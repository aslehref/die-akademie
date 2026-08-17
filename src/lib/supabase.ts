/// <reference types="vite/client" />

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type UserRole = 'admin' | 'teacher' | 'viewer';

export async function getCurrentUser() {
	const {
		data: { user }
	} = await supabase.auth.getUser();
	return user;
}

export async function getUserRole(userId: string): Promise<UserRole | null> {
	const { data } = await supabase.from('user_roles').select('role').eq('user_id', userId).single();
	return data?.role as UserRole;
}

export async function signIn(email: string, password: string) {
	return await supabase.auth.signInWithPassword({ email, password });
}

export async function signUp(email: string, password: string) {
	return await supabase.auth.signUp({ email, password });
}

export async function signOut() {
	return await supabase.auth.signOut();
}

// === Bereich CRUD ===\
export async function getBereiche() {
	return await supabase.from('bereiche').select('*').order('typ').order('name');
}

export async function getBereich(slug: string) {
	return await supabase.from('bereiche').select('*').eq('slug', slug).single();
}

export async function createBereich(data: {
	name: string;
	typ: 'fach' | 'klassenstufe' | 'allgemein';
	beschreibung?: string | null;
	farbe_primär?: string;
	farbe_sekundär?: string;
	motto?: string | null;
}) {
	return await supabase
		.from('bereiche')
		.insert({
			name: data.name,
			slug: data.name
				.toLowerCase()
				.replace(/[^a-z0-9äöü]/g, '-')
				.replace(/-+/g, '-'),
			typ: data.typ,
			beschreibung: data.beschreibung,
			farbe_primär: data.farbe_primär || '#1e3a5f',
			farbe_sekundär: data.farbe_sekundär || '#d4a74a',
			motto: data.motto
		})
		.select()
		.single();
}

export async function updateBereich(
	id: string,
	data: Partial<{
		name: string;
		beschreibung: string;
		farbe_primär: string;
		farbe_sekundär: string;
		motto: string;
	}>
) {
	return await supabase.from('bereiche').update(data).eq('id', id).select().single();
}

export async function deleteBereich(id: string) {
	return await supabase.from('bereiche').delete().eq('id', id);
}

// === Haus CRUD ===\
export async function getHaeuser(bereichId?: string) {
	let query = supabase.from('haeuser').select('*').order('hausname');
	if (bereichId) query = query.eq('bereich_id', bereichId);
	return await query;
}

export async function getHaus(slug: string) {
	return await supabase.from('haeuser').select('*').eq('slug', slug).single();
}

export async function createHaus(data: {
	bereich_id: string;
	name: string;
	hausname: string;
	farbe_primär?: string;
	farbe_sekundär?: string;
	motto?: string | null;
	beschreibung?: string | null;
}) {
	return await supabase
		.from('haeuser')
		.insert({
			bereich_id: data.bereich_id,
			name: data.name,
			hausname: data.hausname,
			slug: data.hausname
				.toLowerCase()
				.replace(/[^a-z0-9äöü]/g, '-')
				.replace(/-+/g, '-'),
			farbe_primär: data.farbe_primär || '#1e3a5f',
			farbe_sekundär: data.farbe_sekundär || '#d4a74a',
			motto: data.motto,
			beschreibung: data.beschreibung
		})
		.select()
		.single();
}

export async function updateHaus(
	id: string,
	data: Partial<{
		name: string;
		hausname: string;
		farbe_primär: string;
		farbe_sekundär: string;
		motto: string;
		beschreibung: string;
	}>
) {
	return await supabase.from('haeuser').update(data).eq('id', id).select().single();
}

export async function deleteHaus(id: string) {
	return await supabase.from('haeuser').delete().eq('id', id);
}

// === Schüler CRUD ===\
export async function getSchueler(hausId: string) {
	return await supabase.from('schueler').select('*').eq('haus_id', hausId).order('akademiename');
}

// Schüler haben bewusst keinen eigenen Zugang: kein Login, keine
// E-Mail-Adressen von Minderjährigen. Die Lehrkraft pflegt die Daten.
export async function createSchueler(data: {
	haus_id: string;
	akademiename: string;
	motto?: string | null;
	titel?: string;
}) {
	return await supabase.from('schueler').insert(data).select().single();
}

export async function deleteSchueler(id: string) {
	return await supabase.from('schueler').delete().eq('id', id);
}

export async function updateSchueler(
	id: string,
	data: Partial<{
		akademiename: string;
		avatar_url: string;
		motto: string;
		titel: string;
	}>
) {
	return await supabase.from('schueler').update(data).eq('id', id).select().single();
}

