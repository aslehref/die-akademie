import { supabase } from './supabase';

/**
 * Alles, was ein angemeldetes Kind über sich selbst wissen muss.
 *
 * Ein Kind gehört über sein Haus zu genau einer Fakultät. Diese eine
 * Fakultät ist sein ganzer Bewegungsraum: dort gibt es sein Guthaben
 * aus, dort reicht es Heldentaten ein. Alles andere ist für es
 * Schaufenster – sichtbar, aber nicht anfassbar.
 *
 * Die Regeln dazu stehen in der Datenbank (Migration 08). Was hier
 * steht, ist nur die Bequemlichkeit: die Oberfläche soll gar nicht
 * erst anbieten, was ohnehin abgelehnt würde.
 */

export type MeineDaten = {
	schueler: {
		id: string;
		akademiename: string;
		punkte: number;
		xp: number;
		level: number;
		motto: string | null;
		haus_id: string;
	};
	haus: {
		id: string;
		hausname: string;
		slug: string;
		bereich_id: string;
		farbe_primär: string | null;
		farbe_sekundär: string | null;
	};
	bereich: {
		id: string;
		titel: string | null;
		name: string;
		slug: string;
	};
};

/**
 * Lädt Kind, Haus und Fakultät in einem Zug. Gibt null zurück, wenn die
 * angemeldete Person kein Kind ist – eine Lehrkraft etwa.
 */
export async function meineDaten(userId: string): Promise<MeineDaten | null> {
	// Bewusst drei einfache Abfragen statt einer verschachtelten. Jede
	// prüft die Zugriffsregeln für sich, und wenn eine leer bleibt, ist
	// sofort klar welche – bei einer verschachtelten Abfrage kommt in
	// dem Fall nur ein „haus: null" zurück, ohne jeden Hinweis, woran es
	// lag. Es sind drei kleine Abfragen beim Anmelden, nicht mehr.
	const { data: kind } = await supabase
		.from('schueler')
		.select('id, akademiename, punkte, xp, level, motto, haus_id')
		.eq('user_id', userId)
		.maybeSingle();
	if (!kind) return null;

	// Bewusst '*': die Spaltennamen farbe_primär/farbe_sekundär enthalten
	// Umlaute, und die Typprüfung von supabase-js kommt mit ihnen in einer
	// Spaltenliste nicht zurecht.
	const { data: haus } = await supabase
		.from('haeuser')
		.select('*')
		.eq('id', kind.haus_id)
		.maybeSingle();
	if (!haus) return null;

	const { data: bereich } = await supabase
		.from('bereiche')
		.select('id, titel, name, slug')
		.eq('id', haus.bereich_id)
		.maybeSingle();
	if (!bereich) return null;

	return {
		schueler: {
			id: kind.id,
			akademiename: kind.akademiename,
			punkte: kind.punkte ?? 0,
			xp: kind.xp ?? 0,
			level: kind.level ?? 1,
			motto: kind.motto ?? null,
			haus_id: kind.haus_id
		},
		haus: haus as MeineDaten['haus'],
		bereich: bereich as MeineDaten['bereich']
	};
}

/** Der Punktestand, frisch aus der Datenbank. */
export async function meinGuthaben(schuelerId: string) {
	const { data } = await supabase
		.from('schueler')
		.select('punkte, xp, level')
		.eq('id', schuelerId)
		.maybeSingle();
	return data ?? { punkte: 0, xp: 0, level: 1 };
}

/**
 * Ein Kind löst selbst ein. Der Punktestand wird NICHT im Browser
 * geprüft, sondern in der Datenbank – zwei offene Fenster könnten sonst
 * nacheinander dasselbe Guthaben ausgeben.
 */
export async function selbstEinloesen(
	schuelerId: string,
	belohnung: { id: string; name: string; kosten: number }
) {
	return await supabase.from('einloesungen').insert({
		schueler_id: schuelerId,
		belohnung_id: belohnung.id,
		belohnung_name: belohnung.name,
		kosten: belohnung.kosten
	});
}

/** Was ich bisher eingelöst habe. */
export async function meineEinloesungen(schuelerId: string, limit = 20) {
	return await supabase
		.from('einloesungen')
		.select('*')
		.eq('schueler_id', schuelerId)
		.order('created_at', { ascending: false })
		.limit(limit);
}

/**
 * Eine Heldentat einreichen. Status und Punkte werden hier bewusst fest
 * gesetzt: Die Datenbank lässt nichts anderes zu, und so steht auch im
 * Code, dass ein Kind sich weder selbst freischalten noch selbst
 * bepunkten kann.
 */
export async function heldentatEinreichen(daten: {
	schuelerId: string;
	hausId: string;
	titel: string;
	beschreibung: string;
	bilder: string[];
	geschehenAm?: string;
}) {
	return await supabase
		.from('heldentaten')
		.insert({
			haus_id: daten.hausId,
			eingereicht_von: daten.schuelerId,
			schueler_id: daten.schuelerId,
			titel: daten.titel.trim(),
			beschreibung: daten.beschreibung.trim() || null,
			bilder: daten.bilder,
			geschehen_am: daten.geschehenAm ?? new Date().toISOString().slice(0, 10),
			status: 'eingereicht',
			punkte: 0
		})
		.select()
		.single();
}

/** Meine eigenen Einreichungen, auch die noch ungeprüften. */
export async function meineEinreichungen(schuelerId: string) {
	return await supabase
		.from('heldentaten')
		.select('*')
		.eq('eingereicht_von', schuelerId)
		.order('created_at', { ascending: false });
}

/** Die anerkannten Heldentaten meiner Fakultät. */
export async function heldentatenDerFakultaet(hausIds: string[]) {
	if (hausIds.length === 0) return { data: [], error: null };
	return await supabase
		.from('heldentaten')
		.select('*')
		.in('haus_id', hausIds)
		.eq('status', 'sichtbar')
		.order('geschehen_am', { ascending: false })
		.limit(24);
}
