-- =====================
-- Die Akademie – Supabase Schema
-- =====================

-- Enable extensions
create extension if not exists "uuid-ossp";

-- =====================
-- TABLES
-- =====================

-- User roles
create table public.user_roles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade not null unique,
  role text not null check (role in ('admin', 'teacher', 'viewer')),
  created_at timestamptz not null default now()
);

-- Bereiche (Subjects / Grade Levels / Allgemein)
create table public.bereiche (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  slug text not null unique,
  typ text not null check (typ in ('fach', 'klassenstufe', 'allgemein')),
  beschreibung text,
  logo_url text,
  banner_url text,
  farbe_primär text,
  farbe_sekundär text,
  motto text,
  verantwortlich text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Häuser / Klassen
create table public.haeuser (
  id uuid primary key default uuid_generate_v4(),
  bereich_id uuid references public.bereiche(id) on delete cascade not null,
  name text not null,
  hausname text not null,
  slug text not null unique,
  logo_url text,
  banner_url text,
  farbe_primär text not null default '#1e3a5f',
  farbe_sekundär text not null default '#d4a74a',
  motto text,
  beschreibung text,
  lehrer_id uuid references auth.users(id) on delete set null,
  energie integer not null default 100,
  energie_max integer not null default 100,
  hauspunkte integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Schüler
create table public.schueler (
  id uuid primary key default uuid_generate_v4(),
  haus_id uuid references public.haeuser(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  akademiename text not null,
  avatar_url text,
  wappen_url text,
  motto text,
  titel text,
  xp integer not null default 0,
  level integer not null default 1,
  punkte integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Punktetransaktionen
create table public.punkte_transaktionen (
  id uuid primary key default uuid_generate_v4(),
  schueler_id uuid references public.schueler(id) on delete cascade not null,
  haus_id uuid references public.haeuser(id) on delete cascade,
  bereich_id uuid references public.bereiche(id) on delete cascade,
  betrag integer not null,
  kategorie text not null check (kategorie in ('lernen', 'sozialverhalten', 'selbstständigkeit', 'diskussion', 'demokratie', 'persönliche_entwicklung', 'verantwortung', 'quest')),
  grund text not null,
  lehrer_id uuid references auth.users(id) on delete set null not null,
  created_at timestamptz not null default now()
);

-- Quests
create table public.quests (
  id uuid primary key default uuid_generate_v4(),
  titel text not null,
  beschreibung text not null,
  schwierigkeit integer not null default 1 check (schwierigkeit between 1 and 5),
  belohnung_hauspunkte integer not null default 0,
  belohnung_xp integer not null default 0,
  abzeichen_id uuid,
  gültigkeitsbereich text not null check (gültigkeitsbereich in ('global', 'fach', 'klassenstufe', 'klasse', 'einzelner')),
  bereich_id uuid references public.bereiche(id) on delete cascade,
  haus_id uuid references public.haeuser(id) on delete cascade,
  schueler_id uuid references public.schueler(id) on delete cascade,
  startdatum timestamptz not null,
  enddatum timestamptz,
  status text not null default 'entwurf' check (status in ('entwurf', 'aktiv', 'abgeschlossen', 'archiviert')),
  created_at timestamptz not null default now()
);

-- Belohnungen
create table public.belohnungen (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  kategorie text not null check (kategorie in ('joker', 'wahlmöglichkeit', 'aktivität', 'challenge', 'legendär')),
  kosten integer not null check (kosten > 0),
  beschreibung text not null,
  gültigkeitsbereich text not null check (gültigkeitsbereich in ('global', 'fach', 'klassenstufe', 'klasse')),
  bereich_id uuid references public.bereiche(id) on delete cascade,
  aktiv boolean not null default true,
  created_at timestamptz not null default now()
);

-- Abzeichen
create table public.abzeichen (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  symbol text not null,
  beschreibung text not null,
  bedingung text not null check (bedingung in ('manuell', 'anzahl_aktionen', 'quest', 'punktzahl', 'besondere_leistung')),
  bedingung_wert integer,
  gültigkeitsbereich text not null check (gültigkeitsbereich in ('global', 'fach', 'klassenstufe', 'klasse')),
  bereich_id uuid references public.bereiche(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Schüler-Abzeichen (Many-to-Many)
create table public.schueler_abzeichen (
  schueler_id uuid references public.schueler(id) on delete cascade not null,
  abzeichen_id uuid references public.abzeichen(id) on delete cascade not null,
  created_at timestamptz not null default now(),
  primary key (schueler_id, abzeichen_id)
);

-- Chronik
create table public.chronik (
  id uuid primary key default uuid_generate_v4(),
  haus_id uuid references public.haeuser(id) on delete cascade not null,
  bereich_id uuid references public.bereiche(id) on delete cascade,
  typ text not null check (typ in ('quest', 'transaktion', 'abzeichen', 'event', 'rekord', 'wettbewerb')),
  titel text not null,
  beschreibung text,
  created_at timestamptz not null default now()
);

-- Kapitel
create table public.kapitel (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  nummer integer not null unique,
  startdatum timestamptz not null,
  enddatum timestamptz,
  beschreibung text,
  freigeschaltet boolean not null default false
);

-- Akademie-Karte Orte
create table public.karte_orte (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  slug text not null unique,
  beschreibung text,
  icon text not null,
  freischaltung_monat integer not null check (freischaltung_monat between 1 and 12),
  freigeschaltet boolean not null default false,
  route text not null
);

-- =====================
-- INDICES
-- =====================

create index idx_user_roles_user_id on public.user_roles(user_id);
create index idx_schueler_user_id on public.schueler(user_id);
create index idx_schueler_haus_id on public.schueler(haus_id);
create index idx_haeuser_bereich_id on public.haeuser(bereich_id);
create index idx_punkte_transaktionen_schueler_id on public.punkte_transaktionen(schueler_id);
create index idx_punkte_transaktionen_created_at on public.punkte_transaktionen(created_at desc);
create index idx_chronik_haus_id on public.chronik(haus_id);
create index idx_chronik_created_at on public.chronik(created_at desc);
create index idx_quests_status on public.quests(status);
create index idx_bereiche_slug on public.bereiche(slug);
create index idx_haeuser_slug on public.haeuser(slug);

-- =====================
-- ROW-LEVEL SECURITY
-- =====================

alter table public.user_roles enable row level security;
alter table public.bereiche enable row level security;
alter table public.haeuser enable row level security;
alter table public.schueler enable row level security;
alter table public.punkte_transaktionen enable row level security;
alter table public.quests enable row level security;
alter table public.belohnungen enable row level security;
alter table public.abzeichen enable row level security;
alter table public.schueler_abzeichen enable row level security;
alter table public.chronik enable row level security;
alter table public.kapitel enable row level security;
alter table public.karte_orte enable row level security;

-- =====================
-- RLS POLICIES
-- =====================

-- Admins can do everything
create policy "admins_all" on public.bereiche for all using (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role = 'admin')
);

-- Teachers can read and write to their assigned areas
create policy "teachers_read_assigned" on public.bereiche for select using (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role in ('admin', 'teacher'))
);

-- Viewers can read
create policy "viewers_read" on public.bereiche for select using (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role in ('admin', 'teacher', 'viewer'))
);

-- Haus policies
create policy "haus_admins_all" on public.haeuser for all using (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role = 'admin')
);

create policy "haus_teachers_read" on public.haeuser for select using (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role in ('admin', 'teacher', 'viewer'))
);

-- Schüler policies
create policy "schueler_admins_all" on public.schueler for all using (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role = 'admin')
);

