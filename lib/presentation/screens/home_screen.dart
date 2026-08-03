import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/generation_job.dart';
import '../../presentation/providers/app_provider.dart';
import '../../presentation/widgets/prompt_tab.dart';
import '../../presentation/widgets/youtube_tab.dart';
import '../../presentation/widgets/settings_tab.dart';
import 'generation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _tabIndicatorCtrl;

  @override
  void initState() {
    super.initState();
    _tabIndicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tabIndicatorCtrl.forward();
  }

  @override
  void dispose() {
    _tabIndicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background ambient glows ──────────────────────────────────────
          Positioned(
            top: -100, left: -80,
            child: _AmbientGlow(color: AppColors.cyan.withOpacity(0.08), size: 350),
          ),
          Positioned(
            top: 200, right: -100,
            child: _AmbientGlow(color: AppColors.purple.withOpacity(0.08), size: 300),
          ),
          Positioned(
            bottom: 100, left: -60,
            child: _AmbientGlow(color: AppColors.purple.withOpacity(0.05), size: 250),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── App bar ───────────────────────────────────────────────────
                _CosmosAppBar(isGenerating: app.isGenerating, job: app.currentJob),

                // ── Pill tab bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: _PillTabBar(
                    activeTab: app.activeTab,
                    onTabChanged: (t) {
                      context.read<AppProvider>().setTab(t);
                      _tabIndicatorCtrl.reset();
                      _tabIndicatorCtrl.forward();
                    },
                  ),
                ),

                // ── Tab content ───────────────────────────────────────────────
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.03, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(app.activeTab),
                      child: switch (app.activeTab) {
                        InputTab.prompt   => const PromptTab(),
                        InputTab.youtube  => const YoutubeTab(),
                        InputTab.settings => const SettingsTab(),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── Floating generation button (when generation is active) ────────────
      floatingActionButton: app.currentJob != null
          ? _GenerationFAB(job: app.currentJob!, isGenerating: app.isGenerating)
          : null,
    );
  }
}

// ── App bar with logo ─────────────────────────────────────────────────────────
class _CosmosAppBar extends StatelessWidget {
  final bool isGenerating;
  final GenerationJob? job;

  const _CosmosAppBar({required this.isGenerating, required this.job});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Logo
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.cyan, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppColors.cyanGlow(20),
            ),
            child: const Center(
              child: Text('C', style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900,
              )),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.cyan, AppColors.purple],
                ).createShader(b),
                child: Text(
                  'COSMOS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
              Text(
                'AI Video Generator',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (isGenerating && job != null)
            _GeneratingBadge(progress: job!.progress),
        ],
      ),
    );
  }
}

class _GeneratingBadge extends StatefulWidget {
  final double progress;
  const _GeneratingBadge({required this.progress});

  @override
  State<_GeneratingBadge> createState() => _GeneratingBadgeState();
}

class _GeneratingBadgeState extends State<_GeneratingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GenerationScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cyan.withOpacity(0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.cyan.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.5 + 0.5 * _ctrl.value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(widget.progress * 100).toInt()}%',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pill tab bar ──────────────────────────────────────────────────────────────
class _PillTabBar extends StatelessWidget {
  final InputTab activeTab;
  final void Function(InputTab) onTabChanged;

  const _PillTabBar({required this.activeTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: InputTab.values.map((tab) {
          final isActive = tab == activeTab;
          final (icon, label) = switch (tab) {
            InputTab.prompt   => (Icons.edit_note_rounded,     'Prompt'),
            InputTab.youtube  => (Icons.play_circle_rounded,   'YouTube'),
            InputTab.settings => (Icons.settings_rounded,      'Settings'),
          };

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(colors: [AppColors.cyan, AppColors.purple])
                      : null,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: isActive ? AppColors.cyanGlow(12) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: isActive ? Colors.white : AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── FAB for generation status ──────────────────────────────────────────────────
class _GenerationFAB extends StatelessWidget {
  final GenerationJob job;
  final bool isGenerating;

  const _GenerationFAB({required this.job, required this.isGenerating});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GenerationScreen()),
      ),
      backgroundColor: AppColors.cardBg,
      foregroundColor: AppColors.cyan,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
      icon: isGenerating
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.cyan),
            )
          : const Icon(Icons.movie_rounded),
      label: Text(
        isGenerating
            ? '${(job.progress * 100).toInt()}% — ${job.completedScenes}/${job.totalScenes}'
            : job.status == JobStatus.completed ? 'View Result' : 'View Progress',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

// ── Background ambient glow ───────────────────────────────────────────────────
class _AmbientGlow extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 60)],
      ),
    );
  }
}