// === Punkte ===\
export async function awardPoints(data: {
	schueler_id: string;
	haus_id?: string;
	bereich_id?: string | null;
	betrag: number;
	kategorie: string;
	grund: string;
	lehrer_id?: string | null;
}) {
	return await supabase.from('punkte_transaktionen').insert(data).select().single();
}

export async function getTransaktionen(schuelerId: string) {
	return await supabase
		.from('punkte_transaktionen')
		.select('*')
		.eq('schueler_id', schuelerId)
		.order('created_at', { ascending: false });
}

export async function getHausTransaktionen(hausId: string) {
	return await supabase
		.from('punkte_transaktionen')
		.select('*')
		.eq('haus_id', hausId)
		.order('created_at', { ascending: false });
}

// === Chronik ===\
export async function addChronik(data: {
	haus_id: string;
	bereich_id?: string | null;
	typ: string;
	titel: string;
	beschreibung?: string | null;
}) {
	return await supabase.from('chronik').insert(data).select().single();
}

export async function getChronik(hausId: string) {
	return await supabase
		.from('chronik')
		.select('*')
		.eq('haus_id', hausId)
		.order('created_at', { ascending: false })
		.limit(20);
}

// === Quests ===\
export async function getQuests(scope?: {
	bereich_id?: string | null;
	haus_id?: string;
	status?: string;
}) {
	let query = supabase.from('quests').select('*').order('startdatum', { ascending: false });
	if (scope?.bereich_id) query = query.eq('bereich_id', scope.bereich_id);
	if (scope?.haus_id) query = query.eq('haus_id', scope.haus_id);
	if (scope?.status) query = query.eq('status', scope.status);
	return await query;
}

export async function createQuest(data: {
	titel: string;
	beschreibung: string;
	schwierigkeit: number;
	belohnung_hauspunkte: number;
	belohnung_xp: number;
	gültigkeitsbereich: string;
	bereich_id?: string | null;
	haus_id?: string;
	startdatum: string;
	enddatum?: string;
}) {
	return await supabase
		.from('quests')
		.insert({
			...data,
			status: 'entwurf'
		})
		.select()
		.single();
}

// === Belohnungen ===\
export async function getBelohnungen(bereichId?: string) {
	let query = supabase.from('belohnungen').select('*').eq('aktiv', true).order('kosten');
	// Ohne Bereich: nur globale Belohnungen. Mit Bereich: global + die des Bereichs.
	if (bereichId) {
		query = query.or(`gültigkeitsbereich.eq.global,bereich_id.eq.${bereichId}`);
	} else {
		query = query.eq('gültigkeitsbereich', 'global');
	}
	return await query;
}

// === Einlösungen ===\
// Eine Einlösung ist bewusst KEINE negative Punktetransaktion: sie kostet
// das persönliche Guthaben, aber weder Erfahrung (XP) noch Hauspunkte.
export async function createEinloesung(data: {
	schueler_id: string;
	belohnung_id?: string | null;
	belohnung_name: string;
	kosten: number;
	eingeloest_von?: string | null;
	notiz?: string;
}) {
	return await supabase.from('einloesungen').insert(data).select().single();
}

export async function getEinloesungen(schuelerId: string, limit = 20) {
	return await supabase
		.from('einloesungen')
		.select('*')
		.eq('schueler_id', schuelerId)
		.order('created_at', { ascending: false })
		.limit(limit);
}

export async function stornoEinloesung(id: string) {
	return await supabase
		.from('einloesungen')
		.update({ storniert: true, storniert_am: new Date().toISOString() })
		.eq('id', id)
		.select()
		.single();
}

export async function createBelohnung(data: {
	name: string;
	kategorie: 'joker' | 'wahlmöglichkeit' | 'aktivität' | 'challenge' | 'legendär';
	kosten: number;
	beschreibung: string;
	gültigkeitsbereich: 'global' | 'fach' | 'klassenstufe' | 'klasse';
	bereich_id?: string | null;
}) {
	return await supabase
		.from('belohnungen')
		.insert({
			name: data.name,
			kategorie: data.kategorie,
			kosten: data.kosten,
			beschreibung: data.beschreibung,
			gültigkeitsbereich: data.gültigkeitsbereich,
			bereich_id: data.bereich_id
		})
		.select()
		.single();
}

export async function updateBelohnung(
	id: string,
	data: Partial<{
		name: string;
		kategorie: 'joker' | 'wahlmöglichkeit' | 'aktivität' | 'challenge' | 'legendär';
		kosten: number;
		beschreibung: string;
		gültigkeitsbereich: 'global' | 'fach' | 'klassenstufe' | 'klasse';
		bereich_id?: string | null;
	}>
) {
	return await supabase.from('belohnungen').update(data).eq('id', id).select().single();
}

export async function deleteBelohnung(id: string) {
	return await supabase.from('belohnungen').delete().eq('id', id);
}

