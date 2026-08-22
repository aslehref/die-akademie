-- =====================================================================
-- Die Akademie – Migration 08
-- Kinder handeln in ihrer eigenen Fakultät
-- =====================================================================
--
-- Bis hierher waren Kinder Zuschauer: Sie konnten sich anmelden, aber
-- nichts tun. Der Markt verlangte die Rolle „teacher", und eine Fakultät
-- führte in das Lehrerzimmer, das ihnen verschlossen ist.
--
-- Ab jetzt gilt:
--
--   * Ein Kind gehört über sein Haus zu genau EINER Fakultät.
--   * In dieser Fakultät darf es etwas tun: sein Guthaben ausgeben und
--     Heldentaten einreichen.
--   * Außerhalb dieser Fakultät darf es nichts – nicht lesen, was dort
--     eingereicht wurde, nicht dort einreichen, nichts dort kaufen.
--
-- Und: Jede Handlung eines Kindes erzeugt eine Meldung für die
-- Lehrkraft. Punkte gehen sofort ab – ein Guthaben, das erst erlaubt
-- werden muss, ist keines. Aber die Lehrkraft erfährt davon und kann
-- eine Einlösung zurücknehmen.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Zuerst eine Lücke schließen, die erst jetzt gefährlich wird
-- ---------------------------------------------------------------------
-- Solange nur Lehrkräfte Einlösungen anlegten, fiel es nicht auf: die
-- Rechenfunktionen aus Migration 02 laufen mit den Rechten dessen, der
-- sie auslöst. Sobald ein Kind selbst einlöst, bedeutet das:
--
--   * trg_pruefe_guthaben() liest `select ... for update` auf
--     public.schueler. Zeilen sperren darf nur, wer sie auch ändern
--     dürfte – ein Kind darf das nicht. Der Wächter fand deshalb gar
--     keine Zeile und brach mit „Unbekannter Schüler." ab.
--
--   * recalc_schueler() schreibt den neuen Punktestand nach
--     public.schueler. Auch das scheiterte still an der RLS: kein
--     Fehler, aber der Stand blieb einfach stehen. Ein Kind hätte
--     dasselbe Guthaben beliebig oft ausgeben können.
--
-- Beide Funktionen rechnen nur Summen aus vorhandenen Zeilen nach. Sie
-- geben nichts heraus und nehmen keine Eingabe an, die man biegen
-- könnte. `security definer` ist hier deshalb genau richtig – und
-- notwendig, damit die Prüfung überhaupt greift.

alter function public.recalc_schueler(uuid)   security definer set search_path = public;
alter function public.recalc_hauspunkte(uuid) security definer set search_path = public;
alter function public.trg_pruefe_guthaben()   security definer set search_path = public;


-- ---------------------------------------------------------------------
-- 1. Zu welcher Fakultät gehöre ich?
-- ---------------------------------------------------------------------
-- security definer aus demselben Grund wie mein_haus_id(): die Funktion
-- muss über public.haeuser lesen können, ohne selbst an der RLS dort
-- hängenzubleiben.

create or replace function public.mein_bereich_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select h.bereich_id
    from public.schueler s
    join public.haeuser h on h.id = s.haus_id
   where s.user_id = auth.uid()
   limit 1;
$$;

revoke all on function public.mein_bereich_id() from public;

do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('grant execute on function public.mein_bereich_id() to %I', r);
    end if;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 2. Meldungen an die Lehrkraft
-- ---------------------------------------------------------------------
-- Ein Postfach, kein E-Mail-Versand. E-Mail bräuchte einen Dienst, eine
-- Adresse je Lehrkraft und die Zustimmung dazu – ein Postfach im
-- Lehrerzimmer erreicht dasselbe und verlässt die Anwendung nie.
--
-- lehrer_id ist die Lehrkraft, die das Haus leitet (haeuser.lehrer_id).
-- Ist dort niemand eingetragen, bleibt das Feld leer und die Meldung
-- gilt allen Lehrkräften.

