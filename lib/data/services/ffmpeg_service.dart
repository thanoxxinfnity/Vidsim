import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Handles all FFmpeg operations: frame extraction, concatenation, encoding
class FfmpegService {
  // ── Extract the very last frame from a video clip ──────────────────────────
  Future<File?> extractLastFrame(String videoPath) async {
    final dir    = await getTemporaryDirectory();
    final outPath = '${dir.path}/last_frame_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Get video duration first
    final duration = await getVideoDuration(videoPath);
    if (duration == null) return null;

    // Seek to 0.1s before end to avoid black/incomplete frames
    final seekTime = (duration - 0.1).clamp(0.0, duration);

    final session = await FFmpegKit.execute(
      '-y '
      '-ss $seekTime '
      '-i "$videoPath" '
      '-vframes 1 '
      '-q:v 2 '        // high quality JPEG
      '"$outPath"',
    );

    if (ReturnCode.isSuccess(await session.getReturnCode())) {
      final f = File(outPath);
      if (await f.exists()) return f;
    }
    return null;
  }

  // ── Get video duration in seconds ──────────────────────────────────────────
  Future<double?> getVideoDuration(String videoPath) async {
    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info    = session.getMediaInformation();
    if (info == null) return null;
    final dur = info.getDuration();
    return dur != null ? double.tryParse(dur) : null;
  }

  // ── Save raw video bytes to a temp file ────────────────────────────────────
  Future<File> saveTempVideo(Uint8List bytes, {String? name}) async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/${name ?? 'clip_${DateTime.now().millisecondsSinceEpoch}'}.mp4';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Concatenate list of clip files into final MP4 ─────────────────────────
  Future<String?> concatenateClips({
    required List<String> clipPaths,
    required String outputPath,
    void Function(double progress)? onProgress,
  }) async {
    if (clipPaths.isEmpty) return null;

    final dir        = await getTemporaryDirectory();
    final listFile   = File('${dir.path}/concat_list.txt');

    // Build ffmpeg concat demuxer file
    final sb = StringBuffer();
    for (final p in clipPaths) {
      sb.writeln("file '$p'");
    }
    await listFile.writeAsString(sb.toString());

    // Ensure output directory exists
    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);

    // Run concat with re-encoding to ensure compatibility
    final cmd = '-y '
        '-f concat '
        '-safe 0 '
        '-i "${listFile.path}" '
        '-c:v libx264 '
        '-preset fast '
        '-crf 18 '             // high quality
        '-pix_fmt yuv420p '
        '-movflags +faststart ' // web-compatible moov atom
        '"$outputPath"';

    final session = await FFmpegKit.executeAsync(cmd, (s) async {
      // Completion callback
    }, (log) {
      // Parse progress from FFmpeg logs
      final logText = log.getMessage();
      final match = RegExp(r'frame=\s*(\d+)').firstMatch(logText);
      if (match != null && onProgress != null) {
        final framesDone = int.parse(match.group(1)!);
        // Rough progress estimate
        final total = clipPaths.length * 120; // ~120 frames per 5s clip
        onProgress((framesDone / total).clamp(0.0, 1.0));
      }
    });

    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) return outputPath;

    final logs = await session.getFailStackTrace();
    throw Exception('FFmpeg concat failed: $logs');
  }

  // ── Scale / re-encode a single clip to target resolution ──────────────────
  Future<String?> reencodeClip({
    required String inputPath,
    required String outputPath,
    int width  = 1920,
    int height = 1080,
  }) async {
    final cmd = '-y '
        '-i "$inputPath" '
        '-vf scale=$width:$height '
        '-c:v libx264 '
        '-preset fast '
        '-crf 18 '
        '-pix_fmt yuv420p '
        '"$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    if (ReturnCode.isSuccess(await session.getReturnCode())) return outputPath;
    return null;
  }

  // ── Clean up temp files ────────────────────────────────────────────────────
  Future<void> cleanupTempClips(List<String> paths) async {
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
