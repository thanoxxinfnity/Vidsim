import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/scene.dart';
import '../../data/models/generation_job.dart';
import '../../data/models/api_config.dart';
import 'nvidia_service.dart';
import 'hf_service.dart';
import 'ffmpeg_service.dart';

typedef PipelineCallback = void Function(GenerationJob job);

/// Orchestrates the full long-form video pipeline (Focal-style):
///   Scenes → Generate clips (NIM primary, HF fallback)
///           → Last-frame capture → Image-to-video anchoring
///           → Crossfade stitch → Color grade → Final MP4
class PipelineService {
  final PipelineCallback onUpdate;

  late NvidiaNimService _nim;
  late HuggingFaceService _hf;
  final FfmpegService _ffmpeg = FfmpegService();
  bool _cancelled = false;

  static const _mediaChannel = MethodChannel('cosmos/media_scanner');

  PipelineService({required this.onUpdate});

  Future<void> runJob(GenerationJob job, ApiConfig config) async {
    _cancelled = false;
    _nim = NvidiaNimService(apiKey: config.nimApiKey, endpoint: config.cosmosEndpoint);
    _hf  = HuggingFaceService(token: config.hfToken.isNotEmpty ? config.hfToken : null);

    // FIX: assign back so all subsequent onUpdate calls carry status: generating
    job = job.copyWith(status: JobStatus.generating);
    _update(job);

    String? prevLastFrameB64;
    String? prevLastFramePath;
    final completedPaths = <String>[];

    // Load reference image as the starting frame for I2V (first clip)
    if (job.referenceImagePath != null) {
      try {
        final imgFile = File(job.referenceImagePath!);
        if (await imgFile.exists()) {
          prevLastFrameB64 = base64Encode(await imgFile.readAsBytes());
        }
      } catch (_) {}
    }

    for (int i = 0; i < job.scenes.length; i++) {
      if (_cancelled) break;

      _updateScene(job, i, SceneStatus.generating);

      // Retry indefinitely until success or cancelled ("jab tak na bana tab tak")
      String? clipPath;
      int attempt = 0;
      while (!_cancelled && clipPath == null) {
        attempt++;

        if (attempt > 1) {
          final waitSec = (10 * (attempt - 1)).clamp(10, 60);
          job.scenes[i] = job.scenes[i].copyWith(
            errorMessage: 'Retry $attempt — waiting ${waitSec}s...',
            retryCount:   attempt - 1,
          );
          onUpdate(job);
          await Future.delayed(Duration(seconds: waitSec));
          if (_cancelled) break;
          _updateScene(job, i, SceneStatus.generating);
        }

        clipPath = await _generateClip(
          scene:         job.scenes[i],
          index:         i,
          config:        config,
          prevFrameB64:  prevLastFrameB64,
          prevFramePath: prevLastFramePath,
          isFirst:       i == 0,
        );
      }

      if (clipPath != null) {
        completedPaths.add(clipPath);
        _updateScene(job, i, SceneStatus.completed, videoPath: clipPath);

        // Extract last frame for next clip (frame continuation)
        final lastFrame = await _ffmpeg.extractLastFrame(clipPath);
        if (lastFrame != null) {
          prevLastFramePath = lastFrame.path;
          prevLastFrameB64  = base64Encode(await lastFrame.readAsBytes());
          job.scenes[i] = job.scenes[i].copyWith(lastFramePath: lastFrame.path);
        }
      } else {
        _updateScene(job, i, SceneStatus.failed, error: 'Cancelled during retry');
      }

      job = job.copyWith(currentSceneIndex: i + 1);
      onUpdate(job);
    }

    if (_cancelled) {
      onUpdate(job.copyWith(status: JobStatus.cancelled));
      return;
    }

    if (completedPaths.isEmpty) {
      onUpdate(job.copyWith(status: JobStatus.failed, errorMessage: 'No clips generated'));
      return;
    }

    // ── Stitch phase (crossfade + color grade) ────────────────────────────────
    onUpdate(job.copyWith(status: JobStatus.stitching));

    final ts      = DateTime.now().millisecondsSinceEpoch;
    final outPath = '${ApiConstants.outputFolder}/${_sanitize(job.title)}_$ts.mp4';

    try {
      final finalPath = completedPaths.length == 1
          ? await _ffmpeg.colorGradeOnly(
              inputPath:  completedPaths.first,
              outputPath: outPath,
            )
          : await _ffmpeg.stitchWithEffects(
              clipPaths:  completedPaths,
              outputPath: outPath,
              onProgress: (p) => onUpdate(job.copyWith(status: JobStatus.stitching)),
            );

      if (finalPath != null) {
        await _ffmpeg.cleanupTempClips(completedPaths);
        // Trigger Android MediaStore scan so video appears in gallery / Downloads
        await _scanToGallery(finalPath);
        onUpdate(job.copyWith(
          status:         JobStatus.completed,
          finalVideoPath: finalPath,
          completedAt:    DateTime.now(),
        ));
      } else {
        onUpdate(job.copyWith(status: JobStatus.failed, errorMessage: 'Video stitching failed'));
      }
    } catch (e) {
      onUpdate(job.copyWith(status: JobStatus.failed, errorMessage: e.toString()));
    }
  }

