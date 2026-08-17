-- =====================================================================
-- Die Akademie – Migration 03
-- Rollen wieder lesbar machen (behebt "Deine Rolle: keine")
-- =====================================================================
--
-- Das Problem
-- -----------
-- Auf public.user_roles war Row-Level-Security eingeschaltet, es gab aber
-- keine einzige Policy. In Postgres heißt das: niemand darf lesen.
--
-- Die Folgen reichten weiter, als es zunächst aussieht. Sämtliche anderen
-- Regeln prüfen die Rolle so:
--
--     exists (select 1 from public.user_roles
--              where user_id = auth.uid() and role = 'admin')
--
-- Diese Unterabfrage unterliegt ihrerseits der RLS von user_roles. Da dort
-- nichts lesbar war, lieferte sie immer "falsch" – und damit war praktisch
-- die gesamte Anwendung gesperrt, ohne dass irgendwo ein Fehler erschien.
-- Man sah nur überall leere Listen.
--
-- Die Lösung
-- ----------
-- 1. Eine Funktion mit "security definer", die die Rolle nachschlägt.
--    Sie läuft mit den Rechten ihres Eigentümers und umgeht damit die RLS
--    von user_roles. Das ist hier nicht nur bequem, sondern notwendig:
--    Eine Policy AUF user_roles, die selbst user_roles abfragt, würde sich
--    sonst endlos selbst aufrufen.
--
-- 2. Policies auf user_roles: jede Person darf ihre eigene Zeile lesen,
--    Admins dürfen alle verwalten.
--
-- 3. Alle bestehenden Policies auf diese Funktion umstellen. Das ist
--    kürzer, schneller und verhindert, dass derselbe Fehler wiederkehrt.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Rollenprüfung als eigene Funktion
-- ---------------------------------------------------------------------

create or replace function public.hat_rolle(rollen text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.user_roles
     where user_id = auth.uid()
       and role = any(rollen)
  );
$$;

comment on function public.hat_rolle(text[]) is
  'Prüft, ob die angemeldete Person eine der genannten Rollen hat. '
  'security definer, damit die Abfrage nicht an der RLS von user_roles scheitert.';

-- Auch nicht angemeldete Besucher müssen die Funktion aufrufen dürfen.
-- Sie steckt in den Policies mehrerer Tabellen; ohne Ausführungsrecht
-- bekäme die Startseite statt einer leeren Liste einen harten Fehler
-- ("permission denied for function hat_rolle"). Für anon ist auth.uid()
-- leer, die Funktion liefert dann schlicht "falsch".
revoke all on function public.hat_rolle(text[]) from public;

do $$
declare
  r text;
begin
  foreach r in array array['anon', 'authenticated', 'service_role']
  loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('grant execute on function public.hat_rolle(text[]) to %I', r);
    end if;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 2. user_roles lesbar machen
-- ---------------------------------------------------------------------

drop policy if exists "user_roles_eigene_lesen" on public.user_roles;
create policy "user_roles_eigene_lesen" on public.user_roles
  for select using (user_id = auth.uid());

drop policy if exists "user_roles_admins_alles" on public.user_roles;
create policy "user_roles_admins_alles" on public.user_roles
  for all using (public.hat_rolle(array['admin']));


-- ---------------------------------------------------------------------
-- 3. Bestehende Policies auf die Funktion umstellen
-- ---------------------------------------------------------------------

-- Bereiche
drop policy if exists "admins_all" on public.bereiche;
drop policy if exists "teachers_read_assigned" on public.bereiche;
drop policy if exists "viewers_read" on public.bereiche;
drop policy if exists "bereiche_admins_all" on public.bereiche;
drop policy if exists "bereiche_angemeldete_lesen" on public.bereiche;

create policy "bereiche_admins_all" on public.bereiche
  for all using (public.hat_rolle(array['admin']));
create policy "bereiche_angemeldete_lesen" on public.bereiche
  for select using (auth.uid() is not null);

-- Häuser
drop policy if exists "haus_admins_all" on public.haeuser;
drop policy if exists "haus_teachers_read" on public.haeuser;
drop policy if exists "haeuser_admins_all" on public.haeuser;
drop policy if exists "haeuser_angemeldete_lesen" on public.haeuser;

create policy "haeuser_admins_all" on public.haeuser
  for all using (public.hat_rolle(array['admin']));
create policy "haeuser_lehrkraefte_schreiben" on public.haeuser
  for update using (public.hat_rolle(array['admin', 'teacher']));
create policy "haeuser_angemeldete_lesen" on public.haeuser
  for select using (auth.uid() is not null);

