import { createClient } from '@supabase/supabase-js';
import { supabase, SUPABASE_URL, SUPABASE_ANON_KEY } from './supabase';

/**
 * Zugänge für Kinder.
 *
 * Drei Dinge sind hier bewusst so gelöst:
 *
 * 1. Kinder haben keine E-Mail-Adresse. Supabase-Auth braucht aber eine.
 *    Deshalb erzeugt die Anwendung eine technische Adresse auf der Domain
 *    akademie.local. Die existiert nicht, empfängt nichts und wird nirgends
 *    angezeigt. Das Kind kennt nur Loginname und Passwort.
 *
 * 2. Das Anlegen läuft über einen ZWEITEN Zugang zu Supabase. Ein
 *    `signUp` meldet nämlich sofort den neuen Benutzer an – über den
 *    normalen Zugang würde die Lehrkraft dadurch mitten im Anlegen aus
 *    ihrer eigenen Sitzung fliegen. Der zweite Zugang merkt sich nichts
 *    und lässt die Sitzung der Lehrkraft unberührt.
 *
 * 3. Die technische Adresse enthält einen Zufallsanteil. Ein Passwort
 *    ändern kann nur der geheime Verwaltungsschlüssel, und der gehört
 *    niemals in den Browser. Zum Zurücksetzen wird deshalb ein neues Konto
 *    angelegt und das Kind dort eingehängt – Loginname bleibt, Passwort ist
 *    neu. Das alte Konto bleibt ohne Rolle zurück und kann nichts mehr sehen.
 */

const LOGIN_DOMAIN = 'akademie.local';

/**
 * Eigener Zugang nur fürs Anlegen. `persistSession: false` ist der
 * entscheidende Teil – ohne das überschriebe das signUp die Anmeldung
 * der Lehrkraft.
 */
const anlage = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
	auth: {
		persistSession: false,
		autoRefreshToken: false,
		detectSessionInUrl: false,
		storageKey: 'akademie-anlage'
	}
});

export type Zugangsdaten = { loginName: string; passwort: string };

/** Prüft einen Loginnamen gegen dieselbe Regel wie die Datenbank. */
export function pruefeLoginName(name: string): string | null {
	const n = name.trim().toLowerCase();
	if (n.length < 3) return 'Der Loginname braucht mindestens 3 Zeichen.';
	if (n.length > 32) return 'Der Loginname darf höchstens 32 Zeichen haben.';
	if (!/^[a-z0-9][a-z0-9._-]*$/.test(n)) {
		return 'Erlaubt sind Kleinbuchstaben, Ziffern, Punkt, Bindestrich und Unterstrich. Keine Umlaute, keine Leerzeichen.';
	}
	return null;
}

/** Macht aus einem Akademienamen einen brauchbaren Loginvorschlag. */
export function loginVorschlag(akademiename: string): string {
	return (
		akademiename
			.toLowerCase()
			.replace(/ä/g, 'ae')
			.replace(/ö/g, 'oe')
			.replace(/ü/g, 'ue')
			.replace(/ß/g, 'ss')
			.replace(/[^a-z0-9]+/g, '-')
			.replace(/^-+|-+$/g, '')
			.slice(0, 32) || 'schueler'
	);
}

// Wörter, die Kinder fehlerfrei abtippen können: keine Umlaute, keine
// Doppeldeutigkeiten, alle gut vorlesbar.
const WOERTER = [
	'Drache',
	'Feder',
	'Mond',
	'Stern',
	'Anker',
	'Turm',
	'Kerze',
	'Nebel',
	'Brunnen',
	'Falke',
	'Krone',
	'Spiegel',
	'Wolke',
	'Blatt',
	'Funke',
	'Schild',
	'Wurzel',
	'Segel',
	'Glocke',
	'Pfeil'
];

/**
 * Erzeugt ein Passwort, das man einem Kind vorlesen kann. Zufällige
 * Zeichenketten sind sicherer, werden aber falsch abgetippt und landen
 * am Ende auf einem Zettel – zwei Wörter und eine Zahl sind hier die
 * praktischere Wahl.
 */
export function passwortVorschlag(): string {
	const w = () => WOERTER[Math.floor(Math.random() * WOERTER.length)];
	const a = w();
	let b = w();
	while (b === a) b = w();
	const zahl = 10 + Math.floor(Math.random() * 90);
	return `${a}-${b}-${zahl}`;
}

function technischeAdresse(loginName: string): string {
	const zufall = Math.random().toString(36).slice(2, 8);
	return `${loginName}-${zufall}@${LOGIN_DOMAIN}`;
}