create table if not exists public.meldungen (
  id uuid primary key default uuid_generate_v4(),

  typ text not null check (typ in ('einloesung', 'heldentat')),
  titel text not null,
  beschreibung text,

  bereich_id  uuid references public.bereiche(id) on delete cascade,
  haus_id     uuid references public.haeuser(id)  on delete cascade,
  schueler_id uuid references public.schueler(id) on delete set null,
  lehrer_id   uuid references auth.users(id)      on delete set null,

  -- Verweis auf den auslösenden Datensatz (Einlösung oder Heldentat),
  -- damit die Oberfläche direkt dorthin springen kann.
  verweis_id uuid,

  erledigt boolean not null default false,
  erledigt_von uuid references auth.users(id) on delete set null,
  erledigt_am timestamptz,

  created_at timestamptz not null default now()
);

create index if not exists idx_meldungen_offen
  on public.meldungen(erledigt, created_at desc);
create index if not exists idx_meldungen_bereich
  on public.meldungen(bereich_id);

alter table public.meldungen enable row level security;

-- Kinder haben hier ausdrücklich KEINE Politik und sehen deshalb nichts.
drop policy if exists "meldungen_lehrkraefte_lesen" on public.meldungen;
create policy "meldungen_lehrkraefte_lesen" on public.meldungen
  for select using (public.hat_rolle(array['admin', 'teacher']));

drop policy if exists "meldungen_lehrkraefte_abhaken" on public.meldungen;
create policy "meldungen_lehrkraefte_abhaken" on public.meldungen
  for update using (public.hat_rolle(array['admin', 'teacher']));

drop policy if exists "meldungen_admins_loeschen" on public.meldungen;
create policy "meldungen_admins_loeschen" on public.meldungen
  for delete using (public.hat_rolle(array['admin']));

-- Angelegt werden Meldungen ausschließlich von Auslösern (siehe unten).
-- Deshalb gibt es bewusst KEINE insert-Politik: niemand kann sich selbst
-- eine Meldung schreiben.


-- ---------------------------------------------------------------------
-- 3. Heldentaten bekommen einen Weg vom Kind zur Lehrkraft
-- ---------------------------------------------------------------------
-- Bestehende Einträge stammen alle von Lehrkräften und sind damit
-- sichtbar. Neu eingereichte warten auf Prüfung.

alter table public.heldentaten
  add column if not exists status text not null default 'sichtbar';

alter table public.heldentaten drop constraint if exists heldentaten_status_check;
alter table public.heldentaten
  add constraint heldentaten_status_check
  check (status in ('eingereicht', 'sichtbar', 'abgelehnt'));

alter table public.heldentaten
  add column if not exists eingereicht_von uuid references public.schueler(id) on delete set null;
alter table public.heldentaten
  add column if not exists punkte integer not null default 0;
alter table public.heldentaten
  add column if not exists rueckmeldung text;
alter table public.heldentaten
  add column if not exists bewertet_von uuid references auth.users(id) on delete set null;
alter table public.heldentaten
  add column if not exists bewertet_am timestamptz;

comment on column public.heldentaten.status is
  'eingereicht = wartet auf die Lehrkraft; sichtbar = gilt und wird '
  'angezeigt; abgelehnt = bleibt beim Kind, aber nicht in der Halle.';
comment on column public.heldentaten.eingereicht_von is
  'Gesetzt, wenn ein Kind die Heldentat selbst eingereicht hat.';


-- ---------------------------------------------------------------------
-- 4. Was ein Kind bei Heldentaten darf
-- ---------------------------------------------------------------------
-- Die alte Politik hieß „lesen darf jede angemeldete Person". Damit sah
-- ein Kind auch die Einreichungen fremder Fakultäten, geprüfte wie
-- ungeprüfte. Sie wird ersetzt, nicht ergänzt: permissive Politiken
-- werden mit ODER verknüpft, eine zusätzliche hätte also nichts
-- eingeschränkt.

drop policy if exists "heldentaten_angemeldete_lesen" on public.heldentaten;

drop policy if exists "heldentaten_lehrkraefte_lesen" on public.heldentaten;
create policy "heldentaten_lehrkraefte_lesen" on public.heldentaten
  for select using (public.hat_rolle(array['admin', 'teacher', 'viewer']));