-- Schüler
drop policy if exists "schueler_admins_all" on public.schueler;
drop policy if exists "schueler_teachers_read" on public.schueler;
drop policy if exists "schueler_self_read" on public.schueler;

create policy "schueler_admins_all" on public.schueler
  for all using (public.hat_rolle(array['admin']));
-- Lehrkräfte legen Kinder an und pflegen sie – ohne das könnten sie im
-- Haus niemanden eintragen.
create policy "schueler_lehrkraefte_lesen" on public.schueler
  for select using (public.hat_rolle(array['admin', 'teacher']));
create policy "schueler_lehrkraefte_anlegen" on public.schueler
  for insert with check (public.hat_rolle(array['admin', 'teacher']));
create policy "schueler_lehrkraefte_aendern" on public.schueler
  for update using (public.hat_rolle(array['admin', 'teacher']));

-- Punktetransaktionen
drop policy if exists "transaktionen_admins_all" on public.punkte_transaktionen;
drop policy if exists "transaktionen_teachers_insert" on public.punkte_transaktionen;
drop policy if exists "transaktionen_teachers_read" on public.punkte_transaktionen;

create policy "transaktionen_admins_all" on public.punkte_transaktionen
  for all using (public.hat_rolle(array['admin']));
create policy "transaktionen_lehrkraefte_lesen" on public.punkte_transaktionen
  for select using (public.hat_rolle(array['admin', 'teacher']));
create policy "transaktionen_lehrkraefte_buchen" on public.punkte_transaktionen
  for insert with check (public.hat_rolle(array['admin', 'teacher']));

-- Einlösungen
drop policy if exists "einloesungen_admins_all" on public.einloesungen;
drop policy if exists "einloesungen_teachers_read" on public.einloesungen;
drop policy if exists "einloesungen_teachers_insert" on public.einloesungen;

create policy "einloesungen_admins_all" on public.einloesungen
  for all using (public.hat_rolle(array['admin']));
create policy "einloesungen_lehrkraefte_lesen" on public.einloesungen
  for select using (public.hat_rolle(array['admin', 'teacher']));
create policy "einloesungen_lehrkraefte_anlegen" on public.einloesungen
  for insert with check (public.hat_rolle(array['admin', 'teacher']));
-- Stornieren ist ein Update auf storniert = true.
create policy "einloesungen_lehrkraefte_stornieren" on public.einloesungen
  for update using (public.hat_rolle(array['admin', 'teacher']));

-- Chronik: bisher gab es hier GAR KEINE Policy, obwohl RLS an ist.
-- Der Punkteladen schreibt aber nach jedem Einlösen einen Eintrag.
drop policy if exists "chronik_angemeldete_lesen" on public.chronik;
drop policy if exists "chronik_lehrkraefte_schreiben" on public.chronik;
drop policy if exists "chronik_admins_all" on public.chronik;

create policy "chronik_admins_all" on public.chronik
  for all using (public.hat_rolle(array['admin']));
create policy "chronik_angemeldete_lesen" on public.chronik
  for select using (auth.uid() is not null);
create policy "chronik_lehrkraefte_schreiben" on public.chronik
  for insert with check (public.hat_rolle(array['admin', 'teacher']));

-- Die in Migration 02 angelegten Policies ebenfalls auf die Funktion
-- umstellen (sie prüften die Rolle noch mit der alten Unterabfrage).
do $$
declare
  t text;
begin
  foreach t in array array['belohnungen', 'abzeichen', 'quests',
                           'karte_orte', 'kapitel', 'schueler_abzeichen']
  loop
    execute format('drop policy if exists %I on public.%I', t || '_admins_all', t);
    execute format('drop policy if exists %I on public.%I', t || '_angemeldete_lesen', t);
    execute format('drop policy if exists %I on public.%I', t || '_lehrkraefte_schreiben', t);

    execute format(
      'create policy %I on public.%I for all using (public.hat_rolle(array[''admin'']))',
      t || '_admins_all', t);
    execute format(
      'create policy %I on public.%I for select using (auth.uid() is not null)',
      t || '_angemeldete_lesen', t);
    execute format(
      'create policy %I on public.%I for insert with check (public.hat_rolle(array[''admin'', ''teacher'']))',
      t || '_lehrkraefte_schreiben', t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 4. Kontrolle
-- ---------------------------------------------------------------------
-- Nach dem Ausführen sollte hier deine E-Mail mit "admin" und "true"
-- erscheinen. Steht dort nichts, fehlt der Eintrag in user_roles –
-- dann noch einmal 03_admin_rolle.sql ausführen.

select u.email, r.role
  from public.user_roles r
  join auth.users u on u.id = r.user_id;
