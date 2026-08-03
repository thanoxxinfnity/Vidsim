import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/generation_job.dart';
import '../../presentation/providers/app_provider.dart';
import '../../presentation/widgets/glassmorphic_card.dart';
import '../../presentation/widgets/neon_button.dart';
import '../../presentation/widgets/scene_card.dart';

class GenerationScreen extends StatelessWidget {
  const GenerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final job = app.currentJob;

    if (job == null) {
      return const Center(child: Text('No active generation', style: TextStyle(color: AppColors.textMuted)));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(job.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (job.isRunning)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Cancel Generation?', style: TextStyle(color: AppColors.textPrimary)),
                    content: const Text('All progress will be lost.', style: TextStyle(color: AppColors.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continue')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        onPressed: () {
                          context.read<AppProvider>().cancelGeneration();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Overall progress card ────────────────────────────────────────
            GlowCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Status icon + label
                  _StatusIndicator(status: job.status),
                  const SizedBox(height: 20),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: job.progress,
                      backgroundColor: AppColors.glassBorder,
                      valueColor: const AlwaysStoppedAnimation(AppColors.cyan),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${job.completedScenes} / ${job.totalScenes} clips',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textSecondary, fontSize: 13,
                        ),
                      ),
                      Text(
                        '${(job.progress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.cyan, fontWeight: FontWeight.w700, fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  if (job.elapsed != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Time elapsed: ${_formatDuration(job.elapsed!)}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Status message ───────────────────────────────────────────────
            if (app.statusMessage != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _statusBgColor(job.status).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusBgColor(job.status).withOpacity(0.25)),
                ),
                child: Text(
                  app.statusMessage!,
                  style: TextStyle(color: _statusBgColor(job.status), fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),

            // ── Final video action (when done) ────────────────────────────────
            if (job.status == JobStatus.completed && job.finalVideoPath != null) ...[
              GlassmorphicCard(
                borderColor: AppColors.success.withOpacity(0.4),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Video Generated!',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.finalVideoPath!,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    NeonButton(
                      label:  'Open Downloads Folder',
                      icon:   Icons.folder_open_rounded,
                      colors: [AppColors.success, AppColors.cyanDark],
                      onPressed: () {
                        // Open file manager at the output folder
                        // On Android this requires intent launch
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Scene progress list ───────────────────────────────────────────
            Text(
              'Scene Progress',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            ...job.scenes.map((scene) => SceneCard(
              index:  scene.index,
              prompt: scene.prompt,
              status: scene.status,
            )),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Color _statusBgColor(JobStatus s) => switch (s) {
    JobStatus.generating => AppColors.cyan,
    JobStatus.stitching  => AppColors.purple,
    JobStatus.completed  => AppColors.success,
    JobStatus.failed     => AppColors.error,
    JobStatus.cancelled  => AppColors.warning,
    _ => AppColors.info,
  };
}

class _StatusIndicator extends StatelessWidget {
  final JobStatus status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      JobStatus.preparing  => (Icons.hourglass_top_rounded, AppColors.info,    'Preparing...'),
      JobStatus.generating => (Icons.movie_filter_rounded,  AppColors.cyan,    'Generating Clips'),
      JobStatus.stitching  => (Icons.merge_rounded,         AppColors.purple,  'Stitching Video'),
      JobStatus.completed  => (Icons.check_circle_rounded,  AppColors.success, 'Completed!'),
      JobStatus.failed     => (Icons.error_rounded,         AppColors.error,   'Failed'),
      JobStatus.cancelled  => (Icons.cancel_rounded,        AppColors.warning, 'Cancelled'),
      _                    => (Icons.circle_outlined,       AppColors.textMuted, 'Idle'),
    };

    return Column(
      children: [
        if (status == JobStatus.generating || status == JobStatus.stitching)
          SizedBox(
            width: 56, height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(color: color, strokeWidth: 3),
                Icon(icon, color: color, size: 28),
              ],
            ),
          )
        else
          Icon(icon, color: color, size: 56),
        const SizedBox(height: 10),
        Text(label, style: GoogleFonts.plusJakartaSans(
          color: color, fontWeight: FontWeight.w700, fontSize: 17,
        )),
      ],
    );
  }
}
