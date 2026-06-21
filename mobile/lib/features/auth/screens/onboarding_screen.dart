import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  bool _locationGranted = false;
  bool _notifGranted    = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    setState(() {
      _locationGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    });
    if (_locationGranted) _nextPage();
  }

  Future<void> _requestNotifications() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    setState(() {
      _notifGranted = settings.authorizationStatus == AuthorizationStatus.authorized;
    });
    _nextPage();
  }

  void _nextPage() {
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i <= _page ? AppColors.coral : AppColors.papel,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _PermissionPage(
                    icon: Icons.location_on,
                    title: 'Localização em tempo real',
                    description:
                        'O TERRA usa seu GPS para registrar rotas e calcular territórios '
                        'conquistados. Sua localização nunca é compartilhada sem sua permissão.',
                    buttonLabel: _locationGranted ? 'Permissão concedida ✓' : 'Permitir Localização',
                    onTap:   _locationGranted ? _nextPage : _requestLocation,
                    granted: _locationGranted,
                  ),
                  _PermissionPage(
                    icon: Icons.notifications_outlined,
                    title: 'Notificações',
                    description:
                        'Receba alertas quando seu território for roubado ou '
                        'seu streak estiver em risco.',
                    buttonLabel: _notifGranted ? 'Notificações ativadas ✓' : 'Permitir Notificações',
                    onTap:    _notifGranted ? _nextPage : _requestNotifications,
                    granted:  _notifGranted,
                    canSkip:  true,
                    onSkip:   _nextPage,
                  ),
                  _NeighborhoodPage(
                    onComplete: (neighborhoodId) async {
                      if (neighborhoodId != null) {
                        try {
                          await ref.read(apiClientProvider).updateMe(
                            {'neighborhoodId': neighborhoodId},
                          );
                        } catch (_) {
                          // Non-blocking — user can update later in settings
                        }
                      }
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Permission slide ──────────────────────────────────────────────────────────

class _PermissionPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;
  final bool granted;
  final bool canSkip;
  final VoidCallback? onSkip;

  const _PermissionPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
    required this.granted,
    this.canSkip = false,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppColors.coral.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: AppColors.coral),
          ),
          const SizedBox(height: 32),
          Text(title, style: AppTextStyles.title(size: 24), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            description,
            style: AppTextStyles.body(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: granted ? AppColors.sage : AppColors.coral,
            ),
            child: Text(buttonLabel),
          ),
          if (canSkip && onSkip != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Pular por agora',
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Neighborhood slide ────────────────────────────────────────────────────────

class _NeighborhoodResult {
  final String id;
  final String name;
  final String fullName;
  const _NeighborhoodResult({required this.id, required this.name, required this.fullName});
}

class _NeighborhoodPage extends StatefulWidget {
  final Future<void> Function(String? neighborhoodId) onComplete;
  const _NeighborhoodPage({required this.onComplete});

  @override
  State<_NeighborhoodPage> createState() => _NeighborhoodPageState();
}

class _NeighborhoodPageState extends State<_NeighborhoodPage> {
  final _searchCtrl = TextEditingController();
  final _dio        = Dio();

  List<_NeighborhoodResult> _results = [];
  _NeighborhoodResult?      _selected;
  bool                      _loading  = false;
  Timer?                    _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchCtrl.text.trim();
    if (query.length < 3) {
      setState(() { _results = []; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final response = await _dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q':              query,
          'format':         'json',
          'addressdetails': '1',
          'limit':          '8',
          'featuretype':    'settlement',
        },
        options: Options(headers: {'User-Agent': 'TERRAApp/1.0 (contato@terra.app)'}),
      );

      final items = response.data ?? [];
      setState(() {
        _results = items.map((item) {
          final placeId = (item['place_id'] as num).toInt();
          final addr    = item['address'] as Map<String, dynamic>? ?? {};
          final name    = (addr['neighbourhood']
                        ?? addr['suburb']
                        ?? addr['city_district']
                        ?? addr['town']
                        ?? addr['city']
                        ?? (item['display_name'] as String).split(',').first.trim())
                        as String;
          return _NeighborhoodResult(
            id:       _placeIdToUuid(placeId),
            name:     name,
            fullName: item['display_name'] as String,
          );
        }).toList();
      });
    } catch (_) {
      setState(() => _results = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  // Deterministic UUID from Nominatim place_id (groups users in same area)
  String _placeIdToUuid(int placeId) {
    final hex = placeId.toRadixString(16).padLeft(12, '0').substring(
      (placeId.toRadixString(16).length - 12).clamp(0, 999),
    );
    return '00000000-0000-4000-a000-${hex.padLeft(12, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppColors.coral.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map_outlined, size: 52, color: AppColors.coral),
          ),
          const SizedBox(height: 32),
          Text('Qual é o seu bairro?', style: AppTextStyles.title(size: 24), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Compete no ranking local com quem corre perto de você.',
            style: AppTextStyles.body(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Search field
          TextField(
            controller:  _searchCtrl,
            autofocus:   false,
            decoration: InputDecoration(
              hintText:    'Buscar bairro ou cidade...',
              prefixIcon:  const Icon(Icons.search),
              suffixIcon:  _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral)),
                    )
                  : _selected != null
                      ? const Icon(Icons.check_circle, color: AppColors.sage)
                      : null,
            ),
          ),

          // Selected neighborhood chip
          if (_selected != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        AppColors.sage.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: AppColors.sage.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.sage, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_selected!.name, style: AppTextStyles.body(weight: FontWeight.w600)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() { _selected = null; _searchCtrl.clear(); }),
                    child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],

          // Results list
          if (_results.isNotEmpty && _selected == null) ...[
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final r = _results[i];
                  return ListTile(
                    leading:  const Icon(Icons.location_on_outlined, color: AppColors.coral),
                    title:    Text(r.name, style: AppTextStyles.body()),
                    subtitle: Text(
                      r.fullName.split(',').take(3).join(','),
                      style: AppTextStyles.label(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      setState(() {
                        _selected = r;
                        _results  = [];
                        _searchCtrl.text = r.name;
                      });
                    },
                  );
                },
              ),
            ),
          ] else
            const Spacer(),

          // CTA button
          ElevatedButton(
            onPressed: () => widget.onComplete(_selected?.id),
            child: Text(_selected != null ? 'Começar a Jogar' : 'Pular por agora'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
