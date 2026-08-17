-- =====================================================================
-- Die Akademie – Migration 02
-- Punkte-Logik, Einlösungen und Schüler ohne eigenen Zugang
-- =====================================================================
--
-- Hintergrund (pädagogisch):
--
--   xp      = Erfahrung. Wächst nur, sinkt nie. Wer etwas gelernt hat,
--             verliert das nicht wieder, weil er sich etwas gönnt.
--   punkte  = das ausgebbare Guthaben des Kindes.
--   hauspunkte = die gemeinsame Leistung des Hauses. Eine Einlösung ist
--             eine persönliche Entscheidung und darf das Haus nicht
--             bestrafen.
--
-- Vorher lief das Einlösen über eine negative Punktetransaktion. Dadurch
-- sank mit jedem Kauf auch die Erfahrung des Kindes UND der Punktestand
-- seines Hauses. Ein Kind, das sich eine Belohnung leistete, schadete
-- damit seinen Mitschülern – genau das Gegenteil der gewünschten
-- Botschaft. Deshalb bekommen Einlösungen hier eine eigene Tabelle.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Schüler brauchen keinen Auth-Account mehr
-- ---------------------------------------------------------------------
-- Kinder loggen sich nicht selbst ein. Die Lehrkraft pflegt die Daten.
-- Damit entstehen keine E-Mail-Adressen und keine Passwörter von
-- Minderjährigen.

alter table public.schueler
  alter column user_id drop not null;

-- Ein Akademiename soll innerhalb eines Hauses eindeutig sein.
alter table public.schueler
  add constraint schueler_akademiename_pro_haus unique (haus_id, akademiename);


-- ---------------------------------------------------------------------
-- 2. Systembuchungen brauchen keine Lehrkraft
-- ---------------------------------------------------------------------
-- Quest-Abschlüsse werden automatisch gebucht und haben keinen Lehrer.

alter table public.punkte_transaktionen
  alter column lehrer_id drop not null;


-- ---------------------------------------------------------------------
-- 3. Chronik: Einlösungen und Stufenaufstiege sollen erzählbar sein
-- ---------------------------------------------------------------------

alter table public.chronik
  drop constraint if exists chronik_typ_check;

alter table public.chronik
  add constraint chronik_typ_check check (
    typ in ('quest', 'transaktion', 'abzeichen', 'event', 'rekord',
            'wettbewerb', 'belohnung', 'levelaufstieg')
  );


-- ---------------------------------------------------------------------
-- 4. Einlösungen
-- ---------------------------------------------------------------------
-- kosten wird bewusst kopiert und nicht nur referenziert: ändert die
-- Lehrkraft später den Preis einer Belohnung, bleibt nachvollziehbar,
-- was das Kind damals bezahlt hat.

create table public.einloesungen (
  id uuid primary key default uuid_generate_v4(),
  schueler_id uuid references public.schueler(id) on delete cascade not null,
  belohnung_id uuid references public.belohnungen(id) on delete set null,
  belohnung_name text not null,
  kosten integer not null check (kosten > 0),
  eingeloest_von uuid references auth.users(id) on delete set null,
  notiz text,
  storniert boolean not null default false,
  storniert_am timestamptz,
  created_at timestamptz not null default now()
);

create index idx_einloesungen_schueler_id on public.einloesungen(schueler_id);
create index idx_einloesungen_created_at on public.einloesungen(created_at desc);


-- ---------------------------------------------------------------------
-- 5. Punktestand, XP und Level neu berechnen
-- ---------------------------------------------------------------------
-- Die alte Funktion update_schueler_xp() verband punkte_transaktionen
-- per Join mit quests, ohne die Zeilen zueinander in Beziehung zu
-- setzen. Das ergab ein Kreuzprodukt: bei 5 Transaktionen und 3
-- Quest-Transaktionen wurden Werte mehrfach gezählt. Die XP-Zahlen
-- waren damit schlicht falsch.
--
-- Neu wird bei jeder Änderung sauber aus den Quelldaten aggregiert.
-- Das ist etwas mehr Arbeit pro Buchung, aber bei Klassengrößen völlig
-- unkritisch – und es bleibt auch nach Korrekturen und Löschungen
-- richtig.

create or replace function public.recalc_schueler(p_schueler_id uuid)
returns void as $$
declare
  v_xp        integer;
  v_verdient  integer;
  v_ausgegeben integer;
begin
  if p_schueler_id is null then
    return;
  end if;

  -- XP zählt nur, was dazugewonnen wurde. Abzüge durch die Lehrkraft
  -- mindern das Guthaben, nicht die Erfahrung.
  select coalesce(sum(betrag) filter (where betrag > 0), 0),
         coalesce(sum(betrag), 0)
    into v_xp, v_verdient
    from public.punkte_transaktionen
   where schueler_id = p_schueler_id;

  select coalesce(sum(kosten), 0)
    into v_ausgegeben
    from public.einloesungen
   where schueler_id = p_schueler_id
     and storniert = false;

  update public.schueler
     set xp     = v_xp,
         level  = greatest(1, (v_xp / 100) + 1),
         punkte = v_verdient - v_ausgegeben
   where id = p_schueler_id;
end;
$$ language plpgsql;


