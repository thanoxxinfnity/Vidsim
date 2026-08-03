import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/scene.dart';
import '../../data/models/generation_job.dart';
import '../../data/models/api_config.dart';
import '../../data/services/pipeline_service.dart';
import '../../data/services/youtube_service.dart';
import '../../data/services/nvidia_service.dart';

enum InputTab { prompt, youtube, settings }

class AppProvider extends ChangeNotifier {
  // ── State ───────────────────────────────────────────────────────────────────
  InputTab _activeTab     = InputTab.prompt;
  GenerationJob? _currentJob;
  List<String> _scenePrompts = [];
  bool _isLoadingScenes   = false;
  bool _isGenerating      = false;
  String? _statusMessage;
  String? _ytVideoTitle;
  String? _ytThumbnail;
  String? _referenceImagePath; // user-selected image for I2V first clip

  final _uuid = const Uuid();
  PipelineService? _pipeline;

  // ── Getters ─────────────────────────────────────────────────────────────────
  InputTab        get activeTab         => _activeTab;
  GenerationJob?  get currentJob        => _currentJob;
  List<String>    get scenePrompts      => List.unmodifiable(_scenePrompts);
  bool            get isLoadingScenes   => _isLoadingScenes;
  bool            get isGenerating      => _isGenerating;
  String?         get statusMessage     => _statusMessage;
  String?         get ytVideoTitle         => _ytVideoTitle;
  String?         get ytThumbnail          => _ytThumbnail;
  String?         get referenceImagePath   => _referenceImagePath;
  bool            get hasReferenceImage    => _referenceImagePath != null;
  bool            get hasScenes            => _scenePrompts.isNotEmpty;

  void setTab(InputTab t) {
    _activeTab = t;
    notifyListeners();
  }

  // ── Reference image (I2V first frame) ──────────────────────────────────────
  void setReferenceImage(String? path) {
    _referenceImagePath = path;
    notifyListeners();
  }

  void clearReferenceImage() {
    _referenceImagePath = null;
    notifyListeners();
  }

  // ── Scene management ────────────────────────────────────────────────────────
  void addScene(String prompt)   { if (prompt.trim().isNotEmpty) { _scenePrompts.add(prompt.trim()); notifyListeners(); } }
  void removeScene(int index)    { _scenePrompts.removeAt(index); notifyListeners(); }
  void reorderScene(int o, int n){ final s = _scenePrompts.removeAt(o); _scenePrompts.insert(n > o ? n - 1 : n, s); notifyListeners(); }
  void editScene(int i, String t){ _scenePrompts[i] = t.trim(); notifyListeners(); }
  void clearScenes()             { _scenePrompts.clear(); _ytVideoTitle = null; _ytThumbnail = null; notifyListeners(); }

  // ── Break raw prompt into scenes using LLaMA ────────────────────────────────
  Future<void> breakdownPrompt(String rawPrompt, ApiConfig config) async {
    if (rawPrompt.trim().isEmpty) return;
    _isLoadingScenes = true;
    _statusMessage   = 'Generating scenes with AI...';
    notifyListeners();

    try {
      final nim    = NvidiaNimService(apiKey: config.nimApiKey, endpoint: config.cosmosEndpoint);
      final scenes = await nim.breakdownPromptToScenes(rawPrompt);
      _scenePrompts = scenes;
      _statusMessage = 'Generated ${scenes.length} scenes';
    } catch (e) {
      _statusMessage = 'Scene breakdown failed: $e';
      // Fallback: treat entire prompt as one scene
      _scenePrompts = [rawPrompt];
    } finally {
      _isLoadingScenes = false;
      notifyListeners();
    }
  }

  // ── Fetch YouTube transcript and convert to scenes ──────────────────────────
  Future<void> fetchYoutubeScenes(String url, String ytApiKey) async {
    final videoId = YoutubeService.extractVideoId(url);
    if (videoId == null) {
      _statusMessage = 'Invalid YouTube URL';
      notifyListeners();
      return;
    }

    _isLoadingScenes = true;
    _statusMessage   = 'Fetching transcript...';
    _ytVideoTitle    = null;
    _ytThumbnail     = null;
    notifyListeners();

    final yt = YoutubeService(apiKey: ytApiKey);
    try {
      final meta = await yt.fetchMetadata(videoId);
      _ytVideoTitle = meta['title'];
      _ytThumbnail  = meta['thumbnail'];
      notifyListeners();

      final transcript = await yt.fetchTranscript(videoId);
      if (transcript.isEmpty) {
        _statusMessage = 'No transcript found. Try a different video.';
        return;
      }

      final scenes = yt.transcriptToScenes(segments: transcript);
      _scenePrompts  = scenes;
      _statusMessage = 'Loaded ${scenes.length} scenes from transcript';
    } catch (e) {
      _statusMessage = 'Failed: $e';
    } finally {
      _isLoadingScenes = false;
      yt.dispose();
      notifyListeners();
    }
  }

  // ── Start video generation ──────────────────────────────────────────────────
  Future<void> startGeneration(String title, ApiConfig config) async {
    if (_scenePrompts.isEmpty || _isGenerating) return;

    final scenes = _scenePrompts.asMap().entries.map((e) {
      return Scene(id: _uuid.v4(), index: e.key, prompt: e.value);
    }).toList();

    _currentJob  = GenerationJob(
      id:                 _uuid.v4(),
      title:              title,
      scenes:             scenes,
      referenceImagePath: _referenceImagePath,
    );
    _isGenerating = true;
    _statusMessage = 'Starting generation...';
    notifyListeners();

    _pipeline = PipelineService(onUpdate: (job) {
      _currentJob = job;
      if (!job.isRunning) _isGenerating = false;
      _statusMessage = _jobStatusMsg(job);
      notifyListeners();
    });

    _pipeline!.runJob(_currentJob!, config);
  }

  void cancelGeneration() {
    _pipeline?.cancel();
    _isGenerating = false;
    _statusMessage = 'Cancelled';
    notifyListeners();
  }

  String _jobStatusMsg(GenerationJob job) {
    switch (job.status) {
      case JobStatus.preparing:  return 'Preparing...';
      case JobStatus.generating: return 'Generating clip ${job.currentSceneIndex}/${job.totalScenes}...';
      case JobStatus.stitching:  return 'Stitching final video...';
      case JobStatus.completed:  return 'Done! Saved to Downloads/AIVideos/';
      case JobStatus.failed:     return 'Failed: ${job.errorMessage}';
      case JobStatus.cancelled:  return 'Cancelled';
      default: return '';
    }
  }
}
