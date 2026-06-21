import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class ActivityPost {
  final String id;
  final String activityId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double distanceM;
  final int durationS;
  final double avgPaceSecPerKm;
  final double capturedAreaKm2;
  final int xpGained;
  final int likeCount;
  final bool likedByMe;
  final String createdAt;

  const ActivityPost({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.distanceM,
    required this.durationS,
    required this.avgPaceSecPerKm,
    required this.capturedAreaKm2,
    required this.xpGained,
    required this.likeCount,
    required this.likedByMe,
    required this.createdAt,
  });

  double get distanceKm => distanceM / 1000;
  String get formattedPace {
    final total = avgPaceSecPerKm.round();
    return '${total ~/ 60}\'${(total % 60).toString().padLeft(2, '0')}"';
  }

  factory ActivityPost.fromJson(Map<String, dynamic> j) => ActivityPost(
    id:              j['id'] as String,
    activityId:      j['activityId'] as String? ?? j['id'] as String,
    userId:          j['userId'] as String,
    displayName:     j['displayName'] as String,
    avatarUrl:       j['avatarUrl'] as String?,
    distanceM:       (j['metrics']?['distanceM'] as num? ?? 0).toDouble(),
    durationS:       (j['metrics']?['durationS'] as num? ?? 0).toInt(),
    avgPaceSecPerKm: (j['metrics']?['avgPaceSecPerKm'] as num? ?? 0).toDouble(),
    capturedAreaKm2: (j['capturedAreaKm2'] as num? ?? 0).toDouble(),
    xpGained:        (j['xpGained'] as num? ?? 0).toInt(),
    likeCount:       (j['likeCount'] as num? ?? 0).toInt(),
    likedByMe:       j['likedByMe'] as bool? ?? false,
    createdAt:       j['createdAt'] as String,
  );

  ActivityPost copyWith({int? likeCount, bool? likedByMe}) => ActivityPost(
    id: id, activityId: activityId, userId: userId, displayName: displayName,
    avatarUrl: avatarUrl, distanceM: distanceM, durationS: durationS,
    avgPaceSecPerKm: avgPaceSecPerKm, capturedAreaKm2: capturedAreaKm2,
    xpGained: xpGained, createdAt: createdAt,
    likeCount:  likeCount  ?? this.likeCount,
    likedByMe:  likedByMe  ?? this.likedByMe,
  );
}

class FeedState {
  final List<ActivityPost> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final String? nextCursor;
  final String? error;

  const FeedState({
    this.posts         = const [],
    this.isLoading     = false,
    this.isLoadingMore = false,
    this.nextCursor,
    this.error,
  });

  FeedState copyWith({
    List<ActivityPost>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    String? nextCursor,
    String? error,
  }) => FeedState(
    posts:         posts         ?? this.posts,
    isLoading:     isLoading     ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    nextCursor:    nextCursor,          // nullable — reset to null
    error:         error,
  );
}

final feedProvider = StateNotifierProvider.family<FeedNotifier, FeedState, String>(
  (ref, tab) => FeedNotifier(ref.read(apiClientProvider), tab),
);

class FeedNotifier extends StateNotifier<FeedState> {
  final ApiClient _api;
  final String _tab;

  FeedNotifier(this._api, this._tab) : super(const FeedState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.getFeed(tab: _tab);
      state = state.copyWith(
        isLoading:  false,
        posts:      _parsePosts(data),
        nextCursor: data['nextCursor'] as String?,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.nextCursor == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final data = await _api.getFeed(tab: _tab, cursor: state.nextCursor);
      state = state.copyWith(
        isLoadingMore: false,
        posts:         [...state.posts, ..._parsePosts(data)],
        nextCursor:    data['nextCursor'] as String?,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void toggleLike(String postId) {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final post = state.posts[idx];
    final updated = state.posts.toList()
      ..[idx] = post.copyWith(
        likedByMe: !post.likedByMe,
        likeCount: post.likeCount + (post.likedByMe ? -1 : 1),
      );
    state = state.copyWith(posts: updated);
  }

  List<ActivityPost> _parsePosts(Map<String, dynamic> data) =>
      (data['posts'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ActivityPost.fromJson)
          .toList();
}

// Ranking provider
final rankingProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, scopeWindow) async {
    final parts = scopeWindow.split(':');
    return ref.read(apiClientProvider).getRankings(
      scope:  parts[0],
      window: parts[1],
    );
  },
);
