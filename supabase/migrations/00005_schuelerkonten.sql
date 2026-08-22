-- =====================================================================
-- Die Akademie – Migration 05
-- Schülerkonten, getrennte Klarnamen, Rolle "schueler"
-- =====================================================================
--
-- Kinder bekommen jetzt eigene Zugänge. Zwei Dinge sind dabei bewusst
-- so und nicht anders gelöst:
--
-- 1. KEINE E-Mail-Adressen von Kindern.
--    Der Zugang besteht aus einem Loginnamen und einem Passwort, beides
--    von der Lehrkraft vergeben. Damit Supabase-Auth damit umgehen kann,
--    setzt die Anwendung im Hintergrund eine technische Adresse der Form
--    <loginname>@akademie.local zusammen. Diese Adresse existiert nicht,
--    empfängt nichts und wird nirgends angezeigt.
--
-- 2. Klarnamen liegen in einer EIGENEN Tabelle.
--    Row-Level-Security wirkt auf Zeilen, nicht auf einzelne Spalten.
--    Stünde der Klarname in public.schueler, könnte ihn jedes Kind
--    mitlesen, das seine eigene Zeile abruft – und über die Mitschüler-
--    liste auch die der anderen. Eine eigene Tabelle mit eigener Regel
--    ist die einzige Art, das sauber zu trennen.
--
--    Angezeigt wird IMMER der Akademiename, nie der Klarname.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Die Rolle "schueler"
-- ---------------------------------------------------------------------

alter table public.user_roles drop constraint if exists user_roles_role_check;
alter table public.user_roles
  add constraint user_roles_role_check
  check (role in ('admin', 'teacher', 'viewer', 'schueler'));


-- ---------------------------------------------------------------------
-- 2. Loginname am Schüler
-- ---------------------------------------------------------------------

alter table public.schueler add column if not exists login_name text;

-- Kleinschreibung und keine Leerzeichen: sonst scheitert die Anmeldung
-- an einer Großschreibung, die beim Anlegen niemand mehr erinnert.
alter table public.schueler drop constraint if exists schueler_login_name_form;
alter table public.schueler
  add constraint schueler_login_name_form
  check (login_name is null or login_name ~ '^[a-z0-9][a-z0-9._-]{2,31}$');

create unique index if not exists idx_schueler_login_name
  on public.schueler (login_name)
  where login_name is not null;

-- Die technische Adresse, unter der Supabase das Kind kennt.
-- Sie enthält ABSICHTLICH einen Zufallsanteil und ist nicht aus dem
-- Loginnamen ableitbar:
--
--   Ein Passwort lässt sich mit dem öffentlichen Schlüssel allein nicht
--   ändern – dafür bräuchte man den geheimen Verwaltungsschlüssel, der
--   niemals in den Browser gehört. Zum Zurücksetzen legt die Anwendung
--   deshalb ein neues Konto mit neuem Zufallsanteil an und hängt das Kind
--   dort ein. Der Loginname bleibt derselbe, das Kind merkt nur, dass sein
--   Passwort neu ist. Das alte Konto bleibt als Karteileiche zurück, hat
--   aber keine Rolle mehr und kann damit nichts mehr sehen.
alter table public.schueler add column if not exists auth_email text;

create unique index if not exists idx_schueler_auth_email
  on public.schueler (auth_email)
  where auth_email is not null;

comment on column public.schueler.auth_email is
  'Technische Anmeldeadresse (<login>-<zufall>@akademie.local). Nie anzeigen.';

comment on column public.schueler.login_name is
  'Loginname des Kindes. Damit meldet es sich an; die zugehörige technische '
  'Adresse steht in auth_email.';
comment on column public.schueler.akademiename is
  'Der Anzeigename. Steht überall dort, wo das Kind sichtbar wird.';


-- ---------------------------------------------------------------------
-- 3. Klarnamen – getrennt und nur für Lehrkräfte
-- ---------------------------------------------------------------------

create table if not exists public.schueler_klarnamen (
  schueler_id uuid primary key references public.schueler(id) on delete cascade,
  klarname text not null check (length(trim(klarname)) > 0),
  notiz text,
  updated_at timestamptz not null default now()
);

comment on table public.schueler_klarnamen is
  'Nur für Lehrkräfte. Getrennt von public.schueler, weil RLS auf Zeilen '
  'wirkt und nicht auf Spalten – in derselben Tabelle wäre der Klarname '
  'für die Kinder mitlesbar.';

alter table public.schueler_klarnamen enable row level security;

drop policy if exists "klarnamen_lehrkraefte" on public.schueler_klarnamen;
create policy "klarnamen_lehrkraefte" on public.schueler_klarnamen
  for all using (public.hat_rolle(array['admin', 'teacher']))
  with check (public.hat_rolle(array['admin', 'teacher']));


