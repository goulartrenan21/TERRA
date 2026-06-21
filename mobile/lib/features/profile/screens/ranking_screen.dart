import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/profile_provider.dart';
import '../../feed/providers/feed_provider.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _window = 'week';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  String get _scope => _tabs.index == 0 ? 'neighborhood' : 'city';
  String get _key   => '$_scope:$_window';

  @override
  Widget build(BuildContext context) {
    final rankingAsync = ref.watch(rankingProvider(_key));
    final profileAsync = ref.watch(profileProvider);
    final currentUserId = profileAsync.valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor:  AppColors.bgDark,
        foregroundColor:  AppColors.textOnDark,
        title: Text('Ranking', style: AppTextStyles.title(color: AppColors.textOnDark)),
        actions: [
          // Semanal / Geral toggle
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(_window == 'week' ? 'Semanal' : 'Geral',
                  style: AppTextStyles.label(color: Colors.white)),
              selected:      true,
              selectedColor: AppColors.coral,
              onSelected:    (_) => setState(() {
                _window = _window == 'week' ? 'alltime' : 'week';
              }),
            ),
          ),
        ],
        bottom: TabBar(
          controller:          _tabs,
          indicatorColor:      AppColors.coral,
          labelColor:          AppColors.coral,
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'Bairro'), Tab(text: 'Cidade')],
        ),
      ),
      body: rankingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral)),
        error:   (e, _) => Center(child: Text('Erro: $e', style: AppTextStyles.body(color: Colors.white))),
        data:    (data) {
          final entries     = (data['entries'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final myPosition  = data['currentUserPosition'] as int?;

          if (entries.isEmpty) {
            return Center(
              child: Text('Nenhuma atividade esta semana',
                  style: AppTextStyles.subtitle(color: Colors.white54)),
            );
          }

          return Stack(
            children: [
              ListView.builder(
                padding:     const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount:   entries.length,
                itemBuilder: (context, i) {
                  final entry     = entries[i];
                  final position  = (entry['position'] as num).toInt();
                  final isMe      = entry['userId'] == currentUserId;

                  if (position <= 3) {
                    return _PodiumCard(entry: entry, isMe: isMe);
                  }
                  return _RankRow(entry: entry, isMe: isMe);
                },
              ),

              // Sticky current user position
              if (myPosition != null && myPosition > 3)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    color:   AppColors.bgDark.withAlpha(230),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child:   _RankRow(
                      entry: entries.firstWhere(
                        (e) => e['userId'] == currentUserId,
                        orElse: () => {'position': myPosition, 'displayName': 'Você', 'totalAreaKm2': 0},
                      ),
                      isMe: true,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isMe;
  const _PodiumCard({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final pos   = (entry['position'] as num).toInt();
    final medal = ['🥇', '🥈', '🥉'][pos - 1];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isMe ? AppColors.coral.withAlpha(40) : AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border:       isMe ? Border.all(color: AppColors.coral) : null,
      ),
      child: Row(
        children: [
          Text(medal, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              entry['displayName'] as String? ?? '—',
              style: AppTextStyles.title(color: AppColors.textOnDark),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(entry['totalAreaKm2'] as num).toStringAsFixed(3)} km²',
                style: AppTextStyles.metric(size: 18, color: AppColors.coral),
              ),
              Text(
                '${entry['territoryCount']} territórios',
                style: AppTextStyles.label(color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isMe;
  const _RankRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color:        isMe ? AppColors.coral.withAlpha(30) : AppColors.cardDark,
      borderRadius: BorderRadius.circular(12),
      border:       isMe ? Border.all(color: AppColors.coral.withAlpha(120)) : null,
    ),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '${entry['position']}',
            style: AppTextStyles.metric(size: 16, color: Colors.white54),
          ),
        ),
        Expanded(
          child: Text(
            entry['displayName'] as String? ?? '—',
            style: AppTextStyles.body(
              color:  isMe ? AppColors.coral : AppColors.textOnDark,
              weight: isMe ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          '${(entry['totalAreaKm2'] as num).toStringAsFixed(2)} km²',
          style: AppTextStyles.metric(size: 14, color: AppColors.textOnDark),
        ),
      ],
    ),
  );
}
