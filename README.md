# PronoFoot

Application de pronostics de football entre amis (iOS + Web).
Certification RNCP Concepteur Développeur d'Applications 2026.

Le cahier des charges complet (produit, règles de gestion, modèle de
données, design) est dans [`PROMPT-PROJET.md`](PROMPT-PROJET.md) — sa
section 11 liste les quelques écarts entre ce document et le code final.

## Lancer le projet

### 1. Backend Supabase

Le projet suppose un projet Supabase existant avec les tables du MPD
(section 3 de `PROMPT-PROJET.md`) déjà créées. Colle
[`supabase/schema_complete.sql`](supabase/schema_complete.sql) dans
l'éditeur SQL du projet — sans danger à rejouer, chaque instruction est
idempotente. Voir [`supabase/NOTES.md`](supabase/NOTES.md) pour le détail
de ce que ce script corrige et pourquoi.

### 2. Secrets

Les secrets ne sont jamais versionnés. Copie `env.example.json` vers
`env.json` (déjà exclu par `.gitignore`) et renseigne tes identifiants :

```bash
cp env.example.json env.json
# puis édite env.json avec SUPABASE_URL et SUPABASE_ANON_KEY
```

### 3. L'application

```bash
flutter pub get

# iOS (simulateur ou appareil connecté)
flutter run --dart-define-from-file=env.json

# Web
flutter run -d chrome --dart-define-from-file=env.json
```

Sous VSCode, l'onglet **Run and Debug** propose directement les
configurations « PronoFoot (Chrome) » et « PronoFoot (iOS / simulateur) »
([`.vscode/launch.json`](.vscode/launch.json)) — pas besoin de retaper la
commande.

## Qualité

```bash
flutter analyze                                       # doit rester à 0 issue
dart format --output=none --set-exit-if-changed .
flutter test                                           # unitaires + widgets
flutter build web                                      # validation de compilation web
```

Une GitHub Action ([.github/workflows/ci.yml](.github/workflows/ci.yml))
exécute ces quatre étapes à chaque push et pull request.

## Architecture

```
lib/
  core/          thème, exceptions métier, config, formatage,
                 barème (RG-03), stickers d'avatar
  models/        objets immuables du MLD + agrégats de lecture
  repositories/  interfaces (repositories.dart) + implémentation
                 Supabase (supabase_repositories.dart)
  providers/     Riverpod — seul point d'accès aux repositories
  screens/       les écrans (E0 à E6, E1 en formulaire à bascule)
  widgets/       composants partagés (monogramme, avatar, sélecteur
                 de score en volets, badges...)
test/
  unit/          logique métier pure (barème, formatage, modèles,
                 traduction d'erreurs, centrage de texte)
  widget/        sélecteur de score, fil rouge « saisir un pronostic »
  support/       doublures de repositories écrites à la main (`Fake*`),
                 pour tester sans base de données ni réseau
supabase/
  schema_complete.sql   état final du schéma côté client (idempotent)
  NOTES.md              ce qui a été trouvé cassé et pourquoi
```

Règle non négociable : **un écran ne parle jamais à Supabase**. Il lit un
provider, qui expose une interface de `repositories.dart`. C'est ce qui
permet de tester `MatchDetailScreen` (E3, le fil rouge du dossier) avec
de fausses données, sans réseau ni base — voir
[`test/widget/prediction_flow_test.dart`](test/widget/prediction_flow_test.dart).

Comment lire le flux d'une action, du tap au serveur :

```
écran (StatelessWidget/ConsumerWidget)
  → provider Riverpod (providers/providers.dart)
    → interface de repository (repositories/repositories.dart)
      → implémentation Supabase (repositories/supabase_repositories.dart)
        → Postgres (RLS + fonctions, supabase/schema_complete.sql)
```

## Fonctionnalités notables

- **Un pronostic se saisit une seule fois** et compte automatiquement
  pour tous les groupes de l'utilisateur (pas de sélection de « groupe
  actif »). Il n'est ensuite ni modifiable ni supprimable.
- **Avatars et groupes en stickers** : icônes Material intégrées à
  Flutter, teintées à la volée (`lib/core/stickers.dart`) — pas d'emoji,
  pas d'image, pas de dépendance réseau.
- **Historique des pronostics par membre**, groupe par groupe,
  activable ou non par l'administrateur.
- **Gestion de groupe** : modifier les paramètres, retirer un membre,
  quitter (transmission automatique du rôle admin si besoin).

## Points de vigilance connus

- **`joinByCode`** insère directement dans `group_members` après avoir
  résolu le code via `find_group_by_code`. Si le projet Supabase expose
  un jour une fonction dédiée (`join_group`) protégée par RLS, adapter
  `SupabaseGroupRepository.joinByCode` en conséquence.
- **Rang par groupe** (E4) : calculé via `group_leaderboard` (un appel
  par groupe de l'utilisateur), pour réutiliser le départage serveur
  (RG-10) plutôt que de le recalculer côté client.
- **Confirmation d'email Supabase** : si elle est réactivée côté projet,
  un `signUp` ne renvoie pas de session immédiate ; l'écran affiche alors
  un message « vérifie ta boîte mail » plutôt que de connecter directement.
