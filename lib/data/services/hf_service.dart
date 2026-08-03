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
/// Free HF token (huggingface.co/settings/tokens) gives better rate limits.
class HuggingFaceService {
  static const _base = 'https://api-inference.huggingface.co/models';

  // T2V models tried in order (best → fallback)
  static const _t2vModels = [
    'THUDM/CogVideoX-5b',
    'THUDM/CogVideoX1.5-5B',
  ];

  // I2V model (last-frame anchor)
  static const _i2vModel = 'ali-vilab/i2vgen-xl';

  // Max frames HF models support (CogVideoX hard limit)
  static const maxHfFrames = 49;

  final String? token;
  late final Dio _dio;

  HuggingFaceService({this.token}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(minutes: 20),
      responseType: ResponseType.bytes,
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
            'guidance_scale': guidance,
            'num_frames': frames,
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
          'image': 'data:image/jpeg;base64,$imageBase64',
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
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final r = await _dio.post(
          '$_base/$model',
          data: json.encode(body),
        );

        if (r.statusCode == 503) {
          // Model loading — wait and retry
          final waitSec = 20 * attempt;
          await Future.delayed(Duration(seconds: waitSec));
          continue;
        }

        if (r.statusCode == 429) {
          await Future.delayed(Duration(seconds: 30 * attempt));
          continue;
        }

        if (r.statusCode == 200) {
          final bytes = r.data as List<int>;
          if (bytes.isEmpty) return HfResult.err('Empty response from $model');
          final path = await _saveBytes(bytes, clipIndex);
          return HfResult(success: true, videoPath: path);
        }

        return HfResult.err('HF HTTP ${r.statusCode} from $model');
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          return HfResult.err('HF token invalid – check Settings');
        }
        if (e.response?.statusCode == 403) {
          return HfResult.err('HF model access denied for $model');
        }
        if (attempt == 3) {
          return HfResult.err(e.message ?? 'HF network error');
        }
        await Future.delayed(Duration(seconds: 5 * attempt));
      }
    }
    return HfResult.err('HF: max retries exceeded for $model');
  }

  Future<String> _saveBytes(List<int> bytes, int index) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/hf_clip_${index}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(path).writeAsBytes(bytes);
    return path;
  }
}
