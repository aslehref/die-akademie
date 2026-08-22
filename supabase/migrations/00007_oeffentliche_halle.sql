-- =====================================================================
-- Die Akademie – Migration 07
-- Die Eingangshalle wird öffentlich
-- =====================================================================
--
-- Bisher galt für Fakultäten, Häuser und Quests: lesen darf nur, wer
-- angemeldet ist. Wer die Seite ohne Anmeldung aufrief, sah deshalb
-- „Noch keine Häuser angelegt“ – obwohl längst welche da waren. Das war
-- keine leere Datenbank, sondern eine Tür ohne Klinke.
--
-- Gewollt ist das Gegenteil: Die Startseite ist die Eingangshalle. Dort
-- stehen die Fakultäten zur Auswahl, dort hängt die Wochenquest aus, und
-- dort stehen die Stundengläser der Häuser. Erst danach entscheidet
-- man sich für eine der beiden Türen – Schüler*in oder Lehrkraft.
--
-- Öffentlich wird dabei ausschließlich, was auch im Schulhaus an der
-- Wand hängen dürfte:
--
--   bereiche  – die Fakultäten
--   haeuser   – Name, Farben, Wappen, Punktestand
--   quests    – aber nur die, die gerade laufen
--
-- Nicht öffentlich wird und bleibt:
--
--   schueler, schueler_klarnamen, punkte_transaktionen, einloesungen,
--   heldentaten, user_roles
--
-- Der Punktestand eines Hauses ist eine Gruppenleistung und verrät
-- nichts über ein einzelnes Kind. Deshalb darf er an die Wand.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Fakultäten und Häuser öffentlich lesbar
-- ---------------------------------------------------------------------
-- Zusätzliche Lesepolitik. Die bestehende Politik für Angemeldete bleibt
-- stehen: mehrere permissive Politiken werden mit ODER verknüpft, die
-- neue erweitert also nur, sie nimmt niemandem etwas.

drop policy if exists "bereiche_oeffentlich_lesen" on public.bereiche;
create policy "bereiche_oeffentlich_lesen" on public.bereiche
  for select using (true);

drop policy if exists "haeuser_oeffentlich_lesen" on public.haeuser;
create policy "haeuser_oeffentlich_lesen" on public.haeuser
  for select using (true);


-- ---------------------------------------------------------------------
-- 2. Quests: nur die laufenden
-- ---------------------------------------------------------------------
-- Entwürfe sind Vorbereitung und gehen niemanden etwas an. Abgeschlossene
-- und archivierte Quests bleiben ebenfalls hinter der Anmeldung.

drop policy if exists "quests_oeffentlich_lesen" on public.quests;
create policy "quests_oeffentlich_lesen" on public.quests
  for select using (status = 'aktiv');


-- ---------------------------------------------------------------------
-- 3. Die Stundengläser
-- ---------------------------------------------------------------------
-- Ein Haus hat zwei Zahlen:
--
--   gesammelt  = alles, was das Haus je erarbeitet hat. Das ist der
--                Sand im Glas. Er fällt nicht zurück, nur weil sich
--                jemand etwas gegönnt hat.
--   verfuegbar = was die Mitglieder zusammen noch ausgeben können.
--
-- „verfuegbar“ ist die Summe der Guthaben aller Kinder des Hauses. Diese
-- Summe darf öffentlich sein, die einzelnen Guthaben nicht. Genau dafür
-- ist eine Funktion mit `security definer` da: sie rechnet innerhalb der
-- Datenbank und gibt nur das Ergebnis heraus, nie die Zeilen.

create or replace function public.stundenglaeser(p_bereich_id uuid default null)
returns table (
  haus_id          uuid,
  bereich_id       uuid,
  hausname         text,
  slug             text,
  farbe_primaer    text,
  farbe_sekundaer  text,
  logo_pfad        text,
  motto            text,
  gesammelt        integer,
  verfuegbar       integer,
  mitglieder       integer
)
as $$
  select h.id,
         h.bereich_id,
         h.hausname,
         h.slug,
         h."farbe_primär",
         h."farbe_sekundär",
         h.logo_pfad,
         h.motto,
         h.hauspunkte,
         coalesce(sum(s.punkte), 0)::integer,
         count(s.id)::integer
    from public.haeuser h
    left join public.schueler s on s.haus_id = h.id
   where p_bereich_id is null or h.bereich_id = p_bereich_id
   group by h.id
   order by h.hauspunkte desc, h.hausname;
$$ language sql stable security definer set search_path = public;

-- Ohne dieses grant bekäme ein nicht angemeldeter Gast keinen leeren
-- Stand, sondern einen harten Fehler: "permission denied for function".
do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format(
        'grant execute on function public.stundenglaeser(uuid) to %I', r);
    end if;
  end loop;
end $$;

comment on function public.stundenglaeser(uuid) is
  'Punktestände der Häuser für die öffentliche Anzeige. Gibt Summen '
  'heraus, niemals einzelne Schülerdaten.';


-- ---------------------------------------------------------------------
-- 4. Kontrolle
-- ---------------------------------------------------------------------

select hausname, gesammelt, verfuegbar, mitglieder
  from public.stundenglaeser();