/** Legt ein Konto an und hängt das Kind daran. */
export async function zugangAnlegen(
	schuelerId: string,
	loginName: string,
	passwort: string
): Promise<void> {
	const name = loginName.trim().toLowerCase();
	const fehler = pruefeLoginName(name);
	if (fehler) throw new Error(fehler);
	if (passwort.length < 8) throw new Error('Das Passwort braucht mindestens 8 Zeichen.');

	// Ist der Loginname schon vergeben? Die Datenbank fängt das ohnehin ab,
	// aber dann wäre das Konto bereits angelegt und bliebe verwaist.
	const { data: belegt } = await supabase
		.from('schueler')
		.select('id')
		.eq('login_name', name)
		.neq('id', schuelerId)
		.maybeSingle();
	if (belegt) throw new Error(`Der Loginname „${name}“ ist schon vergeben.`);

	const adresse = technischeAdresse(name);
	const { data, error } = await anlage.auth.signUp({ email: adresse, password: passwort });
	if (error) {
		if (/signup|disabled/i.test(error.message)) {
			throw new Error(
				'Supabase lässt das Anlegen neuer Konten gerade nicht zu. ' +
					'Im Dashboard unter Authentication → Sign In / Providers muss ' +
					'„Allow new users to sign up" an und die E-Mail-Bestätigung aus sein.'
			);
		}
		throw error;
	}

	const userId = data.user?.id;
	if (!userId) {
		throw new Error(
			'Supabase hat kein Konto zurückgegeben. Vermutlich ist die ' +
				'E-Mail-Bestätigung noch eingeschaltet – die kann bei Adressen ' +
				'auf akademie.local nie ankommen.'
		);
	}

	const { error: rolleFehler } = await supabase
		.from('user_roles')
		.insert({ user_id: userId, role: 'schueler' });
	if (rolleFehler) throw rolleFehler;

	const { error: schuelerFehler } = await supabase
		.from('schueler')
		.update({ login_name: name, user_id: userId, auth_email: adresse })
		.eq('id', schuelerId);
	if (schuelerFehler) throw schuelerFehler;
}

/**
 * Setzt das Passwort neu, indem ein frisches Konto angelegt wird.
 * Der Loginname bleibt derselbe.
 */
export async function passwortNeuSetzen(
	schueler: { id: string; login_name: string | null; user_id: string | null },
	passwort: string
): Promise<void> {
	if (!schueler.login_name) throw new Error('Dieses Kind hat noch keinen Zugang.');
	if (passwort.length < 8) throw new Error('Das Passwort braucht mindestens 8 Zeichen.');

	const adresse = technischeAdresse(schueler.login_name);
	const { data, error } = await anlage.auth.signUp({ email: adresse, password: passwort });
	if (error) throw error;
	const neueId = data.user?.id;
	if (!neueId) throw new Error('Supabase hat kein Konto zurückgegeben.');

	const { error: rolleFehler } = await supabase
		.from('user_roles')
		.insert({ user_id: neueId, role: 'schueler' });
	if (rolleFehler) throw rolleFehler;

	const { error: uFehler } = await supabase
		.from('schueler')
		.update({ user_id: neueId, auth_email: adresse })
		.eq('id', schueler.id);
	if (uFehler) throw uFehler;

	// Dem alten Konto die Rolle nehmen. Ohne Rolle sieht es nichts mehr,
	// selbst wenn jemand das alte Passwort noch kennt.
	if (schueler.user_id) {
		await supabase.from('user_roles').delete().eq('user_id', schueler.user_id);
	}
}

/** Nimmt einem Kind den Zugang. Die Daten des Kindes bleiben bestehen. */
export async function zugangEntziehen(schueler: {
	id: string;
	user_id: string | null;
}): Promise<void> {
	if (schueler.user_id) {
		await supabase.from('user_roles').delete().eq('user_id', schueler.user_id);
	}
	const { error } = await supabase
		.from('schueler')
		.update({ user_id: null, login_name: null, auth_email: null })
		.eq('id', schueler.id);
	if (error) throw error;
}

/** Anmeldung eines Kindes mit Loginname statt E-Mail. */
export async function schuelerAnmelden(loginName: string, passwort: string) {
	const name = loginName.trim().toLowerCase();

	const { data: adresse, error } = await supabase.rpc('login_adresse', { p_login: name });
	if (error) throw error;
	if (!adresse) {
		throw new Error('Loginname oder Passwort stimmt nicht.');
	}

	const ergebnis = await supabase.auth.signInWithPassword({
		email: adresse as string,
		password: passwort
	});
	if (ergebnis.error) {
		// Nicht verraten, welcher der beiden Teile falsch war.
		throw new Error('Loginname oder Passwort stimmt nicht.');
	}
	return ergebnis;
}

// === Klarnamen (nur für Lehrkräfte) ===\
export async function klarnamenHolen(schuelerIds: string[]) {
	if (schuelerIds.length === 0) return {} as Record<string, string>;
	const { data } = await supabase
		.from('schueler_klarnamen')
		.select('schueler_id, klarname')
		.in('schueler_id', schuelerIds);
	const map: Record<string, string> = {};
	for (const z of data ?? []) map[z.schueler_id] = z.klarname;
	return map;
}

export async function klarnameSpeichern(schuelerId: string, klarname: string) {
	const wert = klarname.trim();
	if (!wert) {
		return await supabase.from('schueler_klarnamen').delete().eq('schueler_id', schuelerId);
	}
	return await supabase
		.from('schueler_klarnamen')
		.upsert({ schueler_id: schuelerId, klarname: wert, updated_at: new Date().toISOString() });
}
