import { supabase } from './supabase';

/**
 * Bilder liegen in einem NICHT öffentlichen Bereich.
 *
 * Fotos aus dem Unterricht zeigen in aller Regel Kinder, die Seite selbst
 * liegt aber öffentlich im Netz. Deshalb wird zu keinem Zeitpunkt eine
 * dauerhaft gültige Adresse erzeugt. Stattdessen unterschreibt Supabase
 * bei jedem Aufruf einen Link, der nach kurzer Zeit von selbst verfällt.
 * Wer ihn weitergibt, gibt damit nichts Dauerhaftes weiter.
 */
export const BILDER_BUCKET = 'akademie-bilder';

/** Wie lange ein erzeugter Link gültig bleibt: eine Stunde. */
const LINK_GUELTIG_SEKUNDEN = 60 * 60;

export const MAX_BILD_BYTES = 10 * 1024 * 1024;

const ERLAUBTE_TYPEN = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif'];

/**
 * Prüft eine Datei, bevor sie überhaupt losgeschickt wird. Das spart der
 * Lehrkraft das Warten auf einen Upload, der am Ende ohnehin abgelehnt
 * würde, und liefert eine Meldung, die man verstehen kann.
 */
export function pruefeBild(datei: File): string | null {
	if (!ERLAUBTE_TYPEN.includes(datei.type)) {
		return `„${datei.name}“ ist kein Bild. Erlaubt sind JPG, PNG, WebP, GIF und AVIF.`;
	}
	if (datei.size > MAX_BILD_BYTES) {
		const mb = (datei.size / 1024 / 1024).toFixed(1);
		return `„${datei.name}“ ist ${mb} MB groß. Erlaubt sind höchstens 10 MB.`;
	}
	return null;
}

/** Macht aus einem Dateinamen etwas, das in einem Pfad nicht stört. */
function sichererName(name: string): string {
	const punkt = name.lastIndexOf('.');
	const endung = punkt > 0 ? name.slice(punkt + 1).toLowerCase() : 'bin';
	const basis = (punkt > 0 ? name.slice(0, punkt) : name)
		.toLowerCase()
		.replace(/[äÄ]/g, 'ae')
		.replace(/[öÖ]/g, 'oe')
		.replace(/[üÜ]/g, 'ue')
		.replace(/ß/g, 'ss')
		.replace(/[^a-z0-9]+/g, '-')
		.replace(/^-+|-+$/g, '')
		.slice(0, 40);
	// Zufälliger Anteil, damit zwei Dateien mit gleichem Namen sich nicht
	// gegenseitig überschreiben.
	const zufall = Math.random().toString(36).slice(2, 8);
	return `${basis || 'bild'}-${Date.now()}-${zufall}.${endung}`;
}

/**
 * Lädt eine Datei hoch und gibt den PFAD zurück – nicht die Adresse.
 * Gespeichert wird immer der Pfad, weil Adressen bei einem privaten
 * Speicher nach einer Stunde ungültig sind.
 */
export async function ladeBildHoch(datei: File, ordner: string): Promise<string> {
	const fehler = pruefeBild(datei);
	if (fehler) throw new Error(fehler);

	const pfad = `${ordner.replace(/^\/+|\/+$/g, '')}/${sichererName(datei.name)}`;

	const { error } = await supabase.storage.from(BILDER_BUCKET).upload(pfad, datei, {
		cacheControl: '3600',
		upsert: false,
		contentType: datei.type
	});
	if (error) throw error;

	return pfad;
}

/** Erzeugt für einen Pfad einen befristeten Link. */
export async function bildLink(pfad: string): Promise<string | null> {
	const { data, error } = await supabase.storage
		.from(BILDER_BUCKET)
		.createSignedUrl(pfad, LINK_GUELTIG_SEKUNDEN);
	if (error) return null;
	return data?.signedUrl ?? null;
}

/**
 * Erzeugt Links für viele Pfade auf einmal. Für eine Galerie ist das
 * deutlich schneller als ein Aufruf je Bild.
 * Gibt eine Zuordnung Pfad -> Link zurück; nicht auflösbare Pfade fehlen darin.
 */
export async function bildLinks(pfade: string[]): Promise<Record<string, string>> {
	const ergebnis: Record<string, string> = {};
	const sauber = pfade.filter(Boolean);
	if (sauber.length === 0) return ergebnis;

	const { data, error } = await supabase.storage
		.from(BILDER_BUCKET)
		.createSignedUrls(sauber, LINK_GUELTIG_SEKUNDEN);
	if (error || !data) return ergebnis;

	for (const eintrag of data) {
		// Supabase liefert den Pfad hier ohne führenden Schrägstrich zurück.
		const pfad = (eintrag as { path?: string | null }).path;
		const url = (eintrag as { signedUrl?: string | null }).signedUrl;
		if (pfad && url) ergebnis[pfad] = url;
	}
	return ergebnis;
}

/**
 * Löscht Dateien. Fehler werden bewusst geschluckt: Wenn eine Datei schon
 * weg ist, soll das Löschen des zugehörigen Eintrags trotzdem gelingen.
 * Eine verwaiste Datei ist ärgerlich, ein hängengebliebener Eintrag wäre
 * schlimmer.
 */
export async function loescheBilder(pfade: string[]): Promise<void> {
	const sauber = pfade.filter(Boolean);
	if (sauber.length === 0) return;
	await supabase.storage.from(BILDER_BUCKET).remove(sauber);
}
