import 'dart:convert';
import 'scene.dart';

enum JobStatus { idle, preparing, generating, stitching, completed, failed, cancelled }

class GenerationJob {
  final String id;
  final String title;
  final List<Scene> scenes;
  final String? referenceImagePath;
  JobStatus status;
  int currentSceneIndex;
  String? finalVideoPath;
  String? errorMessage;
  DateTime startedAt;
  DateTime? completedAt;

  GenerationJob({
    required this.id,
    required this.title,
    required this.scenes,
    this.referenceImagePath,
    this.status = JobStatus.idle,
    this.currentSceneIndex = 0,
    this.finalVideoPath,
    this.errorMessage,
    DateTime? startedAt,
    this.completedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  double get progress {
    if (scenes.isEmpty) return 0.0;
    final done = scenes.where((s) => s.isCompleted).length;
    return done / scenes.length;
  }

  int get completedScenes => scenes.where((s) => s.isCompleted).length;
  int get totalScenes     => scenes.length;

  bool get isRunning => status == JobStatus.generating || status == JobStatus.stitching || status == JobStatus.preparing;

  Duration? get elapsed {
    if (completedAt != null) return completedAt!.difference(startedAt);
    return DateTime.now().difference(startedAt);
  }

  GenerationJob copyWith({
    JobStatus? status,
    int? currentSceneIndex,
    String? finalVideoPath,
    String? errorMessage,
    DateTime? completedAt,
  }) =>
      GenerationJob(
        id:                   id,
        title:                title,
        scenes:               scenes,
        referenceImagePath:   referenceImagePath,
        status:               status ?? this.status,
        currentSceneIndex:    currentSceneIndex ?? this.currentSceneIndex,
        finalVideoPath:       finalVideoPath ?? this.finalVideoPath,
        errorMessage:         errorMessage ?? this.errorMessage,
        startedAt:            startedAt,
        completedAt:          completedAt ?? this.completedAt,
      );

  Map<String, dynamic> toMap() => {
        'id':                   id,
        'title':                title,
        'scenes':               scenes.map((s) => s.toMap()).toList(),
        'referenceImagePath':   referenceImagePath,
        'status':               status.name,
        'currentSceneIndex':    currentSceneIndex,
        'finalVideoPath':       finalVideoPath,
        'errorMessage':         errorMessage,
        'startedAt':            startedAt.toIso8601String(),
        'completedAt':          completedAt?.toIso8601String(),
      };

  String toJson() => jsonEncode(toMap());
}
