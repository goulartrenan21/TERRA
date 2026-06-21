import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/map_provider.dart';

class TerritoryLayer extends StatelessWidget {
  final List<TerritoryFeature> features;

  const TerritoryLayer({super.key, required this.features});

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return PolygonLayer(
      polygons: features.map((f) {
        final color = _colorFor(f, currentUserId);
        return Polygon(
          points:            f.points,
          color:             color.withAlpha((0.55 * 255).round()),
          borderColor:       color.withAlpha((0.85 * 255).round()),
          borderStrokeWidth: 1.5,
        );
      }).toList(),
    );
  }

  Color _colorFor(TerritoryFeature f, String? currentUserId) {
    if (f.ownerId == null) return AppColors.sage;
    if (f.ownerId == currentUserId) {
      // Own territory: coral → fades with freshness
      return Color.lerp(
        AppColors.coral.withAlpha((0.4 * 255).round()),
        AppColors.coral,
        f.freshness,
      )!;
    }
    return AppColors.territoryColorForUser(f.ownerId!);
  }
}