-- ---------------------------------------------------------------------
-- 4. Wer bin ich?
-- ---------------------------------------------------------------------
-- security definer, damit die Funktion nicht selbst an der RLS von
-- public.schueler scheitert – dieselbe Falle wie bei hat_rolle().

create or replace function public.mein_schueler_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.schueler where user_id = auth.uid() limit 1;
$$;

create or replace function public.mein_haus_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select haus_id from public.schueler where user_id = auth.uid() limit 1;
$$;

revoke all on function public.mein_schueler_id() from public;
revoke all on function public.mein_haus_id() from public;

do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('grant execute on function public.mein_schueler_id() to %I', r);
      execute format('grant execute on function public.mein_haus_id() to %I', r);
    end if;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 4b. Loginname -> Anmeldeadresse
-- ---------------------------------------------------------------------
-- Beim Anmelden ist noch niemand angemeldet, public.schueler ist also
-- gesperrt. Diese Funktion darf deshalb ausdrücklich auch von nicht
-- angemeldeten Besuchern aufgerufen werden.
--
-- Sie gibt NUR die technische Adresse zurück, keinen Namen, kein Haus,
-- keine Punkte. Wer damit Loginnamen durchprobiert, erfährt lediglich,
-- ob ein Name vergeben ist – dasselbe verrät jeder Anmeldeversuch auch.

create or replace function public.login_adresse(p_login text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select auth_email
    from public.schueler
   where login_name = lower(trim(p_login))
     and auth_email is not null
   limit 1;
$$;

revoke all on function public.login_adresse(text) from public;

do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('grant execute on function public.login_adresse(text) to %I', r);
    end if;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 5. Was ein Kind sehen darf
-- ---------------------------------------------------------------------

-- Die eigene Zeile und die Mitglieder des eigenen Hauses. Kinder sehen
-- also ihr Haus, aber keine fremden Häuser.
drop policy if exists "schueler_eigenes_haus_lesen" on public.schueler;
create policy "schueler_eigenes_haus_lesen" on public.schueler
  for select using (
    haus_id = public.mein_haus_id()
  );

-- Eigene Punktebuchungen
drop policy if exists "transaktionen_eigene_lesen" on public.punkte_transaktionen;
create policy "transaktionen_eigene_lesen" on public.punkte_transaktionen
  for select using (
    schueler_id = public.mein_schueler_id()
  );

-- Eigene Einlösungen
drop policy if exists "einloesungen_eigene_lesen" on public.einloesungen;
create policy "einloesungen_eigene_lesen" on public.einloesungen
  for select using (
    schueler_id = public.mein_schueler_id()
  );

-- Die eigene Rolle darf jede angemeldete Person schon lesen
-- (Policy user_roles_eigene_lesen aus Migration 03).


-- ---------------------------------------------------------------------
-- 6. Lehrkräfte dürfen Zugänge einrichten
-- ---------------------------------------------------------------------
-- Bisher durfte nur ein Admin in user_roles schreiben. Damit auch
-- Kolleginnen und Kollegen Zugänge anlegen können, darf eine Lehrkraft
-- Einträge anlegen – aber ausdrücklich NUR mit der Rolle 'schueler'.
-- Ohne diese Einschränkung könnte sich eine Lehrkraft selbst zum Admin
-- machen.

drop policy if exists "user_roles_lehrkraefte_schueler_anlegen" on public.user_roles;
create policy "user_roles_lehrkraefte_schueler_anlegen" on public.user_roles
  for insert with check (
    role = 'schueler' and public.hat_rolle(array['admin', 'teacher'])
  );

-- Anlegen allein genügt nicht: Ohne Leserecht könnte die Lehrkraft nach dem
-- Anlegen nicht prüfen, ob es geklappt hat, und ohne Löschrecht einen Zugang
-- nie wieder entziehen. Beides ausdrücklich auf role = 'schueler' begrenzt –
-- Einträge von Admins und Kolleginnen bleiben unsichtbar und unantastbar.
drop policy if exists "user_roles_lehrkraefte_schueler_lesen" on public.user_roles;
create policy "user_roles_lehrkraefte_schueler_lesen" on public.user_roles
  for select using (
    role = 'schueler' and public.hat_rolle(array['admin', 'teacher'])
  );

drop policy if exists "user_roles_lehrkraefte_schueler_entziehen" on public.user_roles;
create policy "user_roles_lehrkraefte_schueler_entziehen" on public.user_roles
  for delete using (
    role = 'schueler' and public.hat_rolle(array['admin', 'teacher'])
  );


-- ---------------------------------------------------------------------
-- 7. Kontrolle
-- ---------------------------------------------------------------------

select tablename, policyname, cmd
  from pg_policies
 where schemaname = 'public'
   and tablename in ('schueler', 'schueler_klarnamen', 'user_roles')
 order by tablename, policyname;
