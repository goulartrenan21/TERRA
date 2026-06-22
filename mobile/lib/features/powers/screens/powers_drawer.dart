import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/powers_provider.dart';

class PowersDrawer extends ConsumerStatefulWidget {
  const PowersDrawer({super.key});

  @override
  ConsumerState<PowersDrawer> createState() => _PowersDrawerState();
}

class _PowersDrawerState extends ConsumerState<PowersDrawer> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(powersProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(powersProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  const Text(
                    'Seus Poderes',
                    style: TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (state.loading)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                    ),
                ],
              ),
            ),

            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(state.error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  if (!state.loading && state.powers.isNotEmpty) ...[
                    _SectionHeader('CONSTÂNCIA — PASSIVOS'),
                    const SizedBox(height: 8),
                    ...state.powers
                        .where((p) => p.family == PowerFamily.constancy)
                        .map((p) => _PowerCard(power: p)),
                    const SizedBox(height: 20),
                    _SectionHeader('AÇÃO — ATIVÁVEIS'),
                    const SizedBox(height: 8),
                    ...state.powers
                        .where((p) => p.family == PowerFamily.action)
                        .map((p) => _PowerCard(power: p)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );
}

class _PowerCard extends ConsumerWidget {
  final UserPower power;
  const _PowerCard({required this.power});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final armed   = power.armed;
    final canArm  = !power.passive && power.charges > 0 && !armed;
    final depleted = !power.passive && power.charges == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: armed
            ? AppColors.coral.withValues(alpha: 0.15)
            : AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: armed
            ? Border.all(color: AppColors.coral, width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: depleted
                    ? Colors.white10
                    : AppColors.coral.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(power.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          power.displayName,
                          style: TextStyle(
                            color: depleted
                                ? AppColors.textSecondary
                                : AppColors.textOnDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (power.passive)
                        _Badge('PASSIVO', AppColors.sage)
                      else
                        _ChargeBadge(power.charges, power.maxCharges),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    power.description,
                    style: TextStyle(
                      color: depleted
                          ? AppColors.textSecondary.withValues(alpha: 0.6)
                          : AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (!power.passive && power.rechargesAt != null) ...[
                    const SizedBox(height: 6),
                    _RechargeTimer(rechargesAt: power.rechargesAt!),
                  ],
                ],
              ),
            ),

            // Activate button
            if (canArm || armed) ...[
              const SizedBox(width: 8),
              _ActivateButton(power: power),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

class _ChargeBadge extends StatelessWidget {
  final int charges;
  final int max;
  const _ChargeBadge(this.charges, this.max);

  @override
  Widget build(BuildContext context) {
    final color = charges > 0 ? AppColors.amber : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) => Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Icon(
          i < charges ? Icons.bolt : Icons.bolt_outlined,
          size: 14,
          color: color,
        ),
      )),
    );
  }
}

class _RechargeTimer extends StatelessWidget {
  final DateTime rechargesAt;
  const _RechargeTimer({required this.rechargesAt});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = rechargesAt.difference(now);
    if (diff.isNegative) return const SizedBox.shrink();

    String label;
    if (diff.inDays >= 1) {
      label = '${diff.inDays}d para recarregar';
    } else if (diff.inHours >= 1) {
      label = '${diff.inHours}h para recarregar';
    } else {
      label = '${diff.inMinutes}min para recarregar';
    }

    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 11, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

class _ActivateButton extends ConsumerWidget {
  final UserPower power;
  const _ActivateButton({required this.power});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (power.armed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('ARMADO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      );
    }

    return GestureDetector(
      onTap: () async {
        final ok = await ref.read(powersProvider.notifier).activate(power.kind);
        if (ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${power.emoji} ${power.displayName} armado para a próxima corrida!'),
              backgroundColor: AppColors.coral,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
        ),
        child: const Text('ARMAR', style: TextStyle(color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

void showPowersDrawer(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PowersDrawer(),
  );
}