create or replace function public.trg_recalc_schueler()
returns trigger as $$
begin
  perform public.recalc_schueler(coalesce(new.schueler_id, old.schueler_id));
  -- Bei einem UPDATE kann die Zeile einem anderen Kind zugeordnet
  -- worden sein. Dann muss auch das alte Kind neu gerechnet werden.
  if tg_op = 'UPDATE'
     and old.schueler_id is distinct from new.schueler_id then
    perform public.recalc_schueler(old.schueler_id);
  end if;
  return null;
end;
$$ language plpgsql;


-- ---------------------------------------------------------------------
-- 6. Hauspunkte neu berechnen
-- ---------------------------------------------------------------------
-- Der alte Trigger addierte nur auf. Eine korrigierte oder gelöschte
-- Buchung blieb im Hauspunktestand für immer stehen.

create or replace function public.recalc_hauspunkte(p_haus_id uuid)
returns void as $$
begin
  if p_haus_id is null then
    return;
  end if;

  update public.haeuser
     set hauspunkte = (
           select coalesce(sum(betrag), 0)
             from public.punkte_transaktionen
            where haus_id = p_haus_id
         )
   where id = p_haus_id;
end;
$$ language plpgsql;


create or replace function public.trg_recalc_hauspunkte()
returns trigger as $$
begin
  perform public.recalc_hauspunkte(coalesce(new.haus_id, old.haus_id));
  if tg_op = 'UPDATE'
     and old.haus_id is distinct from new.haus_id then
    perform public.recalc_hauspunkte(old.haus_id);
  end if;
  return null;
end;
$$ language plpgsql;


-- ---------------------------------------------------------------------
-- 7. Kein Überziehen des Kontos
-- ---------------------------------------------------------------------

create or replace function public.trg_pruefe_guthaben()
returns trigger as $$
declare
  v_guthaben integer;
  v_name     text;
begin
  select punkte, akademiename
    into v_guthaben, v_name
    from public.schueler
   where id = new.schueler_id
   for update;

  if v_guthaben is null then
    raise exception 'Unbekannter Schüler.';
  end if;

  if v_guthaben < new.kosten then
    raise exception '% hat % Punkte, die Belohnung kostet aber %.',
      v_name, v_guthaben, new.kosten
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$ language plpgsql;


-- ---------------------------------------------------------------------
-- 8. Alte Trigger ersetzen
-- ---------------------------------------------------------------------

drop trigger if exists after_transaktion_insert on public.punkte_transaktionen;
drop trigger if exists after_transaktion_haus   on public.punkte_transaktionen;
drop function if exists public.update_schueler_xp();
drop function if exists public.update_haus_punkte();

create trigger transaktion_recalc_schueler
  after insert or update or delete on public.punkte_transaktionen
  for each row execute function public.trg_recalc_schueler();

create trigger transaktion_recalc_haus
  after insert or update or delete on public.punkte_transaktionen
  for each row execute function public.trg_recalc_hauspunkte();

create trigger einloesung_guthaben_pruefen
  before insert on public.einloesungen
  for each row execute function public.trg_pruefe_guthaben();

create trigger einloesung_recalc_schueler
  after insert or update or delete on public.einloesungen
  for each row execute function public.trg_recalc_schueler();


-- ---------------------------------------------------------------------
-- 9. Row-Level-Security für Einlösungen
-- ---------------------------------------------------------------------

alter table public.einloesungen enable row level security;

create policy "einloesungen_admins_all" on public.einloesungen
  for all using (
    exists (select 1 from public.user_roles
             where user_id = auth.uid() and role = 'admin')
  );

create policy "einloesungen_teachers_read" on public.einloesungen
  for select using (
    exists (select 1 from public.user_roles
             where user_id = auth.uid() and role in ('admin', 'teacher'))
  );

create policy "einloesungen_teachers_insert" on public.einloesungen
  for insert with check (
    exists (select 1 from public.user_roles
             where user_id = auth.uid() and role in ('admin', 'teacher'))
  );


-- ---------------------------------------------------------------------
-- 10. Lesezugriff für Belohnungen, Abzeichen, Quests, Karte, Kapitel
-- ---------------------------------------------------------------------
-- Diese Tabellen hatten RLS aktiviert, aber keine einzige Policy.
-- In Postgres heißt das: niemand darf lesen. Punkteladen, Abzeichen-
-- übersicht und Akademie-Karte wären dauerhaft leer geblieben.

do $$
declare
  t text;
begin
  foreach t in array array['belohnungen', 'abzeichen', 'quests',
                           'karte_orte', 'kapitel', 'schueler_abzeichen']
  loop
    execute format(
      'create policy %I on public.%I for select using (auth.uid() is not null)',
      t || '_angemeldete_lesen', t);

    execute format(
      'create policy %I on public.%I for all using (
         exists (select 1 from public.user_roles
                  where user_id = auth.uid() and role = ''admin''))',
      t || '_admins_all', t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 11. Bestandsdaten einmalig nachrechnen
-- ---------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in select id from public.schueler loop
    perform public.recalc_schueler(r.id);
  end loop;

  for r in select id from public.haeuser loop
    perform public.recalc_hauspunkte(r.id);
  end loop;
end $$;
