import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronofoot/models/models.dart';
import 'package:pronofoot/providers/providers.dart';

import '../support/fakes.dart';

/// Bug réel observé sur le web : se déconnecter puis se reconnecter avec un
/// autre compte affichait encore les groupes et les stats du compte
/// précédent, parce que les providers ne dépendaient d'aucune identité
/// d'utilisateur et restaient en cache. Ce test verrouille le correctif
/// (chaque provider « à moi » observe `currentUserIdProvider`).
class _CountingGroupRepository extends FakeGroupRepository {
  int calls = 0;

  @override
  Future<List<Membership>> myGroups() {
    calls++;
    return super.myGroups();
  }
}

void main() {
  test('myGroupsProvider se relit après un changement de compte, '
      'pas seulement une déconnexion', () async {
    final repo = _CountingGroupRepository();
    final authChanges = StreamController<Profile?>();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => authChanges.stream),
        groupRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authChanges.close);

    authChanges.add(fakeProfile(id: 'userA'));
    // Laisse authStateProvider (et tout ce qui en dépend) se stabiliser
    // avant de compter les appels, sinon la valeur initiale `null` du
    // flux compte comme un premier changement de compte.
    await container.read(authStateProvider.future);
    await container.read(myGroupsProvider.future);
    expect(repo.calls, 1);

    // Relire sans changement de compte : doit rester en cache, pas de
    // second appel réseau superflu.
    await container.read(myGroupsProvider.future);
    expect(repo.calls, 1);

    // Changement de compte : doit forcer une relecture fraîche.
    authChanges.add(fakeProfile(id: 'userB'));
    await container.read(authStateProvider.future);
    await container.read(myGroupsProvider.future);
    expect(repo.calls, 2);
  });
}
