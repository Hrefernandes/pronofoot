# PronoFoot — contexte complet du projet

> Fichier de référence unique. Tout ce qui suit a été décidé et validé.
> Ne pas reconcevoir : implémenter.

**Certification RNCP Concepteur Développeur d'Applications 2026**
Soutenance le **16 septembre 2026** · gel du code le **10 septembre**

---

# 1. Le produit

Application mobile de pronostics de football entre amis.

Un utilisateur crée un groupe privé, invite ses amis par un code à 6
caractères, chacun pronostique le score exact des matchs à venir, et le
classement se calcule automatiquement dès qu'un match est terminé.

Remplace le trio groupe WhatsApp + tableur + décompte manuel, avec ses
trois défauts : décompte lent et contesté, pronostics saisis après le
coup d'envoi, historique perdu.

## Périmètre — 7 écrans, pas un de plus

| Écran | Contenu | User stories |
|---|---|---|
| **E1** | Connexion / Inscription (formulaire à bascule) | US-01, US-02 |
| **E2** | Liste des matchs groupés par date | US-03 |
| **E3** | Détail d'un match, saisie du pronostic, pronostics du groupe | US-04, US-08 |
| **E4** | Mes groupes + créer / rejoindre (feuilles modales) | US-05, US-06 |
| **E5** | Détail du groupe : classement, code d'invitation, barème | US-07 |
| **E6** | Profil, statistiques, déconnexion | US-10 |

## Hors périmètre — ne pas implémenter

Duels 1v1 · bonus de série · plafond hebdomadaire · semaine parfaite ·
système d'amis · réactions emoji · liens de diffusion · notifications
push · compétitions européennes.

Ces fonctionnalités sont documentées comme évolutions dans le dossier.
Les colonnes `groups.streak_bonus` et `groups.duel_enabled` existent en
base mais restent neutres — ne pas les exploiter.

**Le périmètre a été arbitré volontairement.** L'élargir dégraderait ce
qui est réellement évalué : sécurité, tests, architecture.

---

# 2. État d'avancement

## Terminé

- Conception complète : MCD, MLD, MPD, diagrammes de séquence, matrice des droits
- Charte graphique, personas, maquettes des 7 écrans
- **Back-end Supabase déployé et testé** — 5 migrations, 31 tests passés
- Base Flutter : thème, modèles, repositories, providers

## À faire

1. `flutter analyze` propre — **le code Dart n'a jamais été compilé**
2. Widgets partagés : monogramme, carte match, badge, sélecteur de score
3. Les 7 écrans
4. Tests unitaires puis tests de widgets
5. GitHub Actions, build iOS

---

# 3. Modèle de données

## MCD — 6 entités, 7 associations

```
PROFILE }o--o{ GROUPE : ADHERER (role, total_points, joined_at)
PROFILE ||--o{ PREDICTION : EMETTRE
GROUPE  ||--o{ PREDICTION : ATTRIBUER
MATCH   ||--o{ PREDICTION : PORTER SUR
TEAM    }o--|| MATCH : DISPUTER (role dom/ext)
LEAGUE  ||--|{ TEAM : CONTENIR
LEAGUE  ||--o{ MATCH : ORGANISER
```

| Association | Card. A | Card. B | Attributs portés |
|---|---|---|---|
| ADHERER (PROFILE — GROUPE) | 0,n | 1,n | role, total_points, joined_at |
| EMETTRE (PROFILE — PREDICTION) | 0,n | 1,1 | — |
| ATTRIBUER (GROUPE — PREDICTION) | 0,n | 1,1 | — |
| PORTER SUR (MATCH — PREDICTION) | 0,n | 1,1 | — |
| DISPUTER (TEAM — MATCH) | 0,n | 2,2 | rôle dom/ext |
| CONTENIR (LEAGUE — TEAM) | 1,n | 1,1 | — |
| ORGANISER (LEAGUE — MATCH) | 0,n | 1,1 | — |

## MLD — 7 relations

Clé primaire soulignée, `#` pour les clés étrangères.

```
profiles      (id, username, display_name, avatar_icon, avatar_color, created_at)
leagues       (id, name, country, color_primary, color_secondary, color_text)
teams         (id, #league_id, short_name, name, color_primary, color_secondary, color_text)
matches       (id, #league_id, #home_team_id, #away_team_id, kickoff_at,
               home_score, away_score, status)
groups        (id, name, description, invite_code, points_exact, points_result,
               streak_bonus, duel_enabled, created_at, updated_at)
group_members (id, #group_id, #profile_id, role, total_points,
               current_streak, best_streak, joined_at)
predictions   (id, #group_id, #profile_id, #match_id, home_score_pred,
               away_score_pred, points_earned, created_at, updated_at)
```

