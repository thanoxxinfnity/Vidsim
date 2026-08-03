import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/scene.dart';
import '../../data/models/generation_job.dart';
import '../../data/models/api_config.dart';
import 'nvidia_service.dart';
import 'ffmpeg_service.dart';

typedef PipelineCallback = void Function(GenerationJob job);

/// Orchestrates the full long-form video generation pipeline:
/// Text → Scenes → Generate clips (with last-frame anchoring) → Concatenate
class PipelineService {
  final PipelineCallback onUpdate;

  late NvidiaNimService _nim;
  final FfmpegService _ffmpeg = FfmpegService();
  bool _cancelled = false;

  PipelineService({required this.onUpdate});

  // ── Main entry: run a job ───────────────────────────────────────────────────
  Future<void> runJob(GenerationJob job, ApiConfig config) async {
    _cancelled = false;
    _nim = NvidiaNimService(apiKey: config.nimApiKey, endpoint: config.cosmosEndpoint);

    _update(job.copyWith(status: JobStatus.generating));

    String? prevLastFrameBase64; // last frame of previous clip (for anchoring)
    final completedPaths = <String>[];
    int retryBudget = 3;

    for (int i = 0; i < job.scenes.length; i++) {
      if (_cancelled) break;

      final scene = job.scenes[i];
      _updateScene(job, i, SceneStatus.generating);

      GenerationResult result;
      int attempts = 0;
      bool success = false;

      while (attempts < retryBudget && !success && !_cancelled) {
        attempts++;

        // Call appropriate endpoint
        if (i == 0 || prevLastFrameBase64 == null || !config.useImageToVideo) {
          result = await _nim.textToVideo(
            prompt:         scene.prompt,
            width:          config.videoWidth,
            height:         config.videoHeight,
            numFrames:      config.numFrames,
            guidanceScale:  config.guidanceScale,
            inferenceSteps: config.inferenceSteps,
          );
        } else {
          result = await _nim.imageToVideo(
            prompt:         scene.prompt,
            imageBase64:    prevLastFrameBase64,
            width:          config.videoWidth,
            height:         config.videoHeight,
            numFrames:      config.numFrames,
            guidanceScale:  config.guidanceScale,
            inferenceSteps: config.inferenceSteps,
          );
        }

        if (!result.success) {
          if (result.error?.contains('Rate limit') == true) {
            // Wait 2 seconds + exponential for rate limit
            await Future.delayed(Duration(seconds: 2 * attempts));
            continue;
          }
          _updateScene(job, i, SceneStatus.failed,
              error: result.error ?? 'Unknown error', retry: attempts);
          break;
        }

        // Handle async polling
        String? finalPath;
        if (result.jobId != null && result.pollUrl != null) {
          final polled = await _nim.pollJob(jobId: result.jobId!, pollUrl: result.pollUrl!);
          if (!polled.success) {
            _updateScene(job, i, SceneStatus.failed, error: polled.error);
            break;
          }
          finalPath = await _saveVideo(polled, i);
        } else {
          finalPath = await _saveVideo(result, i);
        }

        if (finalPath == null) {
          _updateScene(job, i, SceneStatus.failed, error: 'Failed to save video');
          break;
        }

        // Extract last frame for next clip
        final lastFrame = await _ffmpeg.extractLastFrame(finalPath);
        if (lastFrame != null) {
          final bytes = await lastFrame.readAsBytes();
          prevLastFrameBase64 = base64Encode(bytes);
          job.scenes[i] = job.scenes[i].copyWith(lastFramePath: lastFrame.path);
        }

        completedPaths.add(finalPath);
        _updateScene(job, i, SceneStatus.completed, videoPath: finalPath);
        success = true;
      }

      if (!success && !_cancelled) {
        // Non-recoverable: mark failed and continue with next scene
      }

      // Notify progress
      job = job.copyWith(currentSceneIndex: i + 1);
      onUpdate(job);
    }

    if (_cancelled) {
      onUpdate(job.copyWith(status: JobStatus.cancelled));
      return;
    }

    // ── Concatenation phase ───────────────────────────────────────────────────
    if (completedPaths.isEmpty) {
      onUpdate(job.copyWith(status: JobStatus.failed, errorMessage: 'No clips generated'));
      return;
    }

    onUpdate(job.copyWith(status: JobStatus.stitching));

    final ts        = DateTime.now().millisecondsSinceEpoch;
    final outPath   = '${ApiConstants.outputFolder}/${_sanitize(job.title)}_$ts.mp4';

    try {
      final finalPath = await _ffmpeg.concatenateClips(
        clipPaths: completedPaths,
        outputPath: outPath,
        onProgress: (p) {
          onUpdate(job.copyWith(status: JobStatus.stitching));
        },
      );

      if (finalPath != null) {
        await _ffmpeg.cleanupTempClips(completedPaths);
        onUpdate(job.copyWith(
          status: JobStatus.completed,
          finalVideoPath: finalPath,
          completedAt: DateTime.now(),
        ));
      } else {
        onUpdate(job.copyWith(status: JobStatus.failed, errorMessage: 'Video stitching failed'));
      }
    } catch (e) {
      onUpdate(job.copyWith(status: JobStatus.failed, errorMessage: e.toString()));
    }
  }

  void cancel() => _cancelled = true;

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Future<String?> _saveVideo(GenerationResult result, int index) async {
    if (result.videoBase64 != null) {
      final bytes = base64Decode(result.videoBase64!);
      final dir   = await getTemporaryDirectory();
      final path  = '${dir.path}/clip_$index.mp4';
      await File(path).writeAsBytes(bytes);
      return path;
    }
    if (result.pollUrl != null) {
      // download from URL
      try {
        final req  = await HttpClient().getUrl(Uri.parse(result.pollUrl!));
        final resp = await req.close();
        final bytes = await resp.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
        final dir  = await getTemporaryDirectory();
        final path = '${dir.path}/clip_$index.mp4';
        await File(path).writeAsBytes(bytes);
        return path;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _updateScene(
    GenerationJob job,
    int index,
    SceneStatus status, {
    String? videoPath,
    String? error,
    int? retry,
  }) {
    job.scenes[index] = job.scenes[index].copyWith(
      status: status,
      outputVideoPath: videoPath,
      errorMessage: error,
      retryCount: retry ?? job.scenes[index].retryCount,
    );
    onUpdate(job);
  }

  void _update(GenerationJob job) => onUpdate(job);

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_').toLowerCase();
}
