<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/<your-username>/die-akademie/main/static/banner-dark.svg">
  <img alt="Die Akademie" src="https://raw.githubusercontent.com/<your-username>/die-akademie/main/static/banner.svg">
</picture>

# 🏰 Die Akademie

**Gamifiziertes Unterrichtssystem für Religion, Sozialkunde, Politik und weitere Fächer**

_Wissen. Gemeinschaft. Verantwortung._

---

## 📋 Übersicht

Die Akademie ist ein webbasiertes Gamification-System für den Unterricht. Schüler erleben das Schuljahr als eine gemeinsame Akademie, in der Klassen bzw. Häuser Punkte sammeln, Quests bearbeiten, Abzeichen erhalten und Punkte gegen pädagogisch sinnvolle Privilegien eintauschen können.

Das System ist von Fantasy-, Akademie- und mittelalterlicher Ästhetik inspiriert, bildet aber eine eigene Welt.

### Kernprinzipien

- **Kompetenz**: „Ich kann etwas und entwickle mich weiter.“
- **Autonomie**: „Ich kann Entscheidungen treffen.“
- **Soziale Eingebundenheit**: „Ich bin Teil meiner Klasse bzw. meines Hauses.“

## ✨ Features

| Feature                 | Beschreibung                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------ |
| 🏰 **Häuser / Klassen** | Jede Klasse wird als Haus dargestellt mit eigenem Namen, Logo, Farben und Motto            |
| 🪙 **Punktesystem**     | Punkte für Lernen, Sozialverhalten, Diskussion, Demokratie, persönliche Entwicklung & mehr |
| ⚔️ **Quests**           | Besondere Aufgaben mit höherer Belohnung, für einzelne oder ganze Gruppen                  |
| 🏅 **Abzeichen**        | Dauerhafte Anerkennung für besondere Leistungen                                            |
| 🛒 **Punkteladen**      | Punkte gegen Joker, Wahlmöglichkeiten und Aktivitäten eintauschen                          |
| 🏆 **Hauspokal**        | Wettbewerb zwischen den Häusern mit mehreren Pokalkategorien                               |
| 🗺️ **Akademie-Karte**   | Visuelle Bereiche, die im Laufe des Schuljahres freigeschaltet werden                      |
| 📖 **Kapitel**          | Das Schuljahr ist in 5 Kapitel unterteilt                                                  |
| 👑 **Jahresfinale**     | Hauspokal-Verleihung und persönliche Auszeichnungen                                        |

## 🛠️ Tech-Stack

### Frontend

