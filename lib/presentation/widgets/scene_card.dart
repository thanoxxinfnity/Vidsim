import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/scene.dart';

class SceneCard extends StatelessWidget {
  final int index;
  final String prompt;
  final SceneStatus? status;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SceneCard({
    super.key,
    required this.index,
    required this.prompt,
    this.status,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor().withOpacity(0.3), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Index bubble ──
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.cyan, AppColors.purple],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Prompt text ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prompt,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 6),
                    _StatusChip(status: status!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Actions ──
            Column(
              children: [
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    color: AppColors.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                if (onDelete != null) ...[
                  const SizedBox(height: 4),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: AppColors.error.withOpacity(0.7),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _borderColor() {
    switch (status) {
      case SceneStatus.completed:  return AppColors.success;
      case SceneStatus.generating: return AppColors.cyan;
      case SceneStatus.failed:     return AppColors.error;
      default: return AppColors.glassBorder;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final SceneStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      SceneStatus.pending    => ('Pending',    AppColors.textMuted,  Icons.hourglass_empty_rounded),
      SceneStatus.generating => ('Generating', AppColors.cyan,       Icons.auto_fix_high_rounded),
      SceneStatus.completed  => ('Done',       AppColors.success,    Icons.check_circle_rounded),
      SceneStatus.failed     => ('Failed',     AppColors.error,      Icons.error_outline_rounded),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == SceneStatus.generating)
          SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5, color: color,
            ),
          )
        else
          Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
