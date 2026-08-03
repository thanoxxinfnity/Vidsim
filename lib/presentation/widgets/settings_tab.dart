import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../presentation/providers/settings_provider.dart';
import 'glassmorphic_card.dart';
import 'neon_button.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _nimCtrl      = TextEditingController();
  final _hfCtrl       = TextEditingController();
  final _ytCtrl       = TextEditingController();
  final _endpointCtrl = TextEditingController();
  bool _nimVisible    = false;
  bool _hfVisible     = false;
  bool _ytVisible     = false;
  bool _saved         = false;
  bool _initialized   = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final cfg = context.read<SettingsProvider>().config;
      _nimCtrl.text      = cfg.nimApiKey;
      _hfCtrl.text       = cfg.hfToken;
      _ytCtrl.text       = cfg.youtubeApiKey;
      _endpointCtrl.text = cfg.cosmosEndpoint;
      _initialized       = true;
    }
  }

  @override
  void dispose() {
    _nimCtrl.dispose();
    _hfCtrl.dispose();
    _ytCtrl.dispose();
    _endpointCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final sp = context.read<SettingsProvider>();
    await sp.saveNimKey(_nimCtrl.text);
    await sp.saveHfToken(_hfCtrl.text);
    await sp.saveYtKey(_ytCtrl.text);
    await sp.saveEndpoint(_endpointCtrl.text);
    setState(() { _saved = true; });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() { _saved = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── NVIDIA NIM ──────────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.api_rounded,
            label: 'NVIDIA NIM API',
            color: AppColors.cyan,
          ),
          const SizedBox(height: 10),
          GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ApiKeyField(
                  controller: _nimCtrl,
                  label:      'NIM API Key',
                  hint:       'nvapi-...',
                  visible:    _nimVisible,
                  icon:       Icons.vpn_key_rounded,
                  color:      AppColors.cyan,
                  onToggle:   () => setState(() => _nimVisible = !_nimVisible),
                ),
                const SizedBox(height: 14),
                _ApiKeyField(
                  controller: _endpointCtrl,
                  label:      'Cosmos Endpoint',
                  hint:       'https://integrate.api.nvidia.com/v1/video/...',
                  visible:    true,
                  icon:       Icons.link_rounded,
                  color:      AppColors.cyan,
                  onToggle:   null,
                ),
                const SizedBox(height: 12),
                // Quick endpoint presets
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _EndpointChip(
                      label: 'Cosmos 1.0 Diffusion',
                      onTap: () => setState(() => _endpointCtrl.text =
                          'https://integrate.api.nvidia.com/v1/video/nvidia/cosmos-1.0-diffusion'),
                    ),
                    _EndpointChip(
                      label: 'Cosmos 1.0 Autoregressive',
                      onTap: () => setState(() => _endpointCtrl.text =
                          'https://integrate.api.nvidia.com/v1/video/nvidia/cosmos-1.0-autoregressive'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoBox(
                  text: 'Cosmos video generation requires enterprise NIM access. '
                      'Sign up at build.nvidia.com for access.',
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── HuggingFace ──────────────────────────────────────────────────────
          _SectionHeader(
            icon:  Icons.hub_rounded,
            label: 'HuggingFace (Free Fallback)',
            color: AppColors.purple,
          ),
          const SizedBox(height: 10),
          GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ApiKeyField(
                  controller: _hfCtrl,
                  label:      'HF Token (optional)',
                  hint:       'hf_...',
                  visible:    _hfVisible,
                  icon:       Icons.token_rounded,
                  color:      AppColors.purple,
                  onToggle:   () => setState(() => _hfVisible = !_hfVisible),
                ),
                const SizedBox(height: 12),
                _InfoBox(
                  text: 'Auto-fallback when NIM unavailable. '
                      'Free token from huggingface.co/settings/tokens gives '
                      'better rate limits. Works without token too (slower queue).',
                  color: AppColors.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── YouTube ─────────────────────────────────────────────────────────
          _SectionHeader(
            icon:  Icons.smart_display_rounded,
            label: 'YouTube Data API v3',
            color: AppColors.error,
          ),
          const SizedBox(height: 10),
          GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            child: _ApiKeyField(
              controller: _ytCtrl,
              label:      'YouTube API Key',
              hint:       'AIzaSy...',
              visible:    _ytVisible,
              icon:       Icons.key_rounded,
              color:      AppColors.error,
              onToggle:   () => setState(() => _ytVisible = !_ytVisible),
            ),
          ),
          const SizedBox(height: 20),

          // ── Video output settings ────────────────────────────────────────────
          _SectionHeader(
            icon:  Icons.video_settings_rounded,
            label: 'Generation Settings',
            color: AppColors.purple,
          ),
          const SizedBox(height: 10),
          GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resolution
                Text('Resolution', style: _labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _ResChip(
                      label: '720p (1280×720)',
                      selected: sp.config.videoWidth == 1280,
                      onTap: () => sp.saveResolution(1280, 720),
                    ),
                    _ResChip(
                      label: '1080p (1920×1080)',
                      selected: sp.config.videoWidth == 1920,
                      onTap: () => sp.saveResolution(1920, 1080),
                    ),
                  ],
                ),
                const Divider(color: AppColors.glassBorder, height: 28),

                // Frame continuation toggle
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dynamic Frame Continuation', style: _labelStyle),
                          const SizedBox(height: 4),
                          Text(
                            'Uses last frame of each clip as reference for the next (image-to-video). Ensures visual continuity.',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textMuted, fontSize: 12, height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value:     sp.config.useImageToVideo,
                      onChanged: sp.saveI2V,
                      activeColor: AppColors.cyan,
                    ),
                  ],
                ),
                const Divider(color: AppColors.glassBorder, height: 28),

                // Frames per clip
                Text('Frames Per Clip: ${sp.config.numFrames} (~${(sp.config.numFrames / 24).toStringAsFixed(1)}s | NIM: up to 360 • HF: max 49)', style: _labelStyle),
                Slider(
                  value:    sp.config.numFrames.toDouble().clamp(48, 360),
                  min:      48, max: 360, divisions: 16,
                  label:    '${sp.config.numFrames} frames (~${(sp.config.numFrames / 24).toStringAsFixed(0)}s)',
                  activeColor: AppColors.cyan,
                  inactiveColor: AppColors.glassBorder,
                  onChanged: (v) => sp.saveNumFrames(v.round()),
                ),

                // Guidance scale
                Text('Guidance Scale: ${sp.config.guidanceScale.toStringAsFixed(1)}', style: _labelStyle),
                Slider(
                  value:    sp.config.guidanceScale,
                  min:      1.0, max: 15.0, divisions: 28,
                  label:    sp.config.guidanceScale.toStringAsFixed(1),
                  activeColor: AppColors.purple,
                  inactiveColor: AppColors.glassBorder,
                  onChanged: sp.saveGuidance,
                ),

                // Inference steps
                Text('Inference Steps: ${sp.config.inferenceSteps}', style: _labelStyle),
                Slider(
                  value:    sp.config.inferenceSteps.toDouble(),
                  min:      10, max: 50, divisions: 8,
                  label:    '${sp.config.inferenceSteps} steps',
                  activeColor: AppColors.purple,
                  inactiveColor: AppColors.glassBorder,
                  onChanged: (v) => sp.saveSteps(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Save button ──────────────────────────────────────────────────────
          NeonButton(
            label: _saved ? '✓ Saved!' : 'Save Settings',
            icon:  _saved ? null : Icons.save_rounded,
            colors: _saved
                ? [AppColors.success, AppColors.success]
                : [AppColors.cyan, AppColors.purple],
            height:    58,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
    color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13,
  );
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15,
        )),
      ],
    );
  }
}

class _ApiKeyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool visible;
  final IconData icon;
  final Color color;
  final VoidCallback? onToggle;

  const _ApiKeyField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.visible,
    required this.icon,
    required this.color,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:    controller,
      obscureText:   !visible,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        prefixIcon: Icon(icon, color: color, size: 18),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(
                  visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.textMuted, size: 18,
                ),
                onPressed: onToggle,
              )
            : null,
        labelStyle: TextStyle(color: color.withOpacity(0.8), fontSize: 13),
      ),
    );
  }
}

class _EndpointChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _EndpointChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cyan.withOpacity(0.08),
          border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: AppColors.cyan, fontSize: 11)),
      ),
    );
  }
}

class _ResChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ResChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple.withOpacity(0.2) : AppColors.glassFill,
          border: Border.all(
            color: selected ? AppColors.purple : AppColors.glassBorder,
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? AppColors.purple : AppColors.textSecondary,
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        )),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoBox({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}