## MPD — schéma physique exact

Utiliser ces noms de colonnes tels quels dans les requêtes.

### profiles

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK, FK → auth.users(id) ON DELETE CASCADE |
| username | varchar(20) | NOT NULL, UNIQUE, ≥ 3 caractères |
| display_name | varchar(50) | NULL |
| avatar_icon | varchar(30) | NOT NULL, DEFAULT 'ball' |
| avatar_color | char(7) | NOT NULL, DEFAULT '#FFB020' |
| created_at | timestamptz | NOT NULL, DEFAULT now() |

### leagues

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| name | varchar(100) | NOT NULL, UNIQUE |
| country | varchar(50) | NOT NULL |
| color_primary / color_secondary / color_text | char(7) | NOT NULL, format `#RRGGBB` |

### teams

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| league_id | uuid | FK → leagues, RESTRICT |
| short_name | varchar(5) | NOT NULL — sert au monogramme |
| name | varchar(100) | NOT NULL, UNIQUE |
| color_primary / color_secondary / color_text | char(7) | NOT NULL |

### matches

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| league_id | uuid | FK → leagues, RESTRICT |
| home_team_id | uuid | FK → teams, RESTRICT |
| away_team_id | uuid | FK → teams, RESTRICT, CHECK ≠ home |
| kickoff_at | timestamptz | NOT NULL, INDEX |
| home_score | smallint | NULL, CHECK 0..20 |
| away_score | smallint | NULL, CHECK 0..20 |
| status | match_status | NOT NULL, DEFAULT 'scheduled' |

`CHECK (status <> 'finished' OR scores NOT NULL)` — un match terminé a
forcément ses deux scores.

### groups

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| name | varchar(50) | NOT NULL, 3 à 50 caractères |
| description | varchar(200) | NULL |
| invite_code | char(6) | NOT NULL, UNIQUE, généré par la base |
| points_exact | smallint | NOT NULL, DEFAULT 3 |
| points_result | smallint | NOT NULL, DEFAULT 1, CHECK exact > result |
| streak_bonus | smallint | NOT NULL, DEFAULT 0 — **ne pas utiliser** |
| duel_enabled | boolean | NOT NULL, DEFAULT false — **ne pas utiliser** |
| created_at | timestamptz | NOT NULL |
| updated_at | timestamptz | NULL, renseigné par trigger |

### group_members

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| group_id | uuid | FK → groups, CASCADE |
| profile_id | uuid | FK → profiles, CASCADE |
| role | member_role | NOT NULL, DEFAULT 'member' |
| total_points | integer | NOT NULL, DEFAULT 0 — **écriture serveur uniquement** |
| current_streak / best_streak | smallint | NOT NULL, DEFAULT 0 — **serveur uniquement** |
| joined_at | timestamptz | NOT NULL |

`UNIQUE (group_id, profile_id)` · index partiel `UNIQUE (group_id) WHERE role = 'admin'`

### predictions

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| group_id | uuid | FK → groups, CASCADE |
| profile_id | uuid | FK → profiles, CASCADE |
| match_id | uuid | FK → matches, **RESTRICT** |
| home_score_pred | smallint | NOT NULL, CHECK 0..20 |
| away_score_pred | smallint | NOT NULL, CHECK 0..20 |
| points_earned | smallint | **NULL = non calculé, 0 = calculé sans point** |
| created_at | timestamptz | NOT NULL |
| updated_at | timestamptz | NULL, trigger |

`UNIQUE (group_id, profile_id, match_id)` — c'est RG-02.

### Types énumérés

```sql
match_status : 'scheduled' | 'live' | 'finished'
member_role  : 'admin' | 'member'
```

---

# 4. Règles de gestion

| Code | Règle | Où elle est appliquée |
|---|---|---|
| **RG-01** | Pronostic créable/modifiable uniquement avant le coup d'envoi | **RLS côté serveur** + confort UI |
| **RG-02** | Un seul pronostic par membre / match / groupe | contrainte UNIQUE |
| **RG-03** | Score exact → points_exact · bon résultat → points_result · sinon 0 | fonction `compute_points` |
| **RG-04** | Barème par défaut 3 / 1 / 0, paramétrable par groupe | DEFAULT en base |
| **RG-05** | Points calculés une seule fois | filtre `points_earned is null` |
| **RG-06** | Code d'invitation : 6 caractères, sans O, 0, I, 1 | CHECK + fonction de génération |
| **RG-07** | Pronostics d'un groupe visibles par ses membres seulement | politique RLS |
| **RG-08** | Pronostics des autres masqués avant le coup d'envoi | politique RLS |
| **RG-09** | Exactement un administrateur par groupe | index unique partiel |
| **RG-10** | Égalité au classement → départage au nombre de scores exacts | fonction `group_leaderboard` |
| **RG-11** | Départ de l'admin → transmission au membre le plus ancien | trigger |

