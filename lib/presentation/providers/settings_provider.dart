import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/api_config.dart';

class SettingsProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  ApiConfig _config = ApiConfig.empty;
  bool _loaded = false;

  ApiConfig get config => _config;
  bool get isLoaded    => _loaded;

  static const _kNimKey       = 'nim_api_key';
  static const _kYtKey        = 'yt_api_key';
  static const _kEndpoint     = 'cosmos_endpoint';
  static const _kWidth        = 'vid_width';
  static const _kHeight       = 'vid_height';
  static const _kFrames       = 'num_frames';
  static const _kGuidance     = 'guidance_scale';
  static const _kSteps        = 'inference_steps';
  static const _kI2V          = 'use_i2v';

  Future<void> load() async {
    final nim      = await _storage.read(key: _kNimKey)    ?? '';
    final yt       = await _storage.read(key: _kYtKey)     ?? '';
    final endpoint = await _storage.read(key: _kEndpoint)  ??
        'https://integrate.api.nvidia.com/v1/video/nvidia/cosmos-1.0-diffusion';
    final width    = int.tryParse(await _storage.read(key: _kWidth)  ?? '1280') ?? 1280;
    final height   = int.tryParse(await _storage.read(key: _kHeight) ?? '720')  ?? 720;
    final frames   = int.tryParse(await _storage.read(key: _kFrames) ?? '121')  ?? 121;
    final guidance = double.tryParse(await _storage.read(key: _kGuidance) ?? '7.5') ?? 7.5;
    final steps    = int.tryParse(await _storage.read(key: _kSteps)  ?? '35')  ?? 35;
    final i2v      = (await _storage.read(key: _kI2V)) != 'false';

    _config = ApiConfig(
      nimApiKey:      nim,
      youtubeApiKey:  yt,
      cosmosEndpoint: endpoint,
      videoWidth:     width,
      videoHeight:    height,
      numFrames:      frames,
      guidanceScale:  guidance,
      inferenceSteps: steps,
      useImageToVideo: i2v,
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> saveNimKey(String key) async {
    await _storage.write(key: _kNimKey, value: key.trim());
    _config = _config.copyWith(nimApiKey: key.trim());
    notifyListeners();
  }

  Future<void> saveYtKey(String key) async {
    await _storage.write(key: _kYtKey, value: key.trim());
    _config = _config.copyWith(youtubeApiKey: key.trim());
    notifyListeners();
  }

  Future<void> saveEndpoint(String ep) async {
    await _storage.write(key: _kEndpoint, value: ep.trim());
    _config = _config.copyWith(cosmosEndpoint: ep.trim());
    notifyListeners();
  }

  Future<void> saveResolution(int w, int h) async {
    await _storage.write(key: _kWidth, value: w.toString());
    await _storage.write(key: _kHeight, value: h.toString());
    _config = _config.copyWith(videoWidth: w, videoHeight: h);
    notifyListeners();
  }

  Future<void> saveNumFrames(int n) async {
    await _storage.write(key: _kFrames, value: n.toString());
    _config = _config.copyWith(numFrames: n);
    notifyListeners();
  }

  Future<void> saveGuidance(double g) async {
    await _storage.write(key: _kGuidance, value: g.toString());
    _config = _config.copyWith(guidanceScale: g);
    notifyListeners();
  }

  Future<void> saveSteps(int s) async {
    await _storage.write(key: _kSteps, value: s.toString());
    _config = _config.copyWith(inferenceSteps: s);
    notifyListeners();
  }

  Future<void> saveI2V(bool v) async {
    await _storage.write(key: _kI2V, value: v.toString());
    _config = _config.copyWith(useImageToVideo: v);
    notifyListeners();
  }
}
