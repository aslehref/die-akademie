-- =====================================================================
-- Die Akademie – Migration 06
-- Fakultäten bekommen einen eigenen Titel
-- =====================================================================
--
-- Bisher hatte eine Fakultät nur `name` – das war zugleich Anzeige und
-- Sachbezeichnung. „Religion" ist als Fachangabe richtig, taugt aber
-- nicht als Name einer Akademie.
--
-- Ab jetzt:
--   titel  = der Name, der groß dasteht  ("Orden der Stillen Wasser")
--   name   = Fach oder Jahrgang, als Untertitel darunter  ("Religion 7")
--
-- `name` bleibt unverändert bestehen, damit nichts umgebaut werden muss,
-- was heute schon darauf zeigt.
-- =====================================================================

alter table public.bereiche add column if not exists titel text;

comment on column public.bereiche.titel is
  'Der große Name der Fakultät. Steht in der Anzeige oben.';
comment on column public.bereiche.name is
  'Fach oder Jahrgang. Steht als Untertitel unter dem Titel.';

-- Bestandsdaten: Wer noch keinen Titel hat, bekommt den bisherigen Namen.
-- So sieht nach der Migration nichts leer aus, und die Lehrkraft kann in
-- Ruhe schönere Titel nachtragen.
update public.bereiche
   set titel = name
 where titel is null or length(trim(titel)) = 0;

-- Ab jetzt verbindlich.
alter table public.bereiche drop constraint if exists bereiche_titel_gefuellt;
alter table public.bereiche
  add constraint bereiche_titel_gefuellt
  check (titel is null or length(trim(titel)) > 0);


-- ---------------------------------------------------------------------
-- Kontrolle
-- ---------------------------------------------------------------------

select titel, name, typ from public.bereiche order by titel;
