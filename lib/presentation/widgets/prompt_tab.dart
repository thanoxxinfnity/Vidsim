import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
  final _picker        = ImagePicker();

  @override
  void dispose() {
    _promptCtrl.dispose();
    _titleCtrl.dispose();
    _sceneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(
      source:       ImageSource.gallery,
      imageQuality: 90,
      maxWidth:     1280,
      maxHeight:    720,
    );
    if (xfile != null && mounted) {
      context.read<AppProvider>().setReferenceImage(xfile.path);
    }
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

          // ── Reference image (I2V first frame) ────────────────────────────
          _ReferenceImageCard(
            imagePath: app.referenceImagePath,
            onPick:    _pickImage,
            onClear:   () => context.read<AppProvider>().clearReferenceImage(),
          ),
          const SizedBox(height: 16),

          // ── Target duration selector ──────────────────────────────────────
          _DurationSelector(
            selectedMinutes: app.targetDurationMinutes,
            estimatedClips:  app.estimatedClipsForTarget,
            onChanged: (m) => context.read<AppProvider>().setTargetDuration(m),
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
                    label:     'Start Generation (${app.estimatedClipsForTarget} clips → ${app.targetDurationMinutes}min)',
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

class _DurationSelector extends StatelessWidget {
  final int selectedMinutes;
  final int estimatedClips;
  final ValueChanged<int> onChanged;

  const _DurationSelector({
    required this.selectedMinutes,
    required this.estimatedClips,
    required this.onChanged,
  });

  static const _options = [1, 2, 3, 4, 5, 6, 8];

  @override
  Widget build(BuildContext context) {
    // Per-clip: ~4s video, ~60s generation + 5s cooldown = ~65s per clip
    final totalGenSec = estimatedClips * 65;
    final genMin      = totalGenSec ~/ 60;
    final genSec      = totalGenSec % 60;
    final genTimeStr  = genMin > 0 ? '~${genMin}m${genSec}s' : '~${genSec}s';

    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.av_timer_rounded, color: AppColors.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'Target Video Duration',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                ),
                child: Text(
                  '$selectedMinutes min',
                  style: const TextStyle(
                    color: AppColors.cyan, fontWeight: FontWeight.w700, fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _options.map((m) {
              final sel = m == selectedMinutes;
              return GestureDetector(
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.cyan.withOpacity(0.15) : AppColors.overlayLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.cyan : AppColors.glassBorder,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    '${m}min',
                    style: TextStyle(
                      color: sel ? AppColors.cyan : AppColors.textSecondary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          if (estimatedClips > 0)
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$estimatedClips clips needed  •  Est. generation time: $genTimeStr  •  5s gap between calls',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                  ),
                ),
              ],
            )
          else
            const Text(
              'Add scenes to see clip estimate',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
        ],
      ),
    );
  }
}

class _ReferenceImageCard extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _ReferenceImageCard({
    required this.imagePath,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_rounded, color: AppColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Reference Image (First Frame)',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (imagePath != null)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded, color: AppColors.error, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Optional — your image will be used as the starting frame for video generation',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          if (imagePath != null) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(imagePath!),
                    width: 90,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        imagePath!.split('/').last,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                          const SizedBox(width: 4),
                          const Text(
                            'Image selected',
                            style: TextStyle(color: AppColors.success, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PillButton(label: 'Change', onPressed: onPick),
              ],
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text('Pick from Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.purple,
                side: const BorderSide(color: AppColors.purple, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
