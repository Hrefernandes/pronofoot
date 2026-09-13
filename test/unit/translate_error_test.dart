import 'package:flutter_test/flutter_test.dart';
import 'package:pronofoot/core/exceptions.dart';
import 'package:pronofoot/repositories/supabase_repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduction des erreurs techniques en exceptions métier — la frontière que
/// les écrans ne franchissent jamais.
void main() {
  test('RLS 42501 → PredictionLockedException (règle du dossier)', () {
    final error = PostgrestException(
      message: 'permission denied',
      code: '42501',
    );
    expect(translateError(error), isA<PredictionLockedException>());
  });

  test('violation UNIQUE 23505 → ValidationException', () {
    final error = PostgrestException(message: 'duplicate key', code: '23505');
    expect(translateError(error), isA<ValidationException>());
  });

  test('CHECK 23514 → ValidationException', () {
    final error = PostgrestException(message: 'check violation', code: '23514');
    expect(translateError(error), isA<ValidationException>());
  });

  test('identifiants invalides → InvalidCredentialsException', () {
    final error = AuthException('Invalid login credentials');
    expect(translateError(error), isA<InvalidCredentialsException>());
  });

  test('email non confirmé → EmailNotConfirmedException', () {
    final error = AuthException('Email not confirmed');
    expect(translateError(error), isA<EmailNotConfirmedException>());
  });

  test('email déjà utilisé → EmailAlreadyRegisteredException', () {
    final error = AuthException('User already registered');
    expect(translateError(error), isA<EmailAlreadyRegisteredException>());
  });

  test('panne réseau → NetworkException', () {
    expect(
      translateError(Exception('SocketException: Failed host lookup')),
      isA<NetworkException>(),
    );
  });

  test('une AppException traverse sans être ré-emballée', () {
    const original = GroupNotFoundException();
    expect(translateError(original), same(original));
  });

  test('erreur inconnue → UnexpectedException', () {
    expect(translateError(Exception('boom')), isA<UnexpectedException>());
  });
}
