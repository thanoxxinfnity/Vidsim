/// API endpoints and configuration constants for Cosmos app
abstract class ApiConstants {
  // ── NVIDIA NIM ──────────────────────────────────────────────────────────────
  static const nimBaseUrl = 'https://integrate.api.nvidia.com/v1';

  /// Cosmos 1.0 Diffusion – text-to-video & image-to-video
  static const cosmosT2VEndpoint =
      '$nimBaseUrl/video/nvidia/cosmos-1.0-diffusion';

  /// Cosmos 1.0 Autoregressive – alternative model
  static const cosmosAREndpoint =
      '$nimBaseUrl/video/nvidia/cosmos-1.0-autoregressive';

  /// LLaMA – used for intelligent scene breakdown from long prompts
  static const llamaEndpoint = '$nimBaseUrl/chat/completions';
  static const llamaModel    = 'meta/llama-3.1-8b-instruct';

  // ── YouTube ─────────────────────────────────────────────────────────────────
  static const ytApiBase   = 'https://www.googleapis.com/youtube/v3';
  static const ytVideos    = '$ytApiBase/videos';
  static const ytCaptions  = '$ytApiBase/captions';
  static const ytSearch    = '$ytApiBase/search';

  // ── Generation defaults ─────────────────────────────────────────────────────
  static const defaultWidth       = 1280;
  static const defaultHeight      = 720;
  static const defaultFps         = 24;
  static const defaultNumFrames   = 121; // ~5 seconds at 24fps
  static const defaultGuidance    = 7.5;
  static const defaultSteps       = 35;

  /// Maximum requests per minute for NVIDIA NIM (free tier)
  static const maxRPM             = 40;
  static const minIntervalMs      = 1500; // 60_000 / 40 = 1500ms

  /// Quality booster appended to every generation prompt
  static const qualityBooster = ', cinematic lighting, ultra-realistic textures, '
      '8k resolution, highly detailed physics, hyper-detailed, '
      'seamless motion blur, raw footage style, photorealistic, '
      'no artifacts, no distortion';

  // ── Storage ──────────────────────────────────────────────────────────────────
  static const outputFolder = '/storage/emulated/0/Download/AIVideos';
}
