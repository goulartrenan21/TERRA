import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ShieldBlockedOverlay extends StatefulWidget {
  final String attackerName;
  final VoidCallback onDismiss;

  const ShieldBlockedOverlay({
    super.key,
    required this.attackerName,
    required this.onDismiss,
  });

  @override
  State<ShieldBlockedOverlay> createState() => _ShieldBlockedOverlayState();
}

class _ShieldBlockedOverlayState extends State<ShieldBlockedOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.3)),
    );
    _ctrl.forward();

    // Auto-dismiss after 3.5 s
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sage.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🛡️', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'ESCUDO ATIVADO!',
                  style: TextStyle(
                    color: AppColors.sage,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.attackerName} tentou roubar seu território,\nmas seu escudo bloqueou o ataque!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.sage.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: AppColors.sage,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