---

# 5. Back-end — déjà déployé

## Ce qui est garanti côté serveur

- **16 politiques RLS** — refus par défaut, autorisation explicite
- **5 triggers** — création du profil, transmission admin, horodatage,
  code d'invitation, admin au créateur
- **8 fonctions**

## Fonctions appelables par le client

| Fonction | Paramètres | Retour |
|---|---|---|
| `find_group_by_code` | `p_code text` | id, name, member_count — code exact uniquement |
| `group_leaderboard` | `p_group_id uuid` | profile_id, username, avatar_icon, avatar_color, total_points, exact_scores, rank |
| `my_stats` | — | total_predictions, exact_scores, correct_outcomes, total_points, success_rate |
| `compute_points` | scores + barème | int — affichage prévisionnel, n'écrit rien |

## Écritures impossibles depuis le client

`predictions.points_earned` · `group_members.total_points` ·
`current_streak` · `best_streak` · toute la table `matches`.

Vérifié par 20 tentatives de contournement, toutes refusées.

## Ce qui se fait automatiquement — ne pas le coder côté Flutter

- **Création du profil** à l'inscription : passer le pseudo dans
  `data: {'username': ...}` de `signUp`, le trigger fait le reste
- **Code d'invitation** : généré par la base, ne pas l'envoyer
- **Créateur = admin** : le trigger l'inscrit, ne pas faire d'insert
- **`updated_at`** : renseigné par trigger

## Jeu de données

6 championnats, 102 équipes, 357 matchs — dont ~153 terminés, ~12 en
direct, ~192 ouverts aux pronostics.

Dates relatives à `now()` : le jeu reste cohérent quelle que soit la
date, et peut être rechargé la veille d'une démonstration.

**Aucun logo.** Les monogrammes sont générés à partir de `short_name`
et des trois couleurs de chaque équipe.

---

# 6. Architecture Flutter

```
lib/
  core/          theme.dart · exceptions.dart · config.dart
  models/        models.dart
  repositories/  repositories.dart (interfaces)
                 supabase_repositories.dart (implémentations)
  providers/     providers.dart — Riverpod
  screens/       ← à créer
  widgets/       ← à créer
```

## Règles non négociables

1. **Aucun écran n'appelle Supabase directement.** Les écrans passent
   par les providers, qui exposent les interfaces de repositories.
2. **Les repositories sont des interfaces.** C'est ce qui rend
   l'application testable sans base de données — via
   `ProviderScope(overrides: [...])`.
3. **Pas de logique métier dans les widgets.**
4. **Les erreurs techniques sont traduites** en exceptions métier par
   `_translate` dans `supabase_repositories.dart`. Le code `42501`
   (violation RLS) devient `PredictionLockedException`.

## Stack

Flutter 3.44.2 · Dart 3.12.2 · `supabase_flutter` ^2.8.0 ·
`flutter_riverpod` ^2.6.1 · `intl` ^0.19.0 · `mocktail` ^1.0.4

macOS, cible iOS. Android non configuré.

## Lancement

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Les secrets ne sont jamais versionnés.

---

# 7. Design

Direction « **Tableau d'affichage** » : l'univers du panneau de scores
d'un stade au crépuscule, pas la pelouse verte.

**Référence visuelle : `docs/maquettes.html`** — les 7 écrans, à ouvrir
dans un navigateur.

## Couleurs

Jetons dans `lib/core/theme.dart`. **Jamais de couleur codée en dur.**

| Nom | Hex | Rôle |
|---|---|---|
| `nuit` | `#0B1220` | fond de l'application |
| `tribune` | `#16203A` | cartes, champs, surfaces élevées |
| `tribune2` | `#1E2A47` | surface au-dessus d'une carte |
| `craie` | `#F2F5FF` | texte principal |
| `ardoise` | `#7C89A8` | texte secondaire, icônes inactives |
| `or` | `#FFB020` | **accent unique** — points, boutons, actif, direct |
| `exact` | `#5CE28A` | **RÉSERVÉ au score exact** |
| `alerte` | `#FF6B6B` | erreurs, déconnexion |
| `ligne` | `rgba(242,245,255,.10)` | bordures |

> **Contrainte non négociable** : `exact` ne sert **qu'**à signaler un
> score exact. Pas de bouton vert, pas de message de succès vert.
> C'est ce qui donne son poids visuel à l'information.

Palette vérifiée en contraste WCAG AA.

## Typographie