// === Abzeichen ===\
export async function getAbzeichen(bereichId?: string) {
	let query = supabase.from('abzeichen').select('*');
	if (bereichId) query = query.or(`bereich_id.eq.${bereichId},gültigkeitsbereich.eq.global`);
	return await query;
}

export async function createAbzeichen(data: {
	name: string;
	symbol: string;
	beschreibung: string;
	bedingung: 'manuell' | 'anzahl_aktionen' | 'quest' | 'punktzahl' | 'besondere_leistung';
	bedingung_wert?: number | null;
	gültigkeitsbereich: 'global' | 'fach' | 'klassenstufe' | 'klasse';
	bereich_id?: string | null;
}) {
	return await supabase
		.from('abzeichen')
		.insert({
			name: data.name,
			symbol: data.symbol,
			beschreibung: data.beschreibung,
			bedingung: data.bedingung,
			bedingung_wert: data.bedingung_wert,
			gültigkeitsbereich: data.gültigkeitsbereich,
			bereich_id: data.bereich_id
		})
		.select()
		.single();
}

export async function updateAbzeichen(
	id: string,
	data: Partial<{
		name: string;
		symbol: string;
		beschreibung: string;
		bedingung: 'manuell' | 'anzahl_aktionen' | 'quest' | 'punktzahl' | 'besondere_leistung';
		bedingung_wert?: number | null;
		gültigkeitsbereich: 'global' | 'fach' | 'klassenstufe' | 'klasse';
		bereich_id?: string | null;
	}>
) {
	return await supabase.from('abzeichen').update(data).eq('id', id).select().single();
}

export async function deleteAbzeichen(id: string) {
	return await supabase.from('abzeichen').delete().eq('id', id);
}

// === Schüler-Abzeichen (Many-to-Many) ===\
export async function awardAbzeichen(schuelerId: string, abzeichenId: string) {
	return await supabase
		.from('schueler_abzeichen')
		.insert({
			schueler_id: schuelerId,
			abzeichen_id: abzeichenId
		})
		.select()
		.single();
}

export async function getSchuelerAbzeichen(schuelerId: string) {
	return await supabase
		.from('schueler_abzeichen')
		.select('*, abzeichen:abzeichen_id(*)')
		.eq('schueler_id', schuelerId);
}

// === Quest completion ===\
export async function completeQuest(questId: string, schuelerId: string) {
	// First get quest details
	const { data: quest, error: questError } = await supabase
		.from('quests')
		.select('*')
		.eq('id', questId)
		.single();
	if (questError) throw questError;

	// Award XP and points to student
	const xpAward = quest.belohnung_xp;
	const hauspunkteAward = quest.belohnung_hauspunkte;

	// Get student's haus_id and akademiename
	const { data: schueler, error: schuelerError } = await supabase
		.from('schueler')
		.select('haus_id, xp, level, punkte, akademiename')
		.eq('id', schuelerId)
		.single();
	if (schuelerError) throw schuelerError;

	// Zwei getrennte Buchungen, weil die Quest zwei verschiedene Dinge belohnt:
	//
	//   belohnung_hauspunkte -> zählt für das Haus (Buchung MIT haus_id)
	//   belohnung_xp         -> zählt nur für das Kind (Buchung OHNE haus_id)
	//
	// Die Hauspunkte eines Hauses sind die Summe aller Buchungen mit seiner
	// haus_id. Eine Buchung ohne haus_id fließt daher in XP und persönliches
	// Guthaben, lässt den Hauspokal aber unberührt.
	const buchungen = [];

	if (hauspunkteAward > 0) {
		buchungen.push({
			schueler_id: schuelerId,
			haus_id: schueler.haus_id,
			bereich_id: quest.bereich_id,
			betrag: hauspunkteAward,
			kategorie: 'quest',
			grund: `Quest abgeschlossen: ${quest.titel}`,
			lehrer_id: null
		});
	}

	if (xpAward > 0) {
		buchungen.push({
			schueler_id: schuelerId,
			haus_id: null,
			bereich_id: quest.bereich_id,
			betrag: xpAward,
			kategorie: 'quest',
			grund: `Erfahrung aus Quest: ${quest.titel}`,
			lehrer_id: null
		});
	}

	if (buchungen.length > 0) {
		const { error: pointsError } = await supabase.from('punkte_transaktionen').insert(buchungen);
		if (pointsError) throw pointsError;
	}

	// Add to chronik
	await supabase.from('chronik').insert({
		haus_id: schueler.haus_id,
		bereich_id: quest.bereich_id,
		typ: 'quest',
		titel: `${schueler.akademiename} hat die Quest „${quest.titel}“ abgeschlossen`,
		beschreibung: `+${xpAward} XP, +${hauspunkteAward} Hauspunkte`
	});

	return { success: true };
}
