import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int streakDays;
  final int streakFreezes;
  final String? neighborhoodId;
  final double totalAreaKm2;
  final int territoryCount;
  final List<Map<String, dynamic>> privacyZones;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.xp,
    required this.level,
    required this.streakDays,
    required this.streakFreezes,
    this.neighborhoodId,
    required this.totalAreaKm2,
    required this.territoryCount,
    this.privacyZones = const [],
  });

  // XP needed to reach next level: 100 × (level+1)^1.5
  int get xpForNextLevel => (100 * (level + 1) * (level + 1) * (level + 1)).toInt();
  int get xpForCurrentLevel => level <= 1 ? 0 : (100 * level * level * level).toInt();
  double get levelProgress {
    final range = xpForNextLevel - xpForCurrentLevel;
    if (range <= 0) return 1.0;
    return ((xp - xpForCurrentLevel) / range).clamp(0.0, 1.0);
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id:              j['id'] as String,
    email:           j['email'] as String? ?? '',
    displayName:     j['displayName'] as String,
    avatarUrl:       j['avatarUrl'] as String?,
    xp:              (j['xp'] as num).toInt(),
    level:           (j['level'] as num).toInt(),
    streakDays:      (j['streakDays'] as num).toInt(),
    streakFreezes:   (j['streakFreezes'] as num).toInt(),
    neighborhoodId:  j['neighborhoodId'] as String?,
    totalAreaKm2:    (j['totalAreaKm2'] as num).toDouble(),
    territoryCount:  (j['territoryCount'] as num).toInt(),
    privacyZones:    (j['privacyZones'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>() ?? [],
  );
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => _fetch();

  Future<UserProfile> _fetch() async {
    final data = await ref.read(apiClientProvider).getMe();
    return UserProfile.fromJson(data);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> updatePrivacyZones(List<Map<String, dynamic>> zones) async {
    await ref.read(apiClientProvider).updateMe({'privacyZones': zones});
    await refresh();
  }

  Future<void> updateProfile({String? displayName, String? neighborhoodId}) async {
    await ref.read(apiClientProvider).updateMe({
      if (displayName != null) 'displayName': displayName,
      if (neighborhoodId != null) 'neighborhoodId': neighborhoodId,
    });
    await refresh();
  }
}

// Public profile of another user
final publicProfileProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final res = await ref.read(apiClientProvider).getMe();
  return res;
});
