import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../core/constants/api_constants.dart';

/// YouTube transcript + metadata extraction
class YoutubeService {
  final String apiKey;
  final Dio _dio;
  final YoutubeExplode _yt = YoutubeExplode();

  YoutubeService({required this.apiKey})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  // ── Extract video ID from various URL formats ───────────────────────────────
  static String? extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // youtube.com/watch?v=ID
    if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
    // youtu.be/ID
    if (uri.host == 'youtu.be') return uri.pathSegments.firstOrNull;
    // youtube.com/shorts/ID  |  youtube.com/embed/ID
    if (uri.pathSegments.length >= 2 &&
        (uri.pathSegments.contains('shorts') || uri.pathSegments.contains('embed'))) {
      return uri.pathSegments.last;
    }
    return null;
  }

  // ── Fetch video metadata (title, duration, thumbnail) ──────────────────────
  Future<Map<String, String?>> fetchMetadata(String videoId) async {
    try {
      final r = await _dio.get(
        ApiConstants.ytVideos,
        queryParameters: {
          'part':  'snippet,contentDetails',
          'id':     videoId,
          'key':    apiKey,
        },
      );
      final items = (r.data['items'] as List?)?.cast<Map<String, dynamic>>();
      if (items == null || items.isEmpty) return {};

      final snippet = items.first['snippet'] as Map<String, dynamic>?;
      final thumbs  = snippet?['thumbnails'] as Map<String, dynamic>?;
      final thumb   = (thumbs?['maxres'] ?? thumbs?['high'] ?? thumbs?['medium'])
                        as Map<String, dynamic>?;

      return {
        'title':       snippet?['title'] as String?,
        'description': snippet?['description'] as String?,
        'thumbnail':   thumb?['url'] as String?,
        'duration':    items.first['contentDetails']?['duration'] as String?,
      };
    } catch (_) {
      return {};
    }
  }

  // ── Fetch full transcript (no OAuth needed via youtube_explode_dart) ─────────
  Future<List<TranscriptSegment>> fetchTranscript(String videoId) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);
      if (manifest.tracks.isEmpty) return [];

      // Prefer English
      final track = manifest.tracks.firstWhere(
        (t) => t.language.code.startsWith('en'),
        orElse: () => manifest.tracks.first,
      );

      final captions = await _yt.videos.closedCaptions.get(track);
      return captions.captions
          .map((c) => TranscriptSegment(
                text:   c.text,
                start:  c.offset,
                end:    c.offset + c.duration,
              ))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // ── Convert transcript → scene prompt list (for ~5-10s clips) ───────────────
  /// Groups transcript lines into chunks of ~[wordsPerScene] words.
  List<String> transcriptToScenes({
    required List<TranscriptSegment> segments,
    int wordsPerScene = 80,
    int maxScenes     = 180,
  }) {
    if (segments.isEmpty) return [];

    final scenes = <String>[];
    final buf = StringBuffer();
    int wordCount = 0;

    for (final seg in segments) {
      final words = seg.text.split(' ');
      for (final w in words) {
        buf.write('$w ');
        wordCount++;
        if (wordCount >= wordsPerScene) {
          scenes.add(buf.toString().trim());
          buf.clear();
          wordCount = 0;
          if (scenes.length >= maxScenes) return scenes;
        }
      }
    }

    if (buf.isNotEmpty) scenes.add(buf.toString().trim());
    return scenes;
  }

  void dispose() => _yt.close();
}

class TranscriptSegment {
  final String text;
  final Duration start;
  final Duration end;

  const TranscriptSegment({
    required this.text,
    required this.start,
    required this.end,
  });

  Duration get duration => end - start;
}