-- Ein Kind sieht die anerkannten Heldentaten seiner eigenen Fakultät –
-- und zusätzlich seine eigenen, solange sie noch geprüft werden. Sonst
-- wüsste es nicht, ob seine Einreichung überhaupt angekommen ist.
drop policy if exists "heldentaten_schueler_lesen" on public.heldentaten;
create policy "heldentaten_schueler_lesen" on public.heldentaten
  for select using (
    public.mein_schueler_id() is not null
    and haus_id in (
      select h.id from public.haeuser h
       where h.bereich_id = public.mein_bereich_id()
    )
    and (status = 'sichtbar' or eingereicht_von = public.mein_schueler_id())
  );

-- Einreichen: nur ins eigene Haus, nur unter eigenem Namen, nur als
-- Einreichung. Ein Kind kann sich damit weder selbst freischalten noch
-- Punkte zusprechen.
drop policy if exists "heldentaten_schueler_einreichen" on public.heldentaten;
create policy "heldentaten_schueler_einreichen" on public.heldentaten
  for insert with check (
    public.mein_schueler_id() is not null
    and haus_id = public.mein_haus_id()
    and eingereicht_von = public.mein_schueler_id()
    and status = 'eingereicht'
    and punkte = 0
  );


-- ---------------------------------------------------------------------
-- 5. Privilegien: nur die der eigenen Fakultät
-- ---------------------------------------------------------------------
-- Auch hier muss die alte Politik weichen, sonst sähe ein Kind den
-- Katalog aller Fakultäten. Privilegien ohne Fakultät gelten für alle.

drop policy if exists "belohnungen_angemeldete_lesen" on public.belohnungen;

drop policy if exists "belohnungen_lesen" on public.belohnungen;
create policy "belohnungen_lesen" on public.belohnungen
  for select using (
    public.hat_rolle(array['admin', 'teacher', 'viewer'])
    or (
      public.mein_schueler_id() is not null
      and (bereich_id is null or bereich_id = public.mein_bereich_id())
    )
  );


-- ---------------------------------------------------------------------
-- 6. Ein Kind gibt sein eigenes Guthaben aus
-- ---------------------------------------------------------------------
-- Der Wächter gegen Überziehen aus Migration 02 greift weiterhin: er
-- prüft den Stand in der Datenbank, nicht den im Browser. Ein Kind kann
-- sich also nicht ins Minus kaufen, auch nicht mit zwei Fenstern
-- gleichzeitig.
--
-- Was ein Kind NICHT darf: eine Einlösung ändern oder stornieren. Sonst
-- könnte es sich das Guthaben zurückholen, nachdem es das Privileg
-- bereits genutzt hat.

create or replace function public.belohnung_fuer_mich(p_belohnung_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.belohnungen b
     where b.id = p_belohnung_id
       and b.aktiv = true
       and (b.bereich_id is null or b.bereich_id = public.mein_bereich_id())
  );
$$;

revoke all on function public.belohnung_fuer_mich(uuid) from public;

do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('grant execute on function public.belohnung_fuer_mich(uuid) to %I', r);
    end if;
  end loop;
end $$;

drop policy if exists "einloesungen_schueler_selbst" on public.einloesungen;
create policy "einloesungen_schueler_selbst" on public.einloesungen
  for insert with check (
    schueler_id = public.mein_schueler_id()
    and storniert = false
    and public.belohnung_fuer_mich(belohnung_id)
  );


-- ---------------------------------------------------------------------
-- 7. Bilder: nur die eigene Fakultät
-- ---------------------------------------------------------------------
-- Bildpfade beginnen mit haeuser/<haus-id>/. Daran lässt sich prüfen, ob
-- ein Bild zur Fakultät des Kindes gehört.

