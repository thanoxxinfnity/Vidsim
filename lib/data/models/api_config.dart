/// Holds all API configurations — stored securely via flutter_secure_storage
class ApiConfig {
  final String nimApiKey;
  final String youtubeApiKey;
  final String cosmosEndpoint;
  final int videoWidth;
  final int videoHeight;
  final int numFrames;
  final double guidanceScale;
  final int inferenceSteps;
  final bool useImageToVideo; // frame continuation

  const ApiConfig({
    required this.nimApiKey,
    required this.youtubeApiKey,
    this.cosmosEndpoint =
        'https://integrate.api.nvidia.com/v1/video/nvidia/cosmos-1.0-diffusion',
    this.videoWidth     = 1280,
    this.videoHeight    = 720,
    this.numFrames      = 121,
    this.guidanceScale  = 7.5,
    this.inferenceSteps = 35,
    this.useImageToVideo = true,
  });

  bool get hasNimKey       => nimApiKey.trim().isNotEmpty;
  bool get hasYoutubeKey   => youtubeApiKey.trim().isNotEmpty;
  bool get isConfigured    => hasNimKey;

  ApiConfig copyWith({
    String? nimApiKey,
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
        nimApiKey:       nimApiKey ?? this.nimApiKey,
        youtubeApiKey:   youtubeApiKey ?? this.youtubeApiKey,
        cosmosEndpoint:  cosmosEndpoint ?? this.cosmosEndpoint,
        videoWidth:      videoWidth ?? this.videoWidth,
        videoHeight:     videoHeight ?? this.videoHeight,
        numFrames:       numFrames ?? this.numFrames,
        guidanceScale:   guidanceScale ?? this.guidanceScale,
        inferenceSteps:  inferenceSteps ?? this.inferenceSteps,
        useImageToVideo: useImageToVideo ?? this.useImageToVideo,
      );

  static const ApiConfig empty = ApiConfig(nimApiKey: '', youtubeApiKey: '');
}