create policy "schueler_teachers_read" on public.schueler for select using (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role in ('admin', 'teacher'))
);

create policy "schueler_self_read" on public.schueler for select using (
  user_id = auth.uid()
);

-- Punktetransaktionen policies
create policy "transaktionen_admins_all" on public.punkte_transaktionen for all using (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role = 'admin')
);

create policy "transaktionen_teachers_insert" on public.punkte_transaktionen for insert with check (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role in ('admin', 'teacher'))
);

create policy "transaktionen_teachers_read" on public.punkte_transaktionen for select using (
  exists (select 1 from public.user_roles where user_id = auth.uid() and role in ('admin', 'teacher'))
);

-- =====================
-- FUNCTIONS & TRIGGERS
-- =====================

-- Update updated_at trigger
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_bereiche_updated_at
  before update on public.bereiche
  for each row execute function update_updated_at();

create trigger update_haeuser_updated_at
  before update on public.haeuser
  for each row execute function update_updated_at();

create trigger update_schueler_updated_at
  before update on public.schueler
  for each row execute function update_updated_at();

-- XP and Level calculation on transaction insert
create or replace function update_schueler_xp()
returns trigger as $$
declare
  total_xp integer;
  new_level integer;
begin
  select coalesce(sum(belohnung_xp), 0) + coalesce(sum(betrag), 0)
  into total_xp
  from (
    select betrag from public.punkte_transaktionen where schueler_id = new.schueler_id
    union all
    select belohnung_xp from public.quests q
    join public.punkte_transaktionen pt on pt.schueler_id = new.schueler_id and pt.kategorie = 'quest'
  ) sub;

  new_level := floor(total_xp / 100) + 1;

  update public.schueler
  set xp = total_xp, level = new_level, punkte = punkte + new.betrag
  where id = new.schueler_id;

  return new;
