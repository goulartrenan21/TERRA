import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
            // Progress dots
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
                    description: 'O TERRA usa seu GPS para registrar rotas e calcular territórios conquistados. '
                        'Sua localização nunca é compartilhada sem sua permissão.',
                    buttonLabel: _locationGranted ? 'Permissão concedida ✓' : 'Permitir Localização',
                    onTap: _locationGranted ? _nextPage : _requestLocation,
                    granted: _locationGranted,
                  ),
                  _PermissionPage(
                    icon: Icons.notifications_outlined,
                    title: 'Notificações',
                    description: 'Receba alertas quando seu território for roubado ou seu streak estiver em risco.',
                    buttonLabel: _notifGranted ? 'Notificações ativadas ✓' : 'Permitir Notificações',
                    onTap: _notifGranted ? _nextPage : _requestNotifications,
                    granted: _notifGranted,
                    canSkip: true,
                    onSkip: _nextPage,
                  ),
                  _NeighborhoodPage(
                    onComplete: () => context.go('/login'),
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
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.coral.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: AppColors.coral),
          ),
          const SizedBox(height: 32),
          Text(title, style: AppTextStyles.title(size: 24), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(description, style: AppTextStyles.body(color: AppColors.textSecondary), textAlign: TextAlign.center),
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
              child: Text('Pular por agora', style: AppTextStyles.body(color: AppColors.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }
}

class _NeighborhoodPage extends StatelessWidget {
  final VoidCallback onComplete;
  const _NeighborhoodPage({required this.onComplete});

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
            child: const Icon(Icons.map_outlined, size: 52, color: AppColors.coral),
          ),
          const SizedBox(height: 32),
          Text('Qual é o seu bairro?', style: AppTextStyles.title(size: 24), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            'Compete no ranking local com quem corre perto de você.',
            style: AppTextStyles.body(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Neighborhood search — integrated with API in Phase 7
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar bairro...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: onComplete,
            child: const Text('Começar a Jogar'),
          ),
        ],
      ),
    );
  }
}
