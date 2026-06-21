import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// Per-user public profile provider
final _userProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, userId) async {
    final dio = ref.read(apiClientProvider);
    // GET /me/user/:id — public profile
    final res = await dio.getMe(); // placeholder — full impl uses /me/user/:id
    return res;
  },
);

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_userProfileProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral)),
        error:   (e, _) => Center(child: Text('Erro: $e')),
        data:    (data) => _PublicProfileBody(data: data, userId: userId),
      ),
    );
  }
}

class _PublicProfileBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final String userId;
  const _PublicProfileBody({required this.data, required this.userId});

  @override
  Widget build(BuildContext context) {
    final displayName    = data['displayName'] as String? ?? '—';
    final level          = (data['level'] as num?)?.toInt() ?? 1;
    final streakDays     = (data['streakDays'] as num?)?.toInt() ?? 0;
    final totalAreaKm2   = (data['totalAreaKm2'] as num?)?.toDouble() ?? 0;
    final territoryCount = (data['territoryCount'] as num?)?.toInt() ?? 0;
    final avatarUrl      = data['avatarUrl'] as String?;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.sage,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [AppColors.sage, Color(0xFF5A8562)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withAlpha(60),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                              style: AppTextStyles.metricMedium(color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(displayName, style: AppTextStyles.title(color: Colors.white)),
                    Text('Nível $level', style: AppTextStyles.subtitle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.sage,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Seguir'),
              ),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Stats
                Row(
                  children: [
                    _StatBox(label: 'Streak',      value: '$streakDays dias'),
                    const SizedBox(width: 12),
                    _StatBox(label: 'Território',  value: '${totalAreaKm2.toStringAsFixed(2)} km²'),
                    const SizedBox(width: 12),
                    _StatBox(label: 'Territórios', value: '$territoryCount'),
                  ],
                ),
                const SizedBox(height: 20),

                // Recent activities placeholder
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Atividades Recentes', style: AppTextStyles.title()),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color:        AppColors.bgLight,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: const Color(0xFFD0C8BF)),
                  ),
                  child: Center(
                    child: Text('Nenhuma atividade pública', style: AppTextStyles.subtitle()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.metric(size: 16), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.label(), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
