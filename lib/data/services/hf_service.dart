import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class HfResult {
  final bool success;
  final String? videoPath;
  final String? error;

  const HfResult({required this.success, this.videoPath, this.error});
  factory HfResult.err(String msg) => HfResult(success: false, error: msg);
}

/// Calls the HuggingFace Inference API for free video generation.
class HuggingFaceService {
  static const _base = 'https://api-inference.huggingface.co/models';

  static const _t2vModels = [
    'THUDM/CogVideoX-5b',
    'THUDM/CogVideoX1.5-5B',
  ];

  static const _i2vModel = 'ali-vilab/i2vgen-xl';

  static const maxHfFrames = 49;

  final String? token;
  late final Dio _dio;

  HuggingFaceService({this.token}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(minutes: 20),
      responseType:   ResponseType.bytes,
      // Never throw based on status — we handle all codes manually
      validateStatus: (_) => true,
    ));
    if (token != null && token!.trim().isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer ${token!.trim()}';
    }
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  bool get hasToken => token != null && token!.trim().isNotEmpty;

  Future<HfResult> textToVideo({
    required String prompt,
    int numFrames = maxHfFrames,
    double guidance = 6.0,
    int steps = 50,
  }) async {
    final frames = numFrames.clamp(1, maxHfFrames);
    for (final model in _t2vModels) {
      final r = await _callModel(
        model: model,
        body: {
          'inputs': prompt,
          'parameters': {
            'num_inference_steps': steps,
            'guidance_scale':      guidance,
            'num_frames':          frames,
          },
        },
        clipIndex: _t2vModels.indexOf(model),
      );
      if (r.success) return r;
    }
    return HfResult.err('All HF T2V models failed');
  }

  Future<HfResult> imageToVideo({
    required String prompt,
    required String imageBase64,
    int numFrames = maxHfFrames,
  }) async {
    return _callModel(
      model: _i2vModel,
      body: {
        'inputs': {
          'image':  'data:image/jpeg;base64,$imageBase64',
          'prompt': prompt,
        },
        'parameters': {'num_frames': numFrames.clamp(1, maxHfFrames)},
      },
    );
  }

  Future<HfResult> _callModel({
    required String model,
    required Map<String, dynamic> body,
    int clipIndex = 0,
  }) async {
    // 5 attempts — outer pipeline retry loop handles further retries
    for (int attempt = 1; attempt <= 5; attempt++) {
      try {
        final r = await _dio.post('$_base/$model', data: json.encode(body));
        final status = r.statusCode ?? 0;

        // Model loading (503) — wait and retry
        if (status == 503) {
          final waitSec = (30 * attempt).clamp(30, 120);
          await Future.delayed(Duration(seconds: waitSec));
          continue;
        }

        // Rate limit (429) — back off
        if (status == 429) {
          await Future.delayed(Duration(seconds: 60 * attempt));
          continue;
        }

        if (status == 401) return HfResult.err('HF token invalid – check Settings');
        if (status == 403) return HfResult.err('HF model access denied for $model');

        if (status == 200) {
          final bytes = r.data as List<int>;
          if (bytes.isEmpty) return HfResult.err('Empty response from $model');

          // HF sometimes returns 200 with a JSON error body instead of binary video
          if (bytes.length < 2000) {
            final maybeJson = _tryParseJson(bytes);
            if (maybeJson != null) {
              final errMsg = maybeJson['error']?.toString();
              final estimatedSec = (maybeJson['estimated_time'] as num?)?.toInt();
              if (errMsg != null) {
                if (estimatedSec != null && attempt < 5) {
                  await Future.delayed(Duration(seconds: estimatedSec.clamp(10, 120)));
                  continue;
                }
                return HfResult.err('HF: $errMsg');
              }
            }
          }

          final path = await _saveBytes(bytes, clipIndex);
          return HfResult(success: true, videoPath: path);
        }

        return HfResult.err('HF HTTP $status from $model');
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;

        if (status == 503) {
          final waitSec = (30 * attempt).clamp(30, 120);
          await Future.delayed(Duration(seconds: waitSec));
          continue;
        }
        if (status == 429) {
          await Future.delayed(Duration(seconds: 60 * attempt));
          continue;
        }
        if (status == 401) return HfResult.err('HF token invalid');
        if (status == 403) return HfResult.err('HF model access denied');

        if (attempt < 5) {
          await Future.delayed(Duration(seconds: 15 * attempt));
        }
      } catch (e) {
        if (attempt < 5) {
          await Future.delayed(Duration(seconds: 10 * attempt));
        }
      }
    }
    return HfResult.err('HF: max retries exceeded for $model');
  }

  Map<String, dynamic>? _tryParseJson(List<int> bytes) {
    try {
      final str = utf8.decode(bytes);
      if (str.trim().startsWith('{')) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<String> _saveBytes(List<int> bytes, int index) async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/hf_clip_${index}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(path).writeAsBytes(bytes);
    return path;
  }
}
