# Notes de mise en conformité du backend Supabase

Le dossier de conception (`PROMPT-PROJET.md`) décrivait un backend « déployé
et testé ». En pratique, à la reprise du projet, les tables existaient mais
plusieurs couches attendues par le client n'avaient jamais été créées. Cette
page résume ce qui a été trouvé et corrigé — utile pour expliquer la
démarche de test à l'oral.

## Ce qui manquait

| Constat | Symptôme observé | Fichier concerné dans `schema_complete.sql` |
|---|---|---|
| Aucun `GRANT` sur les 7 tables pour `authenticated`/`anon` | `permission denied for table X` dès la première requête | section 3 |
| 3 fonctions RPC absentes (`find_group_by_code`, `group_leaderboard`, `my_stats`) | `function ... does not exist` | section 2 |
| RLS activée mais **0 politique** sur 6 des 7 tables | Résultats vides sans erreur (accès refusé par défaut) | section 4 |
| Policy `group_members` qui se relit elle-même | `infinite recursion detected in policy` | fonctions `is_group_member` / `is_group_admin` |
| `INSERT ... RETURNING` sur `groups` juste après création | `new row violates row-level security policy` (le trigger qui rend admin n'a pas encore tourné au moment du RETURNING) | fonction `create_group` |
| `GRANT UPDATE` restreint à 2 colonnes sur `predictions` | `permission denied for table predictions` (l'upsert de Supabase inclut toutes les colonnes envoyées dans le `SET`, pas seulement celles qui changent) | section 3 |

## Méthode

Chaque hypothèse a été vérifiée par une requête de diagnostic (lister les
`GRANT`, les policies, les triggers) avant d'écrire un correctif — plutôt que
de deviner. Le mode debug de l'application (`kDebugMode` dans
`translateError`, `lib/repositories/supabase_repositories.dart`) affiche le
code et le message Postgres réels au lieu d'un message générique, ce qui a
accéléré chaque diagnostic.

## Décisions produit prises en cours de route

- **Un pronostic est saisi une seule fois et vaut pour tous les groupes** de
  l'utilisateur (pas de sélection de « groupe actif »). La table garde une
  ligne par groupe — le barème diffère par groupe — mais un seul geste
  client les crée toutes.
- **Un pronostic n'est plus modifiable ni supprimable** une fois enregistré
  (RG-01 du dossier autorisait la modification jusqu'au coup d'envoi ; ce
  comportement a été volontairement resserré).
- **Historique des pronostics par membre**, affichable ou non selon un
  paramètre du groupe (`show_prediction_history`).