end;
$$ language plpgsql;

create trigger after_transaktion_insert
  after insert on public.punkte_transaktionen
  for each row execute function update_schueler_xp();

-- Update hauspunkte on transaction insert
create or replace function update_haus_punkte()
returns trigger as $$
begin
  if new.haus_id is not null then
    update public.haeuser
    set hauspunkte = hauspunkte + new.betrag
    where id = new.haus_id;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger after_transaktion_haus
  after insert on public.punkte_transaktionen
  for each row execute function update_haus_punkte();

-- =====================
-- SEED DATA
-- =====================

-- Karte Orte
insert into public.karte_orte (name, slug, icon, freischaltung_monat, freigeschaltet, route, beschreibung) values
  ('Große Halle', 'grosse-halle', '🏰', 9, true, '/dashboard', 'Der zentrale Treffpunkt mit dem Hauspokal.'),
  ('Bibliothek', 'bibliothek', '📚', 10, true, '/dashboard/quests', 'Hier finden sich Lernquests und Wissenstests.'),
  ('Arena', 'arena', '⚔️', 11, false, '/dashboard/arena', 'Wettbewerbe und Challenges.'),
  ('Turm der Prüfungen', 'turm-pruefungen', '🔮', 1, false, '/dashboard/pruefungen', 'Schwierige Herausforderungen warten.'),
  ('Markt', 'markt', '🛒', 9, true, '/dashboard/markt', 'Der Punkteladen. Löse Punkte gegen Belohnungen ein.'),
  ('Halle des Ruhms', 'halle-ruhms', '🏅', 9, true, '/dashboard/abzeichen', 'Alle Abzeichen auf einen Blick.'),
  ('Chronik', 'chronik', '📜', 9, true, '/dashboard/chronik', 'Vergangene Ereignisse und Erfolge.'),
  ('Thronsaal', 'thronsaal', '👑', 5, false, '/dashboard/finale', 'Das Jahresfinale findet hier statt.');

-- Kapitel
insert into public.kapitel (name, nummer, startdatum, enddatum, beschreibung, freigeschaltet) values
  ('Kapitel I – Die Aufnahmeprüfung', 1, '2026-09-01', '2026-10-15', 'Akademienamen, Wappen, Hauswerte und erste Quests.', true),
  ('Kapitel II – Die erste Prüfung', 2, '2026-10-16', '2026-12-15', 'Fachquests und erste Wettbewerbe.', true),
  ('Kapitel III – Der Rat der Häuser', 3, '2026-12-16', '2027-02-15', 'Kooperation, Demokratie, gemeinsame Entscheidungen.', false),
  ('Kapitel IV – Die große Herausforderung', 4, '2027-02-16', '2027-04-30', 'Größere Projekte und besondere Quests.', false),
  ('Kapitel V – Das Finale', 5, '2027-05-01', '2027-07-31', 'Hauspokal, Auszeichnungen und persönliche Pokale.', false);