- **[SvelteKit 2](https://kit.svelte.dev/)** + **[Svelte 5](https://svelte.dev/)**
- **[Vite](https://vite.dev/)** (Build-Tool)
- **[TypeScript](https://www.typescriptlang.org/)**
- **[Tailwind CSS 4](https://tailwindcss.com/)** (Styling)
- **[Paraglide JS](https://inlang.com/m/gerre34r/library-inlang-paraglideJs)** (Internationalisierung)
- **adapter-static** (für GitHub Pages Deployment)

### Backend & Daten

- **[Supabase](https://supabase.com/)**: PostgreSQL, Auth, Storage, Realtime, Edge Functions
- **Row-Level Security** für feingranulare Berechtigungen

### DevOps

- **GitHub** + **GitHub Actions** (CI/CD)
- **GitHub Pages** (Hosting)
- **Node 22**, **npm**

### Testing & Qualität

- **Vitest** (Unit-Tests)
- **Playwright** (E2E-Tests)
- **ESLint** + **Prettier** (Linting & Formatierung)
- **svelte-check** (Type-Checking)

## 🚀 Entwicklung starten

### Voraussetzungen

- Node.js 22+
- npm
- Supabase-Projekt (kostenlos auf [supabase.com](https://supabase.com))

### Setup

```bash
# Repository klonen
git clone https://github.com/<dein-username>/die-akademie.git
cd die-akademie

# Abhängigkeiten installieren
npm install

# Supabase-Umgebungsvariablen setzen
cp .env.example .env
# .env mit deinen Supabase-Werten ausfüllen

# Entwicklungsserver starten
npm run dev
```

### Supabase initialisieren

1. Projekt auf [supabase.com](https://supabase.com) anlegen
2. SQL aus `supabase/migrations/00001_schema.sql` im SQL-Editor ausführen
3. Authentication > Settings > Site URL auf `http://localhost:5173` setzen
4. `.env` mit Projekt-URL und Anon-Key befüllen

### Build & Preview

```bash
npm run build
npm run preview
```

Der Build wird im `build/`-Verzeichnis erstellt (statisch für GitHub Pages).

## 🧪 Tests ausführen

```bash
# Unit-Tests
npm run test

# E2E-Tests (Playwright)
npm run test:e2e

# TypeScript-Check
npm run check
```

## 🏗️ Projektstruktur

```
die-akademie/
├── .github/workflows/    # GitHub Actions CI/CD
├── messages/             # i18n Übersetzungen (DE/EN)
├── src/
│   ├── lib/
│   │   ├── supabase.ts   # Supabase Client & Helpers
│   │   ├── types.ts      # TypeScript-Interfaces
│   │   └── ...
│   ├── routes/
│   │   ├── +layout.svelte    # Root-Layout mit Auth & Navigation
│   │   ├── +page.svelte      # Startseite (Dashboard/Gäste)
│   │   ├── login/
│   │   │   └── +page.svelte  # Login-Seite
│   │   ├── dashboard/
│   │   │   ├── +page.svelte  # Dashboard nach Login
│   │   │   ├── faecher/
│   │   │   ├── klassenstufen/
│   │   │   └── ...
│   │   └── admin/
│   │       └── ...
│   ├── app.html          # HTML-Template
│   ├── app.css           # Globale Styles (Tailwind + Academy-Theme)
│   └── hooks.server.ts   # Supabase Session-Handling
├── supabase/migrations/  # Datenbank-Migrationen
├── static/               # Statische Assets
├── tests/                # Playwright E2E-Tests
├── svelte.config.js      # SvelteKit-Konfiguration (adapter-static)
├── vite.config.ts        # Vite-Konfiguration
└── project.inlang.json   # Paraglide i18n Konfiguration
```

## 🎨 Design-Philosophie

Die Oberfläche ist eine Mischung aus:

- **70 %** mittelalterliche Akademie-Ästhetik
- **20 %** modernes Game-Dashboard
- **10 %** dezente Fantasy-Elemente

Farbpalette: Dunkles Blau, Gold, Pergament, Dunkelgrün, Steinoptik.

## 🗺️ Entwicklungs-Roadmap

### Phase 1 – Fundament ✅ (in Arbeit)

- [x] Projekt-Setup & CI/CD
- [x] Datenbank-Schema & RLS
- [x] Auth mit Supabase
- [x] Dashboard-Layout & Navigation
- [x] Login-Seite
- [ ] Bereichsverwaltung (Fächer, Klassenstufen)
- [ ] Haus-/Klassenverwaltung
- [ ] Punkte vergeben/abziehen (Transaktions-Log)

### Phase 2 – Gamification

- [ ] Punkteladen & Belohnungen
- [ ] Abzeichen & XP/Level-System
- [ ] Chronik & Statistiken
- [ ] Questsystem mit Gültigkeitsbereichen
- [ ] Hausranking

### Phase 3 – Akademie-Erlebnis

- [ ] Akademie-Karte mit Freischaltungen
- [ ] Kapitel-System
- [ ] Jahresfinale & Hauspokal
- [ ] Persönliche Auszeichnungen
- [ ] Animationen & Realtime-Updates

## 📄 Lizenz

MIT – offen für Schulen und Lehrkräfte.

---

> **Leitidee**  
> „Ich kann durch mein Lernen, mein Verhalten und meine Entscheidungen Einfluss auf meine Klasse nehmen.“
