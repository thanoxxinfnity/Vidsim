import 'dart:convert';

enum SceneStatus { pending, generating, completed, failed }

class Scene {
  final String id;
  final int index;
  final String prompt;
  SceneStatus status;
  String? outputVideoPath;
  String? lastFramePath;
  String? errorMessage;
  int retryCount;

  Scene({
    required this.id,
    required this.index,
    required this.prompt,
    this.status = SceneStatus.pending,
    this.outputVideoPath,
    this.lastFramePath,
    this.errorMessage,
    this.retryCount = 0,
  });

  bool get isCompleted  => status == SceneStatus.completed;
  bool get isFailed     => status == SceneStatus.failed;
  bool get isPending    => status == SceneStatus.pending;
  bool get isGenerating => status == SceneStatus.generating;

  Scene copyWith({
    SceneStatus? status,
    String? outputVideoPath,
    String? lastFramePath,
    String? errorMessage,
    int? retryCount,
  }) =>
      Scene(
        id:               id,
        index:            index,
        prompt:           prompt,
        status:           status ?? this.status,
        outputVideoPath:  outputVideoPath ?? this.outputVideoPath,
        lastFramePath:    lastFramePath ?? this.lastFramePath,
        errorMessage:     errorMessage ?? this.errorMessage,
        retryCount:       retryCount ?? this.retryCount,
      );

  Map<String, dynamic> toMap() => {
        'id':               id,
        'index':            index,
        'prompt':           prompt,
        'status':           status.name,
        'outputVideoPath':  outputVideoPath,
        'lastFramePath':    lastFramePath,
        'errorMessage':     errorMessage,
        'retryCount':       retryCount,
      };

  factory Scene.fromMap(Map<String, dynamic> m) => Scene(
        id:              m['id'] as String,
        index:           m['index'] as int,
        prompt:          m['prompt'] as String,
        status:          SceneStatus.values.firstWhere(
                           (e) => e.name == m['status'],
                           orElse: () => SceneStatus.pending),
        outputVideoPath: m['outputVideoPath'] as String?,
        lastFramePath:   m['lastFramePath'] as String?,
        errorMessage:    m['errorMessage'] as String?,
        retryCount:      m['retryCount'] as int? ?? 0,
      );

  String toJson() => jsonEncode(toMap());
}
