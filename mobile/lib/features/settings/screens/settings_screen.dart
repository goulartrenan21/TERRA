import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text('Configurações', style: AppTextStyles.title()),
      ),
      body: ListView(
        children: [
          // ── Account section ─────────────────────────────────────────────────
          _SectionHeader('Conta'),
          profileAsync.when(
            loading: () => const ListTile(title: Text('Carregando...')),
            error:   (_, __) => const SizedBox.shrink(),
            data: (profile) => ListTile(
              leading:  CircleAvatar(
                backgroundColor: AppColors.coral.withAlpha(30),
                child: Text(
                  profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?',
                  style: AppTextStyles.body(color: AppColors.coral, weight: FontWeight.w700),
                ),
              ),
              title:    Text(profile.displayName, style: AppTextStyles.body(weight: FontWeight.w600)),
              subtitle: Text(profile.email, style: AppTextStyles.label()),
              trailing: const Icon(Icons.chevron_right),
              onTap:    () => _showEditProfile(context, ref, profile),
            ),
          ),

          // ── Privacy section ─────────────────────────────────────────────────
          _SectionHeader('Privacidade'),
          ListTile(
            leading:  const Icon(Icons.location_off_outlined, color: AppColors.coral),
            title:    Text('Zonas de Privacidade', style: AppTextStyles.body()),
            subtitle: Text('Ocultar início e fim das rotas', style: AppTextStyles.label()),
            trailing: const Icon(Icons.chevron_right),
            onTap:    () => _showPrivacyZones(context, ref),
          ),
          ListTile(
            leading:  const Icon(Icons.download_outlined),
            title:    Text('Exportar meus dados', style: AppTextStyles.body()),
            subtitle: Text('LGPD — baixar todos os seus dados', style: AppTextStyles.label()),
            onTap:    () => _showExportDialog(context),
          ),

          // ── Notifications section ────────────────────────────────────────────
          _SectionHeader('Notificações'),
          _NotificationToggle(
            icon:    Icons.terrain,
            title:   'Território roubado',
            value:   true,
            onChanged: (_) {},
          ),
          _NotificationToggle(
            icon:    Icons.local_fire_department,
            title:   'Streak em risco',
            value:   true,
            onChanged: (_) {},
          ),
          _NotificationToggle(
            icon:    Icons.favorite_border,
            title:   'Curtidas',
            value:   true,
            onChanged: (_) {},
          ),

          // ── Danger zone ─────────────────────────────────────────────────────
          _SectionHeader('Conta'),
          ListTile(
            leading:  const Icon(Icons.logout, color: AppColors.error),
            title:    Text('Sair', style: AppTextStyles.body(color: AppColors.error)),
            onTap:    () => _confirmSignOut(context, ref),
          ),
          ListTile(
            leading:  const Icon(Icons.delete_forever_outlined, color: AppColors.error),
            title:    Text('Deletar conta', style: AppTextStyles.body(color: AppColors.error)),
            subtitle: Text('Esta ação é irreversível', style: AppTextStyles.label()),
            onTap:    () => _confirmDeleteAccount(context, ref),
          ),

          const SizedBox(height: 40),
          Center(child: Text('TERRA v1.0.0', style: AppTextStyles.label())),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context, WidgetRef ref, UserProfile profile) {
    final ctrl = TextEditingController(text: profile.displayName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Editar Perfil', style: AppTextStyles.title()),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Nome de exibição'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await ref.read(profileProvider.notifier).updateProfile(
                  displayName: ctrl.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyZones(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Zonas de Privacidade', style: AppTextStyles.title()),
            const SizedBox(height: 8),
            Text(
              'Adicione endereços sensíveis (casa, trabalho). '
              'O início e fim das rotas dentro do raio serão ocultados.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {},
              icon:  const Icon(Icons.add_location_outlined),
              label: const Text('Adicionar endereço'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exportar dados'),
        content: const Text('Você receberá um e-mail com todos os seus dados em até 72 horas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Solicitar exportação'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair?'),
        content: const Text('Você precisará fazer login novamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deletar conta?'),
        content: const Text(
          'Esta ação é irreversível. Todos os seus territórios, '
          'atividades e progresso serão deletados permanentemente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context), // TODO: implement delete
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Deletar permanentemente'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(
      title.toUpperCase(),
      style: AppTextStyles.label(color: AppColors.textSecondary),
    ),
  );
}

class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotificationToggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary:   Icon(icon),
    title:       Text(title, style: AppTextStyles.body()),
    value:            value,
    activeThumbColor: AppColors.coral,
    onChanged:        onChanged,
  );
}
