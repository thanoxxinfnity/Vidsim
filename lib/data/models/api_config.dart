/// Holds all API configurations — stored securely via flutter_secure_storage
class ApiConfig {
  final String nimApiKey;
  final String hfToken;        // HuggingFace token (free at hf.co/settings/tokens)
  final String youtubeApiKey;
  final String cosmosEndpoint;
  final int videoWidth;
  final int videoHeight;
  final int numFrames;
  final double guidanceScale;
  final int inferenceSteps;
  final bool useImageToVideo;  // frame continuation

  const ApiConfig({
    required this.nimApiKey,
    required this.youtubeApiKey,
    this.hfToken        = '',
    this.cosmosEndpoint =
        'https://integrate.api.nvidia.com/v1/video/nvidia/cosmos-1.0-diffusion',
    this.videoWidth     = 1280,
    this.videoHeight    = 720,
    this.numFrames      = 360,
    this.guidanceScale  = 7.5,
    this.inferenceSteps = 35,
    this.useImageToVideo = true,
  });

  bool get hasNimKey     => nimApiKey.trim().isNotEmpty;
  bool get hasHfToken    => hfToken.trim().isNotEmpty;
  bool get hasYoutubeKey => youtubeApiKey.trim().isNotEmpty;
  /// App works as long as at least one video source is available
  bool get isConfigured  => hasNimKey || true; // HF works even without token

  ApiConfig copyWith({
    String? nimApiKey,
    String? hfToken,
    String? youtubeApiKey,
    String? cosmosEndpoint,
    int? videoWidth,
    int? videoHeight,
    int? numFrames,
    double? guidanceScale,
    int? inferenceSteps,
    bool? useImageToVideo,
  }) =>
      ApiConfig(
        nimApiKey:       nimApiKey       ?? this.nimApiKey,
        hfToken:         hfToken         ?? this.hfToken,
        youtubeApiKey:   youtubeApiKey   ?? this.youtubeApiKey,
        cosmosEndpoint:  cosmosEndpoint  ?? this.cosmosEndpoint,
        videoWidth:      videoWidth      ?? this.videoWidth,
        videoHeight:     videoHeight     ?? this.videoHeight,
        numFrames:       numFrames       ?? this.numFrames,
        guidanceScale:   guidanceScale   ?? this.guidanceScale,
        inferenceSteps:  inferenceSteps  ?? this.inferenceSteps,
        useImageToVideo: useImageToVideo ?? this.useImageToVideo,
      );

  static const ApiConfig empty = ApiConfig(nimApiKey: '', youtubeApiKey: '');
}
