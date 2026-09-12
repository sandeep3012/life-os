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

/// The comp's Signup screen: a back row, the "Start your / LifeOS." hero, then
/// Full name / Email / Password with the four-bar strength meter under the
/// password, a terms checkbox, and the "Create account" CTA.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _accepted = false;
  bool _busy = false;
  int _strength = 0;

  @override
  void initState() {
    super.initState();
    _password.addListener(() {
      final score = PasswordStrengthMeter.scoreOf(_password.text);
      if (score != _strength) setState(() => _strength = score);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_accepted) {
      _message('Please accept the terms to continue.');
      return;
    }
    setState(() => _busy = true);
    final outcome = await ref.read(syncAuthControllerProvider).signUp(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _message(switch (outcome) {
      SyncAuthNotConfigured() => SyncAuthNotConfigured.message,
      SyncAuthFailure(message: final m) => m,
      SyncAuthSuccess() => 'Account created.',
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Tappable(
                  onTap: () => context.go(RoutePaths.syncSignIn),
                  haptic: TapHaptic.light,
                  semanticLabel: 'Back',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.chevronLeft,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        Text(
                          'Back',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const AuthHero(lines: ['Start your', 'LifeOS'], fontSize: 38),
              const SizedBox(height: 10),
              Text(
                'Finance, habits, gym, calendar — organised from day one.',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 14.5,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 26),
              AuthField(
                label: 'Full name',
                icon: LucideIcons.user,
                controller: _name,
                hintText: 'Your name',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 13),
              AuthField(
                label: 'Email',
                icon: LucideIcons.mail,
                controller: _email,
                hintText: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 13),
              AuthField(
                label: 'Password',
                icon: LucideIcons.lock,
                controller: _password,
                obscure: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 9),
              PasswordStrengthMeter(filled: _strength),
              const SizedBox(height: 18),
              Tappable(
                onTap: () => setState(() => _accepted = !_accepted),
                haptic: TapHaptic.selection,
                semanticLabel: 'Accept terms',
                selected: _accepted,
                child: Row(
                  children: [
                    // Comp: a 20×20 radius-6 accent square with a white check.
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _accepted ? scheme.primary : Colors.transparent,
                        border: Border.all(
                          color: _accepted ? scheme.primary : scheme.outline,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _accepted
                          ? Icon(
                              LucideIcons.check,
                              size: 13,
                              color: scheme.onPrimary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I agree to the Terms and Privacy Policy.',
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              AuthPrimaryButton(
                label: 'Create account',
                busy: _busy,
                onTap: _submit,
              ),
              const SizedBox(height: 22),
              const AuthDivider(),
              const SizedBox(height: 22),
              AuthSocialRow(
                onGoogle: () => _message(SyncAuthNotConfigured.message),
                onApple: () => _message(SyncAuthNotConfigured.message),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Tappable(
                          onTap: () => context.go(RoutePaths.syncSignIn),
                          semanticLabel: 'Sign in',
                          child: Text(
                            'Sign in',
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
