-- =====================================================================
-- Die Akademie – Migration 04
-- Heldentaten und geschützter Bildspeicher
-- =====================================================================
--
-- Zwei Dinge kommen dazu:
--
--   1. Heldentaten – festgehaltene Momente, in denen ein Haus oder ein
--      Kind etwas gut gemacht hat, mit Bildern dazu.
--
--   2. Ein Speicher für Bilder, der NICHT öffentlich ist. Fotos aus dem
--      Unterricht zeigen in aller Regel Kinder. Die Seite selbst liegt
--      öffentlich im Netz; die Bilder dürfen das nicht. Deshalb ein
--      privater Bereich, aus dem die Anwendung nur kurzlebige,
--      unterschriebene Links erzeugt.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Häuser bekommen ein Wappen
-- ---------------------------------------------------------------------
-- Gespeichert wird der PFAD im Bildspeicher, nicht eine fertige Adresse.
-- Eine fertige Adresse wäre bei einem privaten Speicher nach kurzer Zeit
-- ungültig – der Pfad bleibt gültig, der Link wird bei jedem Aufruf neu
-- unterschrieben.

alter table public.haeuser add column if not exists logo_pfad text;
alter table public.haeuser add column if not exists banner_pfad text;

comment on column public.haeuser.logo_pfad is
  'Pfad im Bucket "akademie-bilder", z.B. haeuser/<haus-id>/wappen.png';
comment on column public.haeuser.logo_url is
  'Nicht mehr verwendet. Wappen liegen jetzt in logo_pfad.';


-- ---------------------------------------------------------------------
-- 2. Heldentaten
-- ---------------------------------------------------------------------

create table if not exists public.heldentaten (
  id uuid primary key default uuid_generate_v4(),
  haus_id uuid references public.haeuser(id) on delete cascade not null,

  -- Optional: Eine Heldentat kann einem einzelnen Kind zugeordnet sein
  -- oder dem ganzen Haus gelten.
  schueler_id uuid references public.schueler(id) on delete set null,

  titel text not null check (length(trim(titel)) > 0),
  beschreibung text,

  -- Das Datum des Ereignisses, nicht des Eintragens. Man trägt so etwas
  -- oft erst am Abend oder Tage später nach.
  geschehen_am date not null default current_date,

  -- Bildpfade im Bucket. Reihenfolge im Array = Reihenfolge der Anzeige.
  bilder text[] not null default '{}',

  erstellt_von uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_heldentaten_haus_id
  on public.heldentaten(haus_id);
create index if not exists idx_heldentaten_geschehen_am
  on public.heldentaten(geschehen_am desc);

drop trigger if exists heldentaten_updated_at on public.heldentaten;
create trigger heldentaten_updated_at
  before update on public.heldentaten
  for each row execute function public.update_updated_at();


-- ---------------------------------------------------------------------
-- 3. Zugriffsregeln für Heldentaten
-- ---------------------------------------------------------------------

alter table public.heldentaten enable row level security;

drop policy if exists "heldentaten_admins_all" on public.heldentaten;
create policy "heldentaten_admins_all" on public.heldentaten
  for all using (public.hat_rolle(array['admin']));

drop policy if exists "heldentaten_angemeldete_lesen" on public.heldentaten;
create policy "heldentaten_angemeldete_lesen" on public.heldentaten
  for select using (auth.uid() is not null);

drop policy if exists "heldentaten_lehrkraefte_anlegen" on public.heldentaten;
create policy "heldentaten_lehrkraefte_anlegen" on public.heldentaten
  for insert with check (public.hat_rolle(array['admin', 'teacher']));

drop policy if exists "heldentaten_lehrkraefte_aendern" on public.heldentaten;
create policy "heldentaten_lehrkraefte_aendern" on public.heldentaten
  for update using (public.hat_rolle(array['admin', 'teacher']));

drop policy if exists "heldentaten_lehrkraefte_loeschen" on public.heldentaten;
create policy "heldentaten_lehrkraefte_loeschen" on public.heldentaten
  for delete using (public.hat_rolle(array['admin', 'teacher']));


-- ---------------------------------------------------------------------
-- 4. Der Bildspeicher
-- ---------------------------------------------------------------------
-- "public = false" ist hier das Entscheidende: ohne unterschriebenen
-- Link kommt niemand an die Dateien, auch nicht, wer die Adresse kennt.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'akademie-bilder',
  'akademie-bilder',
  false,
  10485760,  -- 10 MB je Datei
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;


-- Zugriff auf die Dateien selbst.
-- Lesen darf jede angemeldete Person, hochladen und löschen nur
-- Lehrkräfte und Admins.

drop policy if exists "bilder_angemeldete_lesen" on storage.objects;
create policy "bilder_angemeldete_lesen" on storage.objects
  for select using (
    bucket_id = 'akademie-bilder' and auth.uid() is not null
  );

drop policy if exists "bilder_lehrkraefte_hochladen" on storage.objects;
create policy "bilder_lehrkraefte_hochladen" on storage.objects
  for insert with check (
    bucket_id = 'akademie-bilder' and public.hat_rolle(array['admin', 'teacher'])
  );

drop policy if exists "bilder_lehrkraefte_ersetzen" on storage.objects;
create policy "bilder_lehrkraefte_ersetzen" on storage.objects
  for update using (
    bucket_id = 'akademie-bilder' and public.hat_rolle(array['admin', 'teacher'])
  );

drop policy if exists "bilder_lehrkraefte_loeschen" on storage.objects;
create policy "bilder_lehrkraefte_loeschen" on storage.objects
  for delete using (
    bucket_id = 'akademie-bilder' and public.hat_rolle(array['admin', 'teacher'])
  );


-- ---------------------------------------------------------------------
-- 5. Kontrolle
-- ---------------------------------------------------------------------

select id, public as oeffentlich, file_size_limit as max_bytes
  from storage.buckets
 where id = 'akademie-bilder';