  void cancel() => _cancelled = true;

  // ── Trigger Android MediaStore scan ─────────────────────────────────────────
  Future<void> _scanToGallery(String path) async {
    try {
      await _mediaChannel.invokeMethod('scan', {'path': path});
    } catch (_) {}
  }

  // ── Try NIM first, auto-switch to HF on any failure ───────────────────────
  Future<String?> _generateClip({
    required Scene scene,
    required int index,
    required ApiConfig config,
    required bool isFirst,
    String? prevFrameB64,
    String? prevFramePath,
  }) async {
    // ── 1. NVIDIA NIM ────────────────────────────────────────────────────────
    if (config.hasNimKey) {
      GenerationResult nimResult;
      for (int attempt = 1; attempt <= 3; attempt++) {
        if (prevFrameB64 == null || !config.useImageToVideo) {
          nimResult = await _nim.textToVideo(
            prompt:         scene.prompt,
            width:          config.videoWidth,
            height:         config.videoHeight,
            numFrames:      config.numFrames,
            guidanceScale:  config.guidanceScale,
            inferenceSteps: config.inferenceSteps,
          );
        } else {
          nimResult = await _nim.imageToVideo(
            prompt:         scene.prompt,
            imageBase64:    prevFrameB64,
            width:          config.videoWidth,
            height:         config.videoHeight,
            numFrames:      config.numFrames,
            guidanceScale:  config.guidanceScale,
            inferenceSteps: config.inferenceSteps,
          );
        }

        if (nimResult.success) {
          if (nimResult.jobId != null && nimResult.pollUrl != null) {
            final polled = await _nim.pollJob(
              jobId:   nimResult.jobId!,
              pollUrl: nimResult.pollUrl!,
            );
            if (polled.success) return _saveNimVideo(polled, index);
          } else {
            return _saveNimVideo(nimResult, index);
          }
        }

        // Rate limit → retry with backoff
        if (nimResult.error?.contains('Rate limit') == true) {
          await Future.delayed(Duration(seconds: 5 * attempt));
          continue;
        }

        // Enterprise / not-available errors → skip NIM entirely
        if (nimResult.error?.contains('404') == true ||
            nimResult.error?.contains('enterprise') == true ||
            nimResult.error?.contains('402') == true) {
          break;
        }

        if (attempt < 3) await Future.delayed(Duration(seconds: 3 * attempt));
      }
    }

    // ── 2. HuggingFace Fallback ───────────────────────────────────────────────
    if (config.useImageToVideo && prevFrameB64 != null) {
      final hfResult = await _hf.imageToVideo(
        prompt:      scene.prompt + ApiConstants.qualityBooster,
        imageBase64: prevFrameB64,
        numFrames:   HuggingFaceService.maxHfFrames,
      );
      if (hfResult.success) return hfResult.videoPath;
    }

    // T2V as final option (single attempt — outer retry loop handles retries)
    final hfResult = await _hf.textToVideo(
      prompt:    scene.prompt + ApiConstants.qualityBooster,
      numFrames: HuggingFaceService.maxHfFrames,
      guidance:  config.guidanceScale,
      steps:     config.inferenceSteps.clamp(20, 50),
    );

    return hfResult.success ? hfResult.videoPath : null;
  }

  Future<String?> _saveNimVideo(GenerationResult result, int index) async {
    if (result.videoBase64 != null) {
      final bytes = base64Decode(result.videoBase64!);
      final dir   = await getTemporaryDirectory();
      final path  = '${dir.path}/nim_clip_${index}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await File(path).writeAsBytes(bytes);
      return path;
    }
    if (result.pollUrl != null) {
      try {
        final req  = await HttpClient().getUrl(Uri.parse(result.pollUrl!));
        final resp = await req.close();
        final bytes = await resp.fold<List<int>>([], (acc, c) => acc..addAll(c));
        final dir  = await getTemporaryDirectory();
        final path = '${dir.path}/nim_clip_${index}_${DateTime.now().millisecondsSinceEpoch}.mp4';
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
  }) {
    job.scenes[index] = job.scenes[index].copyWith(
      status:          status,
      outputVideoPath: videoPath,
      errorMessage:    error,
    );
    onUpdate(job);
  }

  void _update(GenerationJob job) => onUpdate(job);

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_').toLowerCase();
}
