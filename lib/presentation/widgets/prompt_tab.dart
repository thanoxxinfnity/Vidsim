import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../presentation/providers/app_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import 'glassmorphic_card.dart';
import 'neon_button.dart';
import 'scene_card.dart';

class PromptTab extends StatefulWidget {
  const PromptTab({super.key});

  @override
  State<PromptTab> createState() => _PromptTabState();
}

class _PromptTabState extends State<PromptTab> {
  final _promptCtrl    = TextEditingController();
  final _titleCtrl     = TextEditingController(text: 'My Cosmos Video');
  final _sceneCtrl     = TextEditingController();
  bool _showSceneInput = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    _titleCtrl.dispose();
    _sceneCtrl.dispose();
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
          // ── Prompt input ──────────────────────────────────────────────────
          GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.movie_creation_rounded, color: AppColors.cyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Video Concept / Script',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _promptCtrl,
                  maxLines:   8,
                  style:      const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
                  decoration: InputDecoration(
                    hintText: 'Describe your video concept...\n\n'
                        'Example: "A documentary-style video about the evolution of cities. '
                        'Starting from ancient civilizations with mud-brick buildings, '
                        'transitioning through the Roman Empire, medieval castles, '
                        'industrial revolution factories, to modern glass skyscrapers..."',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
                    ),
                    filled:    true,
                    fillColor: AppColors.overlayLight,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: NeonButton(
                        label:     'Generate Scenes with AI',
                        icon:      Icons.auto_awesome_rounded,
                        isLoading: app.isLoadingScenes,
                        colors:    const [AppColors.cyan, AppColors.purple],
                        onPressed: !settings.config.hasNimKey
                            ? null
                            : () => context.read<AppProvider>().breakdownPrompt(
                                  _promptCtrl.text, settings.config),
                      ),
                    ),
                  ],
                ),
                if (!settings.config.hasNimKey) ...[
                  const SizedBox(height: 8),
                  _WarningBanner(text: 'Add NIM key for AI scene breakdown — or add scenes manually below'),
                ],
                // Estimated duration hint
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.cyan, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          app.hasScenes
                              ? 'Estimated video: ~${app.scenePrompts.length * 2}s '
                                '(${app.scenePrompts.length} clips × ~2s via HuggingFace)'
                              : 'Each clip ≈ 2s via HuggingFace • Add scenes to see total estimate',
                          style: const TextStyle(color: AppColors.cyan, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Scene list ────────────────────────────────────────────────────
          if (app.hasScenes) ...[
            _SceneListHeader(
              count:         app.scenePrompts.length,
              onAddTap:      () => setState(() => _showSceneInput = true),
              onClearTap:    () { context.read<AppProvider>().clearScenes(); },
            ),
            const SizedBox(height: 10),
            if (_showSceneInput) ...[
              _AddSceneField(
                controller: _sceneCtrl,
                onAdd: () {
                  if (_sceneCtrl.text.trim().isNotEmpty) {
                    context.read<AppProvider>().addScene(_sceneCtrl.text);
                    _sceneCtrl.clear();
                    setState(() => _showSceneInput = false);
                  }
                },
                onCancel: () => setState(() { _showSceneInput = false; _sceneCtrl.clear(); }),
              ),
              const SizedBox(height: 10),
            ],
            ...app.scenePrompts.asMap().entries.map((e) => SceneCard(
              index:    e.key,
              prompt:   e.value,
              onDelete: () => context.read<AppProvider>().removeScene(e.key),
              onEdit: () => _showEditDialog(context, e.key, e.value),
            )),
            const SizedBox(height: 16),
          ],

          // ── Video title + Start ────────────────────────────────────────────
          if (app.hasScenes) ...[
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
                    onPressed: app.isGenerating
                        ? null
                        : () => context.read<AppProvider>().startGeneration(
                              _titleCtrl.text, settings.config),
                  ),
                ],
              ),
            ),
          ],

          if (app.statusMessage != null) ...[
            const SizedBox(height: 14),
            _StatusBanner(message: app.statusMessage!),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, int index, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Scene', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () {
              context.read<AppProvider>().editScene(index, ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

class _SceneListHeader extends StatelessWidget {
  final int count;
  final VoidCallback onAddTap;
  final VoidCallback onClearTap;

  const _SceneListHeader({required this.count, required this.onAddTap, required this.onClearTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Scenes ($count)',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16,
          ),
        ),
        const Spacer(),
        PillButton(label: '+ Add', onPressed: onAddTap),
        const SizedBox(width: 8),
        PillButton(label: 'Clear', color: AppColors.error, onPressed: onClearTap),
      ],
    );
  }
}

class _AddSceneField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  const _AddSceneField({required this.controller, required this.onAdd, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Describe this scene...',
              hintStyle: TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
                onPressed: onAdd,
                child: const Text('Add Scene', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String text;
  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.warning, fontSize: 12))),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  const _StatusBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.info, fontSize: 13)),
    );
  }
}