create or replace function public.bild_sichtbar(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.hat_rolle(array['admin', 'teacher', 'viewer']) then true
    when public.mein_schueler_id() is null then false
    else exists (
      select 1 from public.haeuser h
       where h.bereich_id = public.mein_bereich_id()
         and p_name like 'haeuser/' || h.id::text || '/%'
    )
  end;
$$;

revoke all on function public.bild_sichtbar(text) from public;

do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('grant execute on function public.bild_sichtbar(text) to %I', r);
    end if;
  end loop;
end $$;

drop policy if exists "bilder_angemeldete_lesen" on storage.objects;
drop policy if exists "bilder_lesen" on storage.objects;
create policy "bilder_lesen" on storage.objects
  for select using (
    bucket_id = 'akademie-bilder'
    and auth.uid() is not null
    and public.bild_sichtbar(name)
  );

-- Hochladen darf ein Kind ausschließlich in den Einreichungsordner
-- seines eigenen Hauses.
drop policy if exists "bilder_schueler_einreichen" on storage.objects;
create policy "bilder_schueler_einreichen" on storage.objects
  for insert with check (
    bucket_id = 'akademie-bilder'
    and public.mein_haus_id() is not null
    and name like 'haeuser/' || public.mein_haus_id()::text || '/einreichungen/%'
  );


-- ---------------------------------------------------------------------
-- 8. Die Meldungen entstehen von selbst
-- ---------------------------------------------------------------------
-- Als Trigger und nicht in der Anwendung: eine Meldung, die der Browser
-- schreiben müsste, bliebe aus, sobald jemand das Fenster zu früh
-- schließt. Und weil die Funktion security definer ist, braucht niemand
-- Schreibrechte auf public.meldungen.

create or replace function public.trg_meldung_einloesung()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name    text;
  v_haus    uuid;
  v_bereich uuid;
  v_lehrer  uuid;
begin
  select s.akademiename, s.haus_id, h.bereich_id, h.lehrer_id
    into v_name, v_haus, v_bereich, v_lehrer
    from public.schueler s
    join public.haeuser h on h.id = s.haus_id
   where s.id = new.schueler_id;

  insert into public.meldungen
    (typ, titel, beschreibung, bereich_id, haus_id, schueler_id, lehrer_id, verweis_id)
  values (
    'einloesung',
    coalesce(v_name, 'Ein Kind') || ' hat „' || new.belohnung_name || '" eingelöst',
    '−' || new.kosten || ' Punkte',
    v_bereich, v_haus, new.schueler_id, v_lehrer, new.id
  );
  return null;
end;
$$;

drop trigger if exists meldung_bei_einloesung on public.einloesungen;
create trigger meldung_bei_einloesung
  after insert on public.einloesungen
  for each row execute function public.trg_meldung_einloesung();


create or replace function public.trg_meldung_heldentat()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name    text;
  v_bereich uuid;
  v_lehrer  uuid;
begin
  -- Nur Einreichungen von Kindern melden. Was die Lehrkraft selbst
  -- einträgt, muss sie sich nicht selbst melden.
  if new.status <> 'eingereicht' or new.eingereicht_von is null then
    return null;
  end if;

  select s.akademiename into v_name
    from public.schueler s where s.id = new.eingereicht_von;

  select h.bereich_id, h.lehrer_id into v_bereich, v_lehrer
    from public.haeuser h where h.id = new.haus_id;

  insert into public.meldungen
    (typ, titel, beschreibung, bereich_id, haus_id, schueler_id, lehrer_id, verweis_id)
  values (
    'heldentat',
    coalesce(v_name, 'Ein Kind') || ' hat eine Heldentat eingereicht: „' || new.titel || '"',
    new.beschreibung,
    v_bereich, new.haus_id, new.eingereicht_von, v_lehrer, new.id
  );
  return null;
end;
$$;

drop trigger if exists meldung_bei_heldentat on public.heldentaten;
create trigger meldung_bei_heldentat
  after insert on public.heldentaten
  for each row execute function public.trg_meldung_heldentat();


-- ---------------------------------------------------------------------
-- 9. Kontrolle
-- ---------------------------------------------------------------------

select 'offene Meldungen' as was, count(*)::text as wert
  from public.meldungen where erledigt = false
union all
select 'Heldentaten in Prüfung', count(*)::text
  from public.heldentaten where status = 'eingereicht';
