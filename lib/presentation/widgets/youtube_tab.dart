import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../presentation/providers/app_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import 'glassmorphic_card.dart';
import 'neon_button.dart';
import 'scene_card.dart';

class YoutubeTab extends StatefulWidget {
  const YoutubeTab({super.key});

  @override
  State<YoutubeTab> createState() => _YoutubeTabState();
}

class _YoutubeTabState extends State<YoutubeTab> {
  final _urlCtrl   = TextEditingController();
  final _titleCtrl = TextEditingController(text: 'My Cosmos Video');

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app      = context.watch<AppProvider>();
    final settings = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Info banner ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.purple.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.purple, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Paste a YouTube URL to extract its transcript and auto-generate scenes for each segment.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.purpleLight, fontSize: 12.5, height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── URL input ─────────────────────────────────────────────────────
          GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.smart_display_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Text('YouTube Video URL',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15,
                    )),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/watch?v=...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.link_rounded, color: AppColors.textMuted),
                    suffixIcon: _urlCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted),
                            onPressed: () => setState(() => _urlCtrl.clear()),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                NeonButton(
                  label:     'Fetch & Extract Transcript',
                  icon:      Icons.download_rounded,
                  isLoading: app.isLoadingScenes,
                  colors:    const [Color(0xFFFF0000), Color(0xFFCC0000)],
                  onPressed: (_urlCtrl.text.trim().isEmpty || !settings.config.hasYoutubeKey)
                      ? null
                      : () => context.read<AppProvider>().fetchYoutubeScenes(
                            _urlCtrl.text.trim(), settings.config.youtubeApiKey),
                ),
                if (!settings.config.hasYoutubeKey) ...[
                  const SizedBox(height: 10),
                  _InfoBadge(
                    text: 'Add YouTube API key in Settings tab',
                    color: AppColors.warning,
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Video metadata card ────────────────────────────────────────────
          if (app.ytVideoTitle != null)
            GlassmorphicCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppColors.cyan.withOpacity(0.3),
              child: Row(
                children: [
                  if (app.ytThumbnail != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        app.ytThumbnail!,
                        width: 80, height: 50, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 80),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.ytVideoTitle!,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _InfoBadge(
                          text: '${app.scenePrompts.length} scenes extracted',
                          color: AppColors.success,
                          icon: Icons.check_circle_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // ── Extracted scenes ─────────────────────────────────────────────
          if (app.hasScenes) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Generated Scenes (${app.scenePrompts.length})',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16,
                ),
              ),
            ),
            ...app.scenePrompts.asMap().entries.take(5).map((e) => SceneCard(
              index: e.key, prompt: e.value,
            )),
            if (app.scenePrompts.length > 5)
              Center(
                child: Text(
                  '... and ${app.scenePrompts.length - 5} more scenes',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
            GlassmorphicCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Video Title',
                      prefixIcon: Icon(Icons.title_rounded, color: AppColors.purple),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeonButton(
                    label:     'Start Generation (${app.scenePrompts.length} clips)',
                    icon:      Icons.play_arrow_rounded,
                    isLoading: app.isGenerating,
                    height:    60,
                    colors:    const [AppColors.purpleDark, AppColors.purple],
                    onPressed: app.isGenerating || !settings.config.hasNimKey
                        ? null
                        : () => context.read<AppProvider>().startGeneration(
                              _titleCtrl.text, settings.config),
                  ),
                ],
              ),
            ),
          ],

          if (app.statusMessage != null && app.statusMessage!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Text(app.statusMessage!, style: const TextStyle(color: AppColors.info, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _InfoBadge({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
