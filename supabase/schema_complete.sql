-- =============================================================================
-- PronoFoot — état final du schéma côté client (au-dessus du MPD d'origine)
-- =============================================================================
--
-- Ce fichier réunit, dans l'ordre, tout ce que l'application attend côté
-- Supabase : colonnes ajoutées, fonctions, droits (GRANT), politiques RLS.
-- Il est réécrit pour être lu d'une traite (comme un schéma final), pas comme
-- un historique — l'historique des découvertes est dans NOTES.md.
--
-- Sans danger à rejouer : chaque instruction est idempotente
-- (`create or replace`, `if not exists`, `drop policy if exists`).
--
-- Prérequis : les tables du MPD (profiles, leagues, teams, matches, groups,
-- group_members, predictions) et leurs contraintes existent déjà, ainsi que
-- les triggers handle_new_user, handle_new_group, transfer_group_admin,
-- set_updated_at, generate_invite_code et les fonctions de notation
-- (compute_points, match_outcome, score_match, score_pending_matches).

-- -----------------------------------------------------------------------------
-- 1. Colonnes ajoutées à `groups` (absentes du MPD d'origine)
-- -----------------------------------------------------------------------------

alter table public.groups
  add column if not exists avatar_icon varchar(30) not null default 'ball',
  add column if not exists avatar_color char(7) not null default '#FFB020',
  add column if not exists show_prediction_history boolean not null default true;

-- -----------------------------------------------------------------------------
-- 2. Fonctions
-- -----------------------------------------------------------------------------

-- Vérifie l'appartenance à un groupe sans jamais passer par la RLS de
-- group_members : appelée par plusieurs politiques ci-dessous, une requête
-- directe créerait une boucle (la policy de group_members se relirait
-- elle-même). SECURITY DEFINER contourne ce problème.
create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group_id and profile_id = auth.uid()
  );
$$;

-- Même principe, pour vérifier le rôle admin (paramètres du groupe, retrait
-- d'un membre).
create or replace function public.is_group_admin(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group_id and profile_id = auth.uid() and role = 'admin'
  );
$$;

-- RG-06 : recherche par code exact, avant même d'être membre — la RLS sur
-- `groups` interdirait sinon de lire le groupe. SECURITY DEFINER nécessaire.
create or replace function public.find_group_by_code(p_code text)
returns table (
  id uuid,
  name varchar,
  member_count integer
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    g.id,
    g.name,
    (select count(*) from public.group_members gm
       where gm.group_id = g.id)::int as member_count
  from public.groups g
  where upper(g.invite_code) = upper(p_code);
$$;

-- RG-10 : classement, départage au nombre de scores exacts. SECURITY
-- INVOKER : l'appelant doit déjà être membre pour voir les group_members.
create or replace function public.group_leaderboard(p_group_id uuid)
returns table (
  profile_id uuid,
  username varchar,
  avatar_icon varchar,
  avatar_color char(7),
  total_points integer,
  exact_scores integer,
  rank integer
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select
    gm.profile_id,
    pr.username,
    pr.avatar_icon,
    pr.avatar_color,
    gm.total_points,
    coalesce(ex.exact_scores, 0)::int as exact_scores,
    rank() over (
      order by gm.total_points desc, coalesce(ex.exact_scores, 0) desc
    )::int as rank
  from public.group_members gm
  join public.profiles pr on pr.id = gm.profile_id
  left join (
    select p.profile_id, count(*) as exact_scores
    from public.predictions p
    join public.groups g on g.id = p.group_id
    where p.group_id = p_group_id
      and p.points_earned = g.points_exact
    group by p.profile_id
  ) ex on ex.profile_id = gm.profile_id
  where gm.group_id = p_group_id
  order by rank;
$$;

-- Statistiques personnelles agrégées (E6), tous groupes confondus.
create or replace function public.my_stats()
returns table (
  total_predictions integer,
  exact_scores integer,
  correct_outcomes integer,
  total_points integer,
  success_rate numeric
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select
    count(*)::int as total_predictions,
    count(*) filter (where p.points_earned = g.points_exact)::int
      as exact_scores,
    count(*) filter (where p.points_earned = g.points_result)::int
      as correct_outcomes,
    coalesce(sum(p.points_earned), 0)::int as total_points,
    case
      when count(*) filter (where p.points_earned is not null) = 0 then 0
      else round(
        100.0 * count(*) filter (where p.points_earned > 0)
        / count(*) filter (where p.points_earned is not null),
        1
      )
    end as success_rate
  from public.predictions p
  join public.groups g on g.id = p.group_id
  where p.profile_id = auth.uid();
$$;

-- Crée un groupe ET la ligne d'admin dans le même contexte SECURITY
-- DEFINER : un simple `insert ... returning` échouerait, la RLS vérifiant
-- l'appartenance avant que le trigger ait pu créer cette ligne.
create or replace function public.create_group(
  p_name text,
  p_description text default null,
  p_points_exact integer default 3,
  p_points_result integer default 1,
  p_avatar_icon text default 'ball',
  p_avatar_color text default '#FFB020'
)
returns public.groups
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_group public.groups;
begin
  insert into public.groups
    (name, description, points_exact, points_result, avatar_icon, avatar_color)
  values
    (p_name, p_description, p_points_exact, p_points_result,
     p_avatar_icon, p_avatar_color)
  returning * into v_group;

  -- Filet de sécurité : ne fait rien si le trigger handle_new_group a déjà
  -- créé la ligne (cas normal).
  insert into public.group_members (group_id, profile_id, role)
  values (v_group.id, auth.uid(), 'admin')
  on conflict (group_id, profile_id) do nothing;

  return v_group;
end;
$$;

drop function if exists public.create_group(text, text, integer, integer);

grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.is_group_admin(uuid) to authenticated;
grant execute on function public.find_group_by_code(text) to authenticated;
grant execute on function public.group_leaderboard(uuid) to authenticated;
grant execute on function public.my_stats() to authenticated;
grant execute on function
  public.create_group(text, text, integer, integer, text, text)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Droits table-level (GRANT)
-- -----------------------------------------------------------------------------
-- Nécessaires en plus des politiques RLS : Postgres vérifie le GRANT avant
-- même d'évaluer une politique. Sans lui, la RLS ne joue jamais son rôle de
-- filtre, l'accès est refusé en amont pour tout le monde.

grant select on public.leagues to authenticated, anon;
grant select on public.teams   to authenticated, anon;
grant select on public.matches to authenticated, anon;

grant select, update on public.profiles to authenticated;

grant select, insert on public.groups to authenticated;
revoke update on public.groups from authenticated;
grant update (name, description, points_exact, points_result,
              avatar_icon, avatar_color, show_prediction_history)
  on public.groups to authenticated;

grant select, insert, delete on public.group_members to authenticated;

grant select, insert on public.predictions to authenticated;
-- Un pronostic n'est ni modifiable ni supprimable une fois enregistré
-- (choix produit — RG-01 du dossier autorisait la modification jusqu'au
-- coup d'envoi, ce comportement a été volontairement resserré).
revoke update, delete on public.predictions from authenticated;

-- -----------------------------------------------------------------------------
-- 4. Politiques RLS
-- -----------------------------------------------------------------------------

-- profiles : lecture ouverte (pseudo/avatar non sensibles, utile pour les
-- classements et la liste des pronostics du groupe), écriture sur soi-même.
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated" on public.profiles
  for select to authenticated using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Référence sportive : lecture publique, jamais écrite par le client.
drop policy if exists "leagues_select_public" on public.leagues;
create policy "leagues_select_public" on public.leagues
  for select to authenticated, anon using (true);

drop policy if exists "teams_select_public" on public.teams;
create policy "teams_select_public" on public.teams
  for select to authenticated, anon using (true);

drop policy if exists "matches_select_public" on public.matches;
create policy "matches_select_public" on public.matches
  for select to authenticated, anon using (true);

-- groups : visible par ses membres, création libre, modification par l'admin.
drop policy if exists "groups_select_member" on public.groups;
create policy "groups_select_member" on public.groups
  for select to authenticated
  using (public.is_group_member(groups.id));

drop policy if exists "groups_insert_any_authenticated" on public.groups;
create policy "groups_insert_any_authenticated" on public.groups
  for insert to authenticated with check (true);

drop policy if exists "groups_update_admin" on public.groups;
create policy "groups_update_admin" on public.groups
  for update to authenticated
  using (public.is_group_admin(groups.id))
  with check (public.is_group_admin(groups.id));

-- group_members : visible par les membres du même groupe, on peut rejoindre
-- (insert sur soi-même) et quitter / être retiré (delete, soi-même ou admin).
-- Pas de policy update : total_points et les streaks restent serveur
-- uniquement (RLS bloque tout UPDATE client, même avec un GRANT table-level).
drop policy if exists "group_members_select_same_group" on public.group_members;
create policy "group_members_select_same_group" on public.group_members
  for select to authenticated
  using (public.is_group_member(group_members.group_id));

drop policy if exists "group_members_insert_self" on public.group_members;
create policy "group_members_insert_self" on public.group_members
  for insert to authenticated with check (profile_id = auth.uid());

drop policy if exists "group_members_delete_self_or_admin" on public.group_members;
create policy "group_members_delete_self_or_admin" on public.group_members
  for delete to authenticated
  using (
    profile_id = auth.uid()
    or public.is_group_admin(group_members.group_id)
  );

-- predictions : RG-07 (membres du groupe seulement), RG-08 (pronostics des
-- autres masqués avant le coup d'envoi), RG-01 (créable avant le coup
-- d'envoi). Pas de policy update/delete : immuable une fois enregistré.
drop policy if exists "predictions_select_own_or_after_kickoff" on public.predictions;
create policy "predictions_select_own_or_after_kickoff" on public.predictions
  for select to authenticated
  using (
    profile_id = auth.uid()
    or (
      public.is_group_member(predictions.group_id)
      and exists (
        select 1 from public.matches m
        where m.id = predictions.match_id and m.kickoff_at <= now()
      )
    )
  );

drop policy if exists "predictions_insert_own_before_kickoff" on public.predictions;
create policy "predictions_insert_own_before_kickoff" on public.predictions
  for insert to authenticated
  with check (
    profile_id = auth.uid()
    and public.is_group_member(predictions.group_id)
    and exists (
      select 1 from public.matches m
      where m.id = predictions.match_id
        and m.status = 'scheduled' and m.kickoff_at > now()
    )
  );
