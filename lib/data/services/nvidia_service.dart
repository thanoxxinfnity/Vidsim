import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';

/// Result from a single generation call
class GenerationResult {
  final bool success;
  final String? videoPath;   // local path after saving
  final String? videoBase64; // raw base64 if not yet saved
  final String? pollUrl;     // for async polling
  final String? jobId;
  final String? error;

  const GenerationResult({
    required this.success,
    this.videoPath,
    this.videoBase64,
    this.pollUrl,
    this.jobId,
    this.error,
  });

  factory GenerationResult.err(String msg) => GenerationResult(success: false, error: msg);
}

class NvidiaNimService {
  final String apiKey;
  final String endpoint;

  late final Dio _dio;

  // Rate limit tracking
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);

  NvidiaNimService({required this.apiKey, required this.endpoint}) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10), // video gen can be slow
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type':  'application/json',
          'Accept':        'application/json',
        },
      ),
    );
  }

  // ── Rate limiter ────────────────────────────────────────────────────────────
  Future<void> _respectRateLimit() async {
    final now = DateTime.now();
    final diff = now.difference(_lastRequestTime).inMilliseconds;
    if (diff < ApiConstants.minIntervalMs) {
      await Future.delayed(Duration(milliseconds: ApiConstants.minIntervalMs - diff));
    }
    _lastRequestTime = DateTime.now();
  }

  // ── Build quality-boosted prompt ────────────────────────────────────────────
  String _enhancePrompt(String raw) => '${raw.trim()}${ApiConstants.qualityBooster}';

  // ── Text-to-Video (clip #1) ──────────────────────────────────────────────────
  Future<GenerationResult> textToVideo({
    required String prompt,
    int? width,
    int? height,
    int? numFrames,
    int? fps,
    double? guidanceScale,
    int? inferenceSteps,
    int? seed,
  }) async {
    await _respectRateLimit();

    final body = <String, dynamic>{
      'prompt':               _enhancePrompt(prompt),
      'width':                width      ?? ApiConstants.defaultWidth,
      'height':               height     ?? ApiConstants.defaultHeight,
      'num_frames':           numFrames  ?? ApiConstants.defaultNumFrames,
      'fps':                  fps        ?? ApiConstants.defaultFps,
      'guidance_scale':       guidanceScale ?? ApiConstants.defaultGuidance,
      'num_inference_steps':  inferenceSteps ?? ApiConstants.defaultSteps,
      if (seed != null) 'seed': seed,
    };

    return _callEndpoint(body);
  }

  // ── Image-to-Video (clip #2 → N, uses last frame as anchor) ─────────────────
  Future<GenerationResult> imageToVideo({
    required String prompt,
    required String imageBase64, // base64 JPEG of last frame
    int? width,
    int? height,
    int? numFrames,
    int? fps,
    double? guidanceScale,
    int? inferenceSteps,
    int? seed,
  }) async {
    await _respectRateLimit();

    final body = <String, dynamic>{
      'prompt':               _enhancePrompt(prompt),
      'image':                'data:image/jpeg;base64,$imageBase64',
      'width':                width      ?? ApiConstants.defaultWidth,
      'height':               height     ?? ApiConstants.defaultHeight,
      'num_frames':           numFrames  ?? ApiConstants.defaultNumFrames,
      'fps':                  fps        ?? ApiConstants.defaultFps,
      'guidance_scale':       guidanceScale ?? ApiConstants.defaultGuidance,
      'num_inference_steps':  inferenceSteps ?? ApiConstants.defaultSteps,
      if (seed != null) 'seed': seed,
    };

    return _callEndpoint(body);
  }

  // ── Poll async job ──────────────────────────────────────────────────────────
  Future<GenerationResult> pollJob({
    required String jobId,
    required String pollUrl,
    Duration timeout = const Duration(minutes: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 5));
      await _respectRateLimit();

      try {
        final r = await _dio.get(pollUrl);
        final data = r.data as Map<String, dynamic>;
        final status = (data['status'] as String?)?.toLowerCase() ?? '';

        if (status == 'completed' || status == 'succeeded') {
          return _extractVideoFromResponse(data);
        } else if (status == 'failed' || status == 'error') {
          return GenerationResult.err(data['error']?.toString() ?? 'Job failed');
        }
        // still running → keep polling
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          return GenerationResult.err('Job not found: $jobId');
        }
      }
    }
    return GenerationResult.err('Generation timed out after ${timeout.inMinutes} minutes');
  }

  // ── Use LLaMA to break long prompt into scene list ──────────────────────────
  Future<List<String>> breakdownPromptToScenes(String rawPrompt) async {
    await _respectRateLimit();

    const systemPrompt = '''You are a video scene planner.
Given a video concept/script, split it into exactly 20 short (1-2 sentence)
cinematic scene descriptions for sequential video generation.
Return ONLY a numbered list, 1 to 20. No extra text.''';

    final body = {
      'model':    ApiConstants.llamaModel,
      'messages': [
        {'role': 'system',  'content': systemPrompt},
        {'role': 'user',    'content': rawPrompt},
      ],
      'max_tokens':   1024,
      'temperature':  0.7,
    };

    try {
      final r = await _dio.post(
        ApiConstants.llamaEndpoint,
        data: body,
      );
      final content = (r.data as Map)['choices'][0]['message']['content'] as String;
      return _parseSceneList(content);
    } on DioException catch (_) {
      return _simpleSplit(rawPrompt);
    }
  }

  // ── Parse numbered list from LLaMA ─────────────────────────────────────────
  List<String> _parseSceneList(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final scenes = <String>[];
    for (final line in lines) {
      // Remove leading numbers like "1. " or "1) "
      final clean = line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim();
      if (clean.isNotEmpty) scenes.add(clean);
    }
    return scenes.isEmpty ? _simpleSplit(content) : scenes;
  }

  List<String> _simpleSplit(String text) {
    final sentences = text.split(RegExp(r'[.!?]\s+')).where((s) => s.trim().length > 10).toList();
    if (sentences.isEmpty) return [text];
    return sentences.take(20).toList();
  }

  // ── Internal: POST to Cosmos endpoint ──────────────────────────────────────
  Future<GenerationResult> _callEndpoint(Map<String, dynamic> body) async {
    try {
      final r = await _dio.post(endpoint, data: body);
      final statusCode = r.statusCode ?? 0;

      if (statusCode == 200 || statusCode == 201) {
        return _extractVideoFromResponse(r.data as Map<String, dynamic>);
      } else if (statusCode == 202) {
        // Async accepted — poll for result
        final data = r.data as Map<String, dynamic>;
        final jobId   = data['id']?.toString() ?? '';
        final pollUrl = r.headers.value('Location') ?? data['status_url']?.toString() ?? '';
        return GenerationResult(success: true, jobId: jobId, pollUrl: pollUrl);
      } else {
        return GenerationResult.err('HTTP $statusCode: ${r.data}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        return GenerationResult.err('Rate limit hit – will retry');
      }
      if (e.response?.statusCode == 402) {
        return GenerationResult.err(
            'Payment required – upgrade your NVIDIA NIM account for Cosmos video generation');
      }
      if (e.response?.statusCode == 404) {
        return GenerationResult.err(
            'Cosmos endpoint not found. Cosmos 1.0 video generation requires enterprise NIM access. '
            'Check your account at build.nvidia.com');
      }
      return GenerationResult.err(e.message ?? e.toString());
    } catch (e) {
      return GenerationResult.err(e.toString());
    }
  }

  // ── Extract video bytes / URL from response ─────────────────────────────────
  GenerationResult _extractVideoFromResponse(Map<String, dynamic> data) {
    // Pattern 1: direct base64 video
    final b64 = data['video'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      return GenerationResult(success: true, videoBase64: b64);
    }

    // Pattern 2: artifacts array
    final artifacts = data['artifacts'] as List?;
    if (artifacts != null && artifacts.isNotEmpty) {
      final art = artifacts.first as Map<String, dynamic>;
      final b64a = art['base64'] as String? ?? art['video'] as String?;
      if (b64a != null) return GenerationResult(success: true, videoBase64: b64a);
      final url = art['url'] as String?;
      if (url != null) return GenerationResult(success: true, pollUrl: url);
    }

    // Pattern 3: download_url
    final url = data['download_url'] as String? ?? data['url'] as String?;
    if (url != null) return GenerationResult(success: true, pollUrl: url);

    // Pattern 4: async job reference
    final jobId = data['id'] as String? ?? data['job_id'] as String?;
    if (jobId != null) {
      return GenerationResult(success: true, jobId: jobId, pollUrl: '${endpoint.split('/v1')[0]}/v1/jobs/$jobId');
    }

    return GenerationResult.err('Unknown response format: ${data.keys.join(', ')}');
  }
}
