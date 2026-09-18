import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/motion.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/sync_auth_providers.dart';
import '../widgets/auth_widgets.dart';

/// The comp's Login screen. Single column, 28px horizontal padding, vertically
/// centred: brand row, serif hero with an accent full stop, sub-copy, email and
/// password fields, a right-aligned "Forgot password?", the primary CTA, an
/// "or continue with" divider, the 2-up social row, then the sign-up footer.
///
/// This is the entry to *sync*, not to the app — free use needs no account, so
/// nothing routes here on launch. It's reached from the sidebar.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final outcome = await ref.read(syncAuthControllerProvider).signIn(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _report(outcome);
  }

  Future<void> _social(String provider) async {
    final outcome =
        await ref.read(syncAuthControllerProvider).signInWithProvider(provider);
    if (!mounted) return;
    _report(outcome);
  }

  void _report(SyncAuthOutcome outcome) {
    final message = switch (outcome) {
      SyncAuthNotConfigured() => SyncAuthNotConfigured.message,
      SyncAuthFailure(message: final m) => m,
      SyncAuthSuccess() => 'Signed in.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthBrandRow(),
                const SizedBox(height: 44),
                const AuthHero(lines: ['Welcome', 'back']),
                const SizedBox(height: 12),
                Text(
                  'Your whole life, one calm place.\n'
                  "Let's pick up where you left off.",
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 14.5,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 34),
                AuthField(
                  label: 'Email',
                  icon: LucideIcons.mail,
                  controller: _email,
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AuthField(
                  label: 'Password',
                  icon: LucideIcons.lock,
                  controller: _password,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Tappable(
                    onTap: () => _report(const SyncAuthNotConfigured()),
                    semanticLabel: 'Forgot password',
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.accentInk,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: 'Sign in',
                  busy: _busy,
                  onTap: _submit,
                ),
                const SizedBox(height: 22),
                const AuthDivider(),
                const SizedBox(height: 22),
                AuthSocialRow(
                  onGoogle: () => _social('google'),
                  onApple: () => _social('apple'),
                ),
                const SizedBox(height: 30),
                Center(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'New here? '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: Tappable(
                            onTap: () => context.go(RoutePaths.syncSignUp),
                            semanticLabel: 'Create an account',
                            child: Text(
                              'Create an account',
                              style: TextStyle(
                                fontFamily: AppFonts.sans,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.accentInk,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: AppMotion.screenEnter).slideY(
              begin: 0.02,
              end: 0.0,
              duration: AppMotion.screenEnter,
              curve: AppMotion.standard,
            ),
      ),
    );
  }
}
