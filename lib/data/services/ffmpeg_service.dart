import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class FfmpegService {
  // Crossfade duration between clips (seconds)
  static const _xfadeDur = 0.5;

  // Color grade: slight contrast + saturation boost (cinematic look)
  static const _colorGrade =
      'eq=contrast=1.05:brightness=0.02:saturation=1.15,'
      'curves=r=\'0/0 0.5/0.52 1/1\':g=\'0/0 0.5/0.5 1/1\':b=\'0/0 0.5/0.48 1/1\'';

  // ── Stitch N clips with crossfade transitions + color grade ─────────────────
  Future<String?> stitchWithEffects({
    required List<String> clipPaths,
    required String outputPath,
    void Function(double)? onProgress,
  }) async {
    if (clipPaths.isEmpty) return null;
    if (clipPaths.length == 1) {
      return colorGradeOnly(inputPath: clipPaths.first, outputPath: outputPath);
    }

    // Get duration of every clip
    final durations = <double>[];
    for (final p in clipPaths) {
      final d = await getVideoDuration(p);
      durations.add(d ?? 5.0);
    }

    // Build filter_complex for xfade chain
    final filter = _buildXfadeFilter(durations, clipPaths.length);

    // Build -i flags
    final inputs = clipPaths.map((p) => '-i "$p"').join(' ');

    // Ensure output dir exists
    await File(outputPath).parent.create(recursive: true);

    final cmd = '$inputs '
        '-filter_complex "$filter" '
        '-map "[vout]" '
        '-c:v libx264 -preset fast -crf 18 '
        '-pix_fmt yuv420p '
        '-movflags +faststart '
        '"$outputPath"';

    final session = await FFmpegKit.executeAsync(cmd, (_) {}, (log) {
      final m = RegExp(r'frame=\s*(\d+)').firstMatch(log.getMessage());
      if (m != null && onProgress != null) {
        final totalFrames = durations.fold(0.0, (s, d) => s + d * 24);
        onProgress((int.parse(m.group(1)!) / totalFrames).clamp(0.0, 1.0));
      }
    });

    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) return outputPath;

    // Fallback: plain concat without xfade if complex filter fails
    return _plainConcat(clipPaths, outputPath);
  }

  // ── Apply color grade only (single clip) ────────────────────────────────────
  Future<String?> colorGradeOnly({
    required String inputPath,
    required String outputPath,
  }) async {
    await File(outputPath).parent.create(recursive: true);

    final session = await FFmpegKit.execute(
      '-y -i "$inputPath" '
      '-vf "$_colorGrade" '
      '-c:v libx264 -preset fast -crf 18 '
      '-pix_fmt yuv420p -movflags +faststart '
      '"$outputPath"',
    );
    final rc = await session.getReturnCode();
    return ReturnCode.isSuccess(rc) ? outputPath : null;
  }

  // ── Extract very last frame from a video (for frame continuation) ────────────
  Future<File?> extractLastFrame(String videoPath) async {
    final dir     = await getTemporaryDirectory();
    final outPath = '${dir.path}/last_frame_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final duration = await getVideoDuration(videoPath);
    if (duration == null) return null;

    final seekTime = (duration - 0.1).clamp(0.0, duration);

    final session = await FFmpegKit.execute(
      '-y -ss $seekTime -i "$videoPath" -vframes 1 -q:v 2 "$outPath"',
    );
    if (ReturnCode.isSuccess(await session.getReturnCode())) {
      final f = File(outPath);
      if (await f.exists()) return f;
    }
    return null;
  }

  // ── Get video duration in seconds ────────────────────────────────────────────
  Future<double?> getVideoDuration(String videoPath) async {
    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info    = session.getMediaInformation();
    if (info == null) return null;
    final dur = info.getDuration();
    return dur != null ? double.tryParse(dur) : null;
  }

  // ── Save raw bytes to a temp mp4 file ────────────────────────────────────────
  Future<File> saveTempVideo(List<int> bytes, {String? name}) async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/${name ?? 'clip_${DateTime.now().millisecondsSinceEpoch}'}.mp4';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Delete temp clip files ───────────────────────────────────────────────────
  Future<void> cleanupTempClips(List<String> paths) async {
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  // ── Internal: build xfade filter chain for N clips ───────────────────────────
  String _buildXfadeFilter(List<double> durations, int n) {
    final buf = StringBuffer();
    double offset = durations[0] - _xfadeDur;

    // First xfade: [0:v][1:v] → [v01]
    buf.write('[0:v][1:v]xfade=transition=fade:duration=$_xfadeDur:offset=${offset.toStringAsFixed(2)}[v01]');

    for (int i = 2; i < n; i++) {
      offset += durations[i - 1] - _xfadeDur;
      final prev = i == 2 ? 'v01' : 'v0${i - 1}';
      final curr = i == n - 1 ? 'vpre' : 'v0$i';
      buf.write(';[$prev][$i:v]xfade=transition=fade:duration=$_xfadeDur:offset=${offset.toStringAsFixed(2)}[$curr]');
    }

    // Color grade on the final stitched output
    final lastRef = n == 2 ? 'v01' : 'vpre';
    buf.write(';[$lastRef]$_colorGrade[vout]');

    return buf.toString();
  }

  // ── Fallback: plain H.264 concat (no xfade) ──────────────────────────────────
  Future<String?> _plainConcat(List<String> clipPaths, String outputPath) async {
    final dir      = await getTemporaryDirectory();
    final listFile = File('${dir.path}/concat_list.txt');
    await listFile.writeAsString(clipPaths.map((p) => "file '$p'").join('\n'));

    await File(outputPath).parent.create(recursive: true);

    final session = await FFmpegKit.execute(
      '-y -f concat -safe 0 -i "${listFile.path}" '
      '-vf "$_colorGrade" '
      '-c:v libx264 -preset fast -crf 18 '
      '-pix_fmt yuv420p -movflags +faststart '
      '"$outputPath"',
    );

    try { await listFile.delete(); } catch (_) {}

    final rc = await session.getReturnCode();
    return ReturnCode.isSuccess(rc) ? outputPath : null;
  }
}
