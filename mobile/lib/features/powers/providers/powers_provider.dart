import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

enum PowerKind { shield, reclaim, sprint, roots, freshness, revenge }
enum PowerFamily { constancy, action }

class UserPower {
  final PowerKind kind;
  final PowerFamily family;
  final int charges;
  final int maxCharges;
  final bool armed;
  final bool passive;
  final DateTime? rechargesAt;

  const UserPower({
    required this.kind,
    required this.family,
    required this.charges,
    required this.maxCharges,
    required this.armed,
    required this.passive,
    this.rechargesAt,
  });

  factory UserPower.fromJson(Map<String, dynamic> json) {
    return UserPower(
      kind:        PowerKind.values.byName(json['kind'] as String),
      family:      PowerFamily.values.byName(json['family'] as String),
      charges:     (json['charges'] as num).toInt(),
      maxCharges:  (json['max_charges'] as num).toInt(),
      armed:       json['armed'] as bool,
      passive:     json['passive'] as bool,
      rechargesAt: json['recharges_at'] != null
          ? DateTime.parse(json['recharges_at'] as String)
          : null,
    );
  }

  bool get available => passive || charges > 0;

  String get displayName => switch (kind) {
    PowerKind.shield    => 'Escudo de Território',
    PowerKind.reclaim   => 'Reconquista Relâmpago',
    PowerKind.sprint    => 'Sprint de Captura',
    PowerKind.roots     => 'Raízes',
    PowerKind.freshness => 'Multiplicador de Frescor',
    PowerKind.revenge   => 'Bônus de Revanche',
  };

  String get description => switch (kind) {
    PowerKind.shield    => 'Absorve 1 tentativa de roubo do seu território.',
    PowerKind.reclaim   => 'Recupere território perdido há menos de 14 dias.',
    PowerKind.sprint    => 'Área capturada conta 2× por 10 minutos.',
    PowerKind.roots     => 'Território visitado 3× decai 50% mais devagar.',
    PowerKind.freshness => '+2%/dia de sequência de frescor (máx +40%).',
    PowerKind.revenge   => '+50% de área ao roubar de quem te roubou em 48h.',
  };

  String get emoji => switch (kind) {
    PowerKind.shield    => '🛡️',
    PowerKind.reclaim   => '⚡',
    PowerKind.sprint    => '🚀',
    PowerKind.roots     => '🌱',
    PowerKind.freshness => '❄️',
    PowerKind.revenge   => '🔥',
  };
}

class PowersState {
  final List<UserPower> powers;
  final bool loading;
  final String? error;

  const PowersState({
    this.powers  = const [],
    this.loading = false,
    this.error,
  });

  PowersState copyWith({List<UserPower>? powers, bool? loading, String? error}) =>
      PowersState(
        powers:  powers  ?? this.powers,
        loading: loading ?? this.loading,
        error:   error,
      );
}

class PowersNotifier extends StateNotifier<PowersState> {
  final ApiClient _api;

  PowersNotifier(this._api) : super(const PowersState());

  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final raw = await _api.getPowers();
      final powers = raw
          .cast<Map<String, dynamic>>()
          .map(UserPower.fromJson)
          .toList();
      state = state.copyWith(powers: powers, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> activate(PowerKind kind) async {
    try {
      final raw = await _api.activatePower(kind.name);
      final updated = UserPower.fromJson(raw);
      final powers = state.powers
          .map((p) => p.kind == kind ? updated : p)
          .toList();
      state = state.copyWith(powers: powers);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final powersProvider = StateNotifierProvider<PowersNotifier, PowersState>(
  (ref) => PowersNotifier(ref.read(apiClientProvider)),
);
