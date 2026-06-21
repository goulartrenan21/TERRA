import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signInWithEmail(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    final error = ref.read(authNotifierProvider).error;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: AppColors.error),
      );
    } else if (mounted) {
      context.go('/app/map');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),

                // ── Logo ──────────────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.coral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.terrain, color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 12),
                      Text('TERRA', style: AppTextStyles.metricMedium(color: AppColors.coral)),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Text('Entrar', style: AppTextStyles.display()),
                const SizedBox(height: 4),
                Text('Conquiste seu bairro', style: AppTextStyles.subtitle()),
                const SizedBox(height: 32),

                // ── Email ─────────────────────────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'seu@email.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o e-mail';
                    if (!v.contains('@')) return 'E-mail inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password ──────────────────────────────────────────────────
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    hintText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Entrar ────────────────────────────────────────────────────
                ElevatedButton(
                  onPressed: isLoading ? null : _signIn,
                  child: isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 16),

                // ── Divider ───────────────────────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou', style: AppTextStyles.label()),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),

                // ── Google Sign In ────────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => ref.read(authNotifierProvider.notifier).signInWithGoogle(),
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: const Text('Continuar com Google'),
                ),
                const SizedBox(height: 24),

                // ── Criar conta ───────────────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/onboarding'),
                    child: RichText(
                      text: TextSpan(
                        text: 'Não tem conta? ',
                        style: AppTextStyles.body(color: AppColors.textSecondary),
                        children: [
                          TextSpan(
                            text: 'Criar conta',
                            style: AppTextStyles.body(
                              color: AppColors.coral,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
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