| Rôle | Police | Usage |
|---|---|---|
| Display | **Archivo** 800-900 | titres, wordmark — **toujours en capitales** |
| Corps | **Instrument Sans** 400-600 | texte courant |
| Données | **Azeret Mono** | scores, codes, heures, eyebrows |

La mono pour les chiffres n'est pas décorative : la chasse fixe permet
aux scores et aux totaux de s'aligner verticalement dans un classement.

## Échelle

Espacement : 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40
Rayons : s 10 · m 14 · l 20 · xl 28
Boutons : 40 / 46 / 50
Marge latérale d'écran : **18 px**

## Composants

- **Monogramme d'équipe** — carré 32 px (52 en grand), rayon 9,
  initiales en Archivo 800, couleurs du club. Aucune image.
- **Carte match** — fond `tribune`, en-tête compétition + heure,
  deux lignes équipe, pied avec état du pronostic
- **Badges** — `à pronostiquer` (or) · `enregistré` (ardoise) ·
  `score exact` (exact) · `direct` (or + pastille)

## Élément signature — écran E3

Le **sélecteur de score en volets** : deux tuiles 74 × 88 façon panneau
d'aéroport (dégradé haut/bas avec filet central), boutons − / + de
30 × 26 en dessous, barre de verrouillage « 🔒 modifiable jusqu'à HH:MM ».

**Ne pas remplacer par un TextField.** Justification : un clavier
numérique masque la moitié de l'écran et exige de viser un champ. Le
sélecteur se manipule au pouce, d'une main, sans regarder — c'est le
geste central de l'application.

---

# 8. Conventions de code

- Widgets granulaires, extraits dans `widgets/`
- `const` partout où c'est possible
- `dispose()` systématique sur les controllers
- Commentaires en français, sobres, expliquant le **pourquoi**
- Pas de `print`
- `flutter analyze` doit passer **sans aucun avertissement**

---

# 9. Attentes de la certification

Le jury évalue des **compétences**, pas un nombre de fonctionnalités.

Ce qui compte le plus :

- application **sécurisée** et **organisée en couches**
- **composants métier** séparés de l'interface
- **composants d'accès aux données**
- **plan de tests exécuté** — les tests unitaires sont obligatoires
- déploiement documenté

**Conséquence :** mieux vaut 7 écrans testés qu'un périmètre plus large
sans tests.

## Fil rouge du dossier

La fonctionnalité **« saisir un pronostic »** sert au diagramme de
séquence, au jeu d'essai, aux extraits de code annexés et à la
démonstration. C'est elle qu'il faut soigner en priorité.

---

# 10. Points de vigilance

1. **Le code Dart existant n'a jamais été compilé.** Premier travail :
   `flutter analyze` et corriger.
2. **Ne pas ajouter de dépendance** sans nécessité — chaque ajout doit
   être justifiable à l'oral.
3. **Ne pas contourner les repositories.**
4. **Tester la logique métier**, pas seulement l'affichage.
5. **Ne pas élargir le périmètre.**
6. **Ne pas modifier l'architecture** — les interfaces et le découpage
   en couches sont des choix de conception à défendre devant un jury.

---

# 11. État réel au 13 septembre 2026 — écarts avec ce document

Ce document a été écrit comme une cible, avant que le code existe. Le
tableau ci-dessous liste ce qui, en pratique, diffère de ce qui est
décrit plus haut. Voir aussi [`supabase/NOTES.md`](supabase/NOTES.md)
pour le détail des correctifs backend.

| Décrit ci-dessus | Réalité | Décision |
|---|---|---|
| Backend « déployé et testé » | Tables présentes, mais aucun GRANT, 0 politique RLS sur 6 tables sur 7, 3 fonctions absentes | Corrigé — voir `supabase/schema_complete.sql` |
| Android non configuré (implicite) | Retiré du projet | iOS + Web uniquement, à la demande |
| RG-01 : pronostic modifiable jusqu'au coup d'envoi | Immuable dès l'enregistrement | Choix produit assumé, appliqué aussi côté serveur |
| Un pronostic par groupe (implicite dans le MCD) | Un seul geste de saisie, répliqué sur tous les groupes de l'utilisateur | Choix produit — la ligne par groupe du MLD est conservée, seule la saisie est unifiée |
| 7 écrans listés | E0 (landing) ajouté, non compté dans le périmètre officiel ; E5 enrichi d'un onglet historique des pronostics (activable par groupe) | Ajouts mineurs à l'écran groupe, pas de nouvel écran |
| Avatars : `avatar_icon`/`avatar_color` sur `profiles` | Mêmes colonnes ajoutées sur `groups` (sticker de groupe) ; rendu en `Icons` Flutter plutôt qu'emoji | Cohérence visuelle demandée en cours de projet |
