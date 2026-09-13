import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/exceptions.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/wordmark.dart';

/// E1A / E1B — Connexion et inscription, formulaire à bascule.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.startInRegister = false});

  final bool startInRegister;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late bool _register = widget.startInRegister;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() => _register = !_register);
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final auth = ref.read(authRepositoryProvider);
    try {
      if (_register) {
        final profile = await auth.signUp(
          email: _email.text,
          password: _password.text,
          username: _username.text,
        );
        if (!mounted) return;
        if (profile == null) {
          await _showConfirmEmailDialog();
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          return;
        }
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AppException catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showConfirmEmailDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.tribune,
        title: const Text('Vérifie ta boîte mail'),
        content: Text(
          'Un lien de confirmation a été envoyé à ${_email.text.trim()}. '
          'Clique dessus puis connecte-toi.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenEdge,
            AppSpacing.m,
            AppSpacing.screenEdge,
            AppSpacing.l,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_register) ...[
                  Text('CRÉER UN', style: AppText.screenTitle),
                  Text('COMPTE', style: AppText.screenTitle),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Trois champs, et tu rejoins ton premier groupe.',
                    style: AppText.bodyMuted,
                  ),
                ] else ...[
                  const Wordmark(fontSize: 44),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'LE CLASSEMENT COMPTE TOUT SEUL',
                    style: AppText.eyebrow,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (_register) ...[
                  _label('Pseudo'),
                  TextFormField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Ton pseudo'),
                    validator: _validateUsername,
                  ),
                  const SizedBox(height: AppSpacing.m),
                ],
                _label('Email'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(hintText: 'ton@email.com'),
                  validator: _validateEmail,
                ),
                const SizedBox(height: AppSpacing.m),
                _label('Mot de passe'),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: _register ? '8 caractères minimum' : '••••••••',
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: AppSpacing.l),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surOr,
                          ),
                        )
                      : Text(_register ? 'CRÉER MON COMPTE' : 'SE CONNECTER'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _toggleMode,
                    child: Text.rich(
                      TextSpan(
                        style: AppText.bodyMuted,
                        children: [
                          TextSpan(
                            text: _register
                                ? 'Déjà inscrit ? '
                                : 'Pas encore de compte ? ',
                          ),
                          TextSpan(
                            text: _register
                                ? 'Se connecter'
                                : 'Créer un compte',
                            style: const TextStyle(
                              color: AppColors.or,
                              fontWeight: FontWeight.w600,
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

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s),
    child: Text(text.toUpperCase(), style: AppText.eyebrow),
  );

  String? _validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 3) return 'Au moins 3 caractères.';
    if (v.length > 20) return '20 caractères maximum.';
    return null;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    return ok ? null : 'Email invalide.';
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) return 'Au moins 8 caractères.';
    return null;
  }
}
