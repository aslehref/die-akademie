# Contributing to Die Akademie

## Entwicklungsworkflow

1. Branch von `main` erstellen: `git checkout -b feature/mein-feature`
2. Änderungen umsetzen
3. Linting & Tests: `npm run lint && npm run check && npm run test`
4. Build testen: `npm run build`
5. Pull Request auf GitHub erstellen

## Coding-Standards

- **Sprache**: Code-Kommentare und UI-Texte auf Deutsch
- **Identifier**: Englisch (camelCase für Variablen/Funktionen, PascalCase für Typen/Klassen)
- **Formatierung**: Prettier (wird beim Commit automatisch angewendet)
- **Typisierung**: Strict TypeScript, keine `any`

## Supabase-Entwicklung

- Schema-Änderungen als SQL-Migration in `supabase/migrations/` ablegen
- Nach Änderungen: RLS-Policies prüfen
- Lokale Entwicklung: Supabase CLI (`supabase start`)

## Commit-Konventionen

- `feat:` – Neues Feature
- `fix:` – Bugfix
- `refactor:` – Code-Umstrukturierung ohne Funktionsänderung
- `style:` – Formatierung, fehlende Semikolons etc.
- `docs:` – Dokumentation
- `test:` – Tests
- `chore:` – Build, CI, Dependencies

## Pull Request Checklist

- [ ] `npm run check` erfolgreich
- [ ] `npm run build` erfolgreich
- [ ] Tests hinzugefügt/aktualisiert
- [ ] Supabase-Migration ist versioniert
- [ ] `.env.example` aktualisiert falls neue Env-Vars
