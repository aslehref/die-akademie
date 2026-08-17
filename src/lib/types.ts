// Typen zu den Tabellen aus supabase/migrations/.
// Stand: Migration 00002.

export type UserRole = 'admin' | 'teacher' | 'viewer';

export type Punktekategorie =
	| 'lernen'
	| 'sozialverhalten'
	| 'selbstständigkeit'
	| 'diskussion'
	| 'demokratie'
	| 'persönliche_entwicklung'
	| 'verantwortung'
	| 'quest';

export interface Schueler {
	id: string;
	haus_id: string;
	/** Kinder haben keinen eigenen Zugang – dieses Feld bleibt in der Regel leer. */
	user_id: string | null;
	akademiename: string;
	avatar_url: string | null;
	wappen_url: string | null;
	motto: string | null;
	titel: string | null;
	/** Erfahrung. Zählt nur positive Buchungen und sinkt nie. */
	xp: number;
	level: number;
	/** Ausgebbares Guthaben: alle Buchungen minus nicht stornierte Einlösungen. */
	punkte: number;
	created_at: string;
	updated_at: string;
}

export interface Punktetransaktion {
	id: string;
	schueler_id: string;
	/** Ohne haus_id zählt die Buchung für das Kind, aber nicht für den Hauspokal. */
	haus_id: string | null;
	bereich_id: string | null;
	betrag: number;
	kategorie: Punktekategorie;
	grund: string;
	/** Leer bei automatischen Buchungen, etwa aus abgeschlossenen Quests. */
	lehrer_id: string | null;
	created_at: string;
}

export interface Einloesung {
	id: string;
	schueler_id: string;
	belohnung_id: string | null;
	/** Bewusst kopiert: bleibt richtig, auch wenn der Preis später geändert wird. */
	belohnung_name: string;
	kosten: number;
	eingeloest_von: string | null;
	notiz: string | null;
	storniert: boolean;
	storniert_am: string | null;
	created_at: string;
}
