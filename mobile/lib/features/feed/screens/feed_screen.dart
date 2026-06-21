import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/feed_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text('Feed', style: AppTextStyles.title()),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.coral,
          labelColor:     AppColors.coral,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [Tab(text: 'Explorar'), Tab(text: 'Seguindo')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _FeedList(tab: 'explore'),
          _FeedList(tab: 'following'),
        ],
      ),
    );
  }
}

class _FeedList extends ConsumerStatefulWidget {
  final String tab;
  const _FeedList({required this.tab});

  @override
  ConsumerState<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<_FeedList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(feedProvider(widget.tab).notifier).loadMore();
    }
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider(widget.tab));

    if (feed.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.coral));
    }

    if (feed.error != null && feed.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Erro ao carregar feed', style: AppTextStyles.body()),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(feedProvider(widget.tab).notifier).loadInitial(),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (feed.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_run, size: 64, color: AppColors.sage),
            const SizedBox(height: 16),
            Text(
              widget.tab == 'following'
                  ? 'Siga outros corredores para ver o feed'
                  : 'Nenhuma atividade ainda',
              style: AppTextStyles.subtitle(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () => ref.read(feedProvider(widget.tab).notifier).loadInitial(),
      child: ListView.builder(
        controller:  _scroll,
        padding:     const EdgeInsets.symmetric(vertical: 8),
        itemCount:   feed.posts.length + (feed.isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == feed.posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.coral)),
            );
          }
          return _PostCard(
            post: feed.posts[i],
            onLike: () => ref.read(feedProvider(widget.tab).notifier).toggleLike(feed.posts[i].id),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final ActivityPost post;
  final VoidCallback onLike;
  const _PostCard({required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _timeAgo(post.createdAt);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Row(
              children: [
                _Avatar(name: post.displayName, url: post.avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/user/${post.userId}'),
                        child: Text(post.displayName, style: AppTextStyles.body(weight: FontWeight.w700)),
                      ),
                      Text(timeAgo, style: AppTextStyles.label()),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Map placeholder ───────────────────────────────────────────────
            Container(
              height: 120,
              decoration: BoxDecoration(
                color:        AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: const Color(0xFFE0D8D0)),
              ),
              child: const Center(child: Icon(Icons.map_outlined, size: 40, color: AppColors.sage)),
            ),

            const SizedBox(height: 14),

            // ── Metrics row ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MetricChip(label: 'DIST',  value: '${post.distanceKm.toStringAsFixed(2)} km'),
                _MetricChip(label: 'PACE',  value: post.formattedPace),
                _MetricChip(label: 'ÁREA',  value: '${post.capturedAreaKm2.toStringAsFixed(3)} km²'),
                _MetricChip(label: 'XP',    value: '+${post.xpGained}'),
              ],
            ),

            const Divider(height: 24),

            // ── Actions ───────────────────────────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: onLike,
                  child: Row(
                    children: [
                      Icon(
                        post.likedByMe ? Icons.favorite : Icons.favorite_border,
                        color: post.likedByMe ? AppColors.coral : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text('${post.likeCount}', style: AppTextStyles.label()),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String isoDate) {
    try {
      final dt   = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  { return 'agora'; }
      if (diff.inHours < 1)    { return '${diff.inMinutes}min atrás'; }
      if (diff.inDays < 1)     { return '${diff.inHours}h atrás'; }
      if (diff.inDays < 7)     { return '${diff.inDays}d atrás'; }
      return DateFormat('dd/MM').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  const _Avatar({required this.name, this.url});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 20,
    backgroundColor: AppColors.coral.withAlpha(30),
    backgroundImage: url != null ? NetworkImage(url!) : null,
    child: url == null
        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: AppTextStyles.body(color: AppColors.coral, weight: FontWeight.w700))
        : null,
  );
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: AppTextStyles.label()),
      Text(value, style: AppTextStyles.metric(size: 14, color: AppColors.tinta)),
    ],
  );
}
