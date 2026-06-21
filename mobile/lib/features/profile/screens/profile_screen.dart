import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral)),
        error:   (e, _) => Center(child: Text('Erro: $e')),
        data:    (profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserProfile profile;
  const _ProfileBody({required this.profile});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── App Bar ──────────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.coral,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [AppColors.coral, AppColors.amber],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withAlpha(60),
                      backgroundImage: profile.avatarUrl != null
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: profile.avatarUrl == null
                          ? Text(
                              profile.displayName.isNotEmpty
                                  ? profile.displayName[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.metricMedium(color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(profile.displayName, style: AppTextStyles.title(color: Colors.white)),
                    Text('Nível ${profile.level}', style: AppTextStyles.subtitle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () => context.go('/app/settings'),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Streak ────────────────────────────────────────────────────
                _StreakCard(profile: profile),
                const SizedBox(height: 16),

                // ── XP Progress ───────────────────────────────────────────────
                _XpCard(profile: profile),
                const SizedBox(height: 16),

                // ── Stats ─────────────────────────────────────────────────────
                _StatsRow(profile: profile),
                const SizedBox(height: 20),

                // ── Ranking button ────────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: () => context.go('/app/profile/ranking'),
                  icon:  const Icon(Icons.leaderboard_outlined),
                  label: const Text('Ver Ranking do Bairro'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  final UserProfile profile;
  const _StreakCard({required this.profile});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color:        AppColors.coral.withAlpha(15),
      borderRadius: BorderRadius.circular(16),
      border:       Border.all(color: AppColors.coral.withAlpha(60)),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_fire_department, color: AppColors.coral, size: 40),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${profile.streakDays}',
                    style: AppTextStyles.metricLarge(color: AppColors.coral),
                  ),
                  const SizedBox(width: 6),
                  Text('dias seguidos', style: AppTextStyles.body(color: AppColors.tinta)),
                ],
              ),
              if (profile.streakFreezes > 0)
                Text(
                  '${profile.streakFreezes} freeze${profile.streakFreezes > 1 ? 's' : ''} disponível',
                  style: AppTextStyles.label(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _XpCard extends StatelessWidget {
  final UserProfile profile;
  const _XpCard({required this.profile});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Nível ${profile.level}', style: AppTextStyles.title()),
            Text('Nível ${profile.level + 1}', style: AppTextStyles.subtitle()),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value:            profile.levelProgress,
            minHeight:        10,
            backgroundColor:  AppColors.papel,
            valueColor:       const AlwaysStoppedAnimation(AppColors.coral),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${profile.xp} / ${profile.xpForNextLevel} XP',
          style: AppTextStyles.label(),
        ),
      ],
    ),
  );
}

class _StatsRow extends StatelessWidget {
  final UserProfile profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _StatBox(
        label: 'Território',
        value: '${profile.totalAreaKm2.toStringAsFixed(2)} km²',
      ),
      const SizedBox(width: 12),
      _StatBox(
        label: 'Territórios',
        value: '${profile.territoryCount}',
      ),
      const SizedBox(width: 12),
      _StatBox(
        label: 'Total XP',
        value: '${profile.xp}',
      ),
    ],
  );
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.metric(size: 18)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.label()),
        ],
      ),
    ),
  );
}
