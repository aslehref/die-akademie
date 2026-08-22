<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import {
		supabase,
		createSchueler,
		deleteSchueler,
		awardPoints,
		getChronik,
		getHeldentaten,
		createHeldentat,
		deleteHeldentat,
		updateHaus,
		deleteHaus,
		hausLoeschUmfang
	} from '$lib/supabase.js';
	import { ladeBildHoch, bildLinks, loescheBilder, pruefeBild } from '$lib/bilder.js';
	import {
		zugangAnlegen,
		passwortNeuSetzen,
		zugangEntziehen,
		klarnamenHolen,
		klarnameSpeichern,
		loginVorschlag,
		passwortVorschlag,
		pruefeLoginName
	} from '$lib/schuelerkonten.js';

	let haus = $state<any>(null);
	let schueler = $state<any[]>([]);
	let buchungen = $state<any[]>([]);
	let chronik = $state<any[]>([]);
	let heldentaten = $state<any[]>([]);
	let links = $state<Record<string, string>>({});
	let laedt = $state(true);
	let ladeFehler = $state('');
	let meldung = $state('');
	let fehler = $state('');
	let arbeitet = $state(false);

	let offen = $state<'' | 'aufnehmen' | 'punkte' | 'heldentat' | 'bearbeiten' | 'loeschen'>('');

	// Aufnahme
	let neuerName = $state('');
	let aufnahmeFehler = $state('');

	// Punkte
	let punkteSchueler = $state('');
	let punkteBetrag = $state(10);
	let punkteKategorie = $state('lernen');
	let punkteGrund = $state('');
	let lehrerId = $state<string | null>(null);

	// Heldentat
	let htTitel = $state('');
	let htText = $state('');
	let htDatum = $state('');
	let htSchueler = $state('');
	let htDateien = $state<File[]>([]);
	let htVorschau = $state<string[]>([]);
	let htFehler = $state('');

	// Bearbeiten
	let bName = $state('');
	let bHausname = $state('');
	let bMotto = $state('');
	let bBeschreibung = $state('');
	let bFarbe1 = $state('#1e3a5f');
	let bFarbe2 = $state('#d4a74a');
	let bWappen = $state<File | null>(null);
	let bWappenVorschau = $state('');

	// Löschen
	let umfang = $state<{ schueler: number; heldentaten: number; buchungen: number } | null>(null);
	let loeschBestaetigung = $state('');

	// Zugänge und Klarnamen
	let klarnamen = $state<Record<string, string>>({});
	let zugangFuer = $state<string | null>(null);
	let zLogin = $state('');
	let zPasswort = $state('');
	let zKlarname = $state('');
	let zFehler = $state('');
	let zHinweis = $state('');

	const kategorien = [
		{ value: 'lernen', label: '📚 Lernen & Leistung' },
		{ value: 'sozialverhalten', label: '🤝 Sozialverhalten' },
		{ value: 'selbstständigkeit', label: '🧠 Selbstständigkeit' },
		{ value: 'diskussion', label: '🗣️ Diskussion' },
		{ value: 'demokratie', label: '🏛️ Demokratie' },
		{ value: 'persönliche_entwicklung', label: '🌱 Persönliche Entwicklung' },
		{ value: 'verantwortung', label: '🧹 Verantwortung' },
		{ value: 'quest', label: '⚔️ Quest' }
	];

	onMount(async () => {
		htDatum = new Date().toISOString().slice(0, 10);
		await laden();
	});

	async function laden() {
		laedt = true;
		ladeFehler = '';
		try {
			const { data: h, error } = await supabase
				.from('haeuser')
				.select('*')
				.eq('slug', $page.params.houslug)
				.single();
			if (error) throw error;
			haus = h;

			const [s, t, c, ht] = await Promise.all([
				supabase.from('schueler').select('*').eq('haus_id', h.id).order('akademiename'),
				supabase
					.from('punkte_transaktionen')
					.select('*, schueler:schueler_id(akademiename)')
					.eq('haus_id', h.id)
					.order('created_at', { ascending: false })
					.limit(30),
				getChronik(h.id),
				getHeldentaten(h.id)
			]);
			schueler = s.data ?? [];
			buchungen = t.data ?? [];
			chronik = c.data ?? [];
			heldentaten = ht.data ?? [];

			await linksHolen();
			klarnamen = await klarnamenHolen(schueler.map((k) => k.id));
			setzeBearbeitenFelder();

			const { data } = await supabase.auth.getUser();
			lehrerId = data.user?.id ?? null;
		} catch (e: any) {
			ladeFehler = e?.message ?? 'Das Haus konnte nicht geladen werden.';
		} finally {
			laedt = false;
		}
	}

	/**
	 * Bilder liegen in einem privaten Speicher. Für die Anzeige braucht es
	 * jedes Mal frisch unterschriebene Links – deshalb alle Pfade der Seite
	 * in einem Rutsch auflösen statt einzeln je Bild.
	 */
	async function linksHolen() {
		const pfade = [
			...(haus?.logo_pfad ? [haus.logo_pfad] : []),
			...heldentaten.flatMap((h) => h.bilder ?? [])
		];
		links = await bildLinks(pfade);
	}

	function setzeBearbeitenFelder() {
		if (!haus) return;
		bName = haus.name ?? '';
		bHausname = haus.hausname ?? '';
		bMotto = haus.motto ?? '';
		bBeschreibung = haus.beschreibung ?? '';
		bFarbe1 = haus.farbe_primär ?? '#1e3a5f';
		bFarbe2 = haus.farbe_sekundär ?? '#d4a74a';
		bWappen = null;
		bWappenVorschau = '';
	}

	function oeffne(was: typeof offen) {
		offen = offen === was ? '' : was;
		meldung = '';
		fehler = '';
		aufnahmeFehler = '';
		htFehler = '';
		if (was === 'bearbeiten') setzeBearbeitenFelder();
		if (was === 'loeschen') ladeUmfang();
	}

	// ---------------------------------------------------------------- Aufnahme
	async function aufnehmen(e: Event) {
		e.preventDefault();
		if (!haus) return;
		aufnahmeFehler = '';
		const { error } = await createSchueler({
			haus_id: haus.id,
			akademiename: neuerName.trim()
		});
		if (error) {
			aufnahmeFehler =
				error.code === '23505'
					? `„${neuerName.trim()}“ gibt es in diesem Haus schon.`
					: error.message;
			return;
		}
		neuerName = '';
		offen = '';
		meldung = 'Aufgenommen.';
		await laden();
	}

	async function entlassen(s: any) {
		if (!confirmErsatz(`${s.akademiename} wirklich aus dem Haus entfernen?`)) return;
		const { error } = await deleteSchueler(s.id);
		if (error) fehler = error.message;
		else await laden();
	}

	// Kleine Hilfe, damit die Rückfrage an einer Stelle sitzt.
	function confirmErsatz(text: string) {
		return window.confirm(text);
	}

	// ---------------------------------------------------------------- Zugänge
	function zugangOeffnen(s: any) {
		if (zugangFuer === s.id) {
			zugangFuer = null;
			return;
		}
		zugangFuer = s.id;
		zLogin = s.login_name ?? loginVorschlag(s.akademiename);
		zPasswort = passwortVorschlag();
		zKlarname = klarnamen[s.id] ?? '';
		zFehler = '';
		zHinweis = '';
	}

	async function zugangSpeichern(s: any) {
		zFehler = '';
		zHinweis = '';
		const formfehler = pruefeLoginName(zLogin);
		if (formfehler) {
			zFehler = formfehler;
			return;
		}
		arbeitet = true;
		try {
			// Der Klarname wird immer gespeichert, auch ohne Zugang.
			const { error: kFehler } = await klarnameSpeichern(s.id, zKlarname);
			if (kFehler) throw kFehler;

			if (!s.login_name) {
				await zugangAnlegen(s.id, zLogin, zPasswort);
				zHinweis =
					`Zugang angelegt. Loginname „${zLogin.trim().toLowerCase()}“, ` +
					`Passwort „${zPasswort}“. Notiere beides jetzt – das Passwort ist danach nicht mehr einsehbar.`;
			} else {
				zHinweis = 'Klarname gespeichert.';
			}
			await laden();
		} catch (err: any) {
			zFehler = err?.message ?? 'Das hat nicht geklappt.';
		} finally {
			arbeitet = false;
		}
	}

	async function passwortNeu(s: any) {
		zFehler = '';
		zHinweis = '';
		arbeitet = true;
		try {
			const neues = passwortVorschlag();
			await passwortNeuSetzen(s, neues);
			zPasswort = neues;
			zHinweis = `Neues Passwort für „${s.login_name}“: „${neues}“. Jetzt notieren.`;
			await laden();
		} catch (err: any) {
			zFehler = err?.message ?? 'Das Zurücksetzen hat nicht geklappt.';
		} finally {
			arbeitet = false;
		}
	}

	async function zugangWeg(s: any) {
		if (!confirmErsatz(`${s.akademiename} den Zugang entziehen? Die Punkte bleiben erhalten.`))
			return;
		arbeitet = true;
		zFehler = '';
		try {
			await zugangEntziehen(s);
			zHinweis = 'Zugang entzogen.';
			await laden();
		} catch (err: any) {
			zFehler = err?.message ?? 'Das hat nicht geklappt.';
		} finally {
			arbeitet = false;
		}
	}

	// ---------------------------------------------------------------- Punkte
	async function punkteVerleihen(e: Event) {
		e.preventDefault();
		if (!haus || !punkteSchueler) return;
		arbeitet = true;
		fehler = '';
		const { error } = await awardPoints({
			schueler_id: punkteSchueler,
			haus_id: haus.id,
			bereich_id: haus.bereich_id,
			betrag: punkteBetrag,
			kategorie: punkteKategorie,
			grund: punkteGrund,
			lehrer_id: lehrerId
		});
		arbeitet = false;
		if (error) {
			fehler = error.message;
			return;
		}
		punkteGrund = '';
		offen = '';
		meldung = 'Punkte verliehen.';
		await laden();
	}

	// ---------------------------------------------------------------- Heldentat
	function dateienGewaehlt(e: Event) {
		htFehler = '';
		const liste = Array.from((e.target as HTMLInputElement).files ?? []);
		for (const d of liste) {
			const f = pruefeBild(d);
			if (f) {
				htFehler = f;
				return;
			}
		}
		htDateien = liste;
		htVorschau = liste.map((d) => URL.createObjectURL(d));
	}

	async function heldentatEintragen(e: Event) {
		e.preventDefault();
		if (!haus) return;
		arbeitet = true;
		htFehler = '';
		try {
			const pfade: string[] = [];
			for (const datei of htDateien) {
				pfade.push(await ladeBildHoch(datei, `haeuser/${haus.id}/heldentaten`));
			}

			const { error } = await createHeldentat({
				haus_id: haus.id,
				schueler_id: htSchueler || null,
				titel: htTitel.trim(),
				beschreibung: htText.trim() || null,
				geschehen_am: htDatum,
				bilder: pfade,
				erstellt_von: lehrerId
			});
			if (error) throw error;

			htTitel = '';
			htText = '';
			htSchueler = '';
			htDateien = [];
			htVorschau = [];
			htDatum = new Date().toISOString().slice(0, 10);
			offen = '';
			meldung = 'Heldentat festgehalten.';
			await laden();
		} catch (err: any) {
			htFehler = err?.message ?? 'Die Heldentat konnte nicht gespeichert werden.';
		} finally {
			arbeitet = false;
		}
	}

	async function heldentatLoeschen(h: any) {
		if (!confirmErsatz(`„${h.titel}“ wirklich löschen? Die Bilder gehen mit.`)) return;
		arbeitet = true;
		try {
			const { error } = await deleteHeldentat(h.id);
			if (error) throw error;
			await loescheBilder(h.bilder ?? []);
			await laden();
		} catch (err: any) {
			fehler = err?.message ?? 'Löschen fehlgeschlagen.';
		} finally {
			arbeitet = false;
		}
	}

	// ---------------------------------------------------------------- Bearbeiten
	function wappenGewaehlt(e: Event) {
		fehler = '';
		const datei = (e.target as HTMLInputElement).files?.[0] ?? null;
		if (!datei) return;
		const f = pruefeBild(datei);
		if (f) {
			fehler = f;
			return;
		}
		bWappen = datei;
		bWappenVorschau = URL.createObjectURL(datei);
	}

	async function hausSpeichern(e: Event) {
		e.preventDefault();
		if (!haus) return;
		arbeitet = true;
		fehler = '';
		try {
			let logoPfad = haus.logo_pfad ?? null;
			if (bWappen) {
				const neu = await ladeBildHoch(bWappen, `haeuser/${haus.id}`);
				// Erst nach erfolgreichem Hochladen das alte Wappen entfernen,
				// sonst steht das Haus bei einem Fehler ganz ohne da.
				if (logoPfad) await loescheBilder([logoPfad]);
				logoPfad = neu;
			}

			const { error } = await updateHaus(haus.id, {
				name: bName.trim(),
				hausname: bHausname.trim(),
				motto: bMotto.trim(),
				beschreibung: bBeschreibung.trim(),
				farbe_primär: bFarbe1,
				farbe_sekundär: bFarbe2,
				logo_pfad: logoPfad
			});
			if (error) throw error;

			offen = '';
			meldung = 'Gespeichert.';
			await laden();
		} catch (err: any) {
			fehler = err?.message ?? 'Speichern fehlgeschlagen.';
		} finally {
			arbeitet = false;
		}
	}

	async function wappenEntfernen() {
		if (!haus?.logo_pfad) return;
		arbeitet = true;
		const alt = haus.logo_pfad;
		const { error } = await updateHaus(haus.id, { logo_pfad: null });
		if (!error) await loescheBilder([alt]);
		arbeitet = false;
		await laden();
	}

	// ---------------------------------------------------------------- Löschen
	async function ladeUmfang() {
		umfang = null;
		loeschBestaetigung = '';
		if (!haus) return;
		umfang = await hausLoeschUmfang(haus.id);
	}

	async function hausLoeschen() {
		if (!haus) return;
		arbeitet = true;
		fehler = '';
		try {
			// Bilder zuerst, solange die Pfade noch bekannt sind.
			const pfade = [
				...(haus.logo_pfad ? [haus.logo_pfad] : []),
				...heldentaten.flatMap((h) => h.bilder ?? [])
			];
			await loescheBilder(pfade);

			const { error } = await deleteHaus(haus.id);
			if (error) throw error;
			await goto(`${base}/admin/bereiche/${$page.params.slug}`);
		} catch (err: any) {
			fehler = err?.message ?? 'Löschen fehlgeschlagen.';
			arbeitet = false;
		}
	}

	// ---------------------------------------------------------------- Anzeige
	function datum(s: string) {
		return new Date(s).toLocaleDateString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric'
		});
	}
	function datumZeit(s: string) {
		return new Date(s).toLocaleDateString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}
	function katLabel(v: string) {
		return kategorien.find((k) => k.value === v)?.label ?? v;
	}

	const eingabeKlasse =
		'w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none';
</script>

<svelte:head>
	<title>{haus?.hausname ?? 'Haus'} · Die Akademie</title>
</svelte:head>

{#if laedt}
	<div class="text-academy-steel">Lade…</div>
{:else if ladeFehler}
	<div class="bg-red-900/30 border border-red-700/50 text-red-200 p-4 rounded">{ladeFehler}</div>
{:else if !haus}
	<div class="text-academy-steel">Dieses Haus gibt es nicht.</div>
{:else}
	<div class="mb-4">
		<a
			href="{base}/admin/bereiche/{$page.params.slug}"
			class="text-academy-steel text-sm hover:text-academy-parchment">← Zurück zur Fakultät</a
		>
	</div>

	<!-- Kopf des Hauses -->
	<div
		class="bg-academy-surface rounded-lg p-6 border mb-6"
		style="border-color: {haus.farbe_primär}44;"
	>
		<div class="flex items-start justify-between gap-4 flex-wrap">
			<div class="flex items-center gap-4">
				{#if haus.logo_pfad && links[haus.logo_pfad]}
					<img
						src={links[haus.logo_pfad]}
						alt="Wappen von {haus.hausname}"
						class="w-20 h-20 rounded-lg object-cover border-2"
						style="border-color: {haus.farbe_sekundär}"
					/>
				{:else}
					<div
						class="w-20 h-20 rounded-lg flex items-center justify-center text-3xl font-bold font-heading"
						style="background: {haus.farbe_primär}; color: {haus.farbe_sekundär}"
					>
						{haus.hausname[0]}
					</div>
				{/if}
				<div>
					<h2 class="text-2xl font-heading text-academy-gold">{haus.hausname}</h2>
					<p class="text-academy-steel">
						{haus.name}{#if haus.motto}
							· „{haus.motto}“{/if}
					</p>
					{#if haus.beschreibung}
						<p class="text-sm text-academy-steel mt-1 max-w-xl">{haus.beschreibung}</p>
					{/if}
				</div>
			</div>
			<div class="text-right">
				<div class="text-3xl font-bold text-academy-gold">{haus.hauspunkte}</div>
				<div class="text-sm text-academy-steel">Hauspunkte</div>
				<div class="text-xs text-academy-steel mt-2">
					🔥 Hausfeuer {haus.energie}/{haus.energie_max}
				</div>
			</div>
		</div>
	</div>

	{#if meldung}
		<div
			class="bg-academy-green/30 border border-academy-green text-academy-parchment p-3 rounded mb-4"
		>
			{meldung}
		</div>
	{/if}
	{#if fehler}
		<div class="bg-red-900/30 border border-red-700/50 text-red-200 p-3 rounded mb-4">{fehler}</div>
	{/if}

	<!-- Handlungen -->
	<div class="flex gap-2 mb-6 flex-wrap">
		<button
			onclick={() => oeffne('heldentat')}
			class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90"
		>
			⚔️ Heldentat eintragen
		</button>
		<button
			onclick={() => oeffne('punkte')}
			class="px-4 py-2 bg-academy-cyan text-white rounded font-bold text-sm hover:bg-academy-cyan/80"
		>
			✨ Punkte verleihen
		</button>
		<button
			onclick={() => oeffne('aufnehmen')}
			class="px-4 py-2 rounded border border-academy-blue/50 text-academy-parchment text-sm hover:bg-academy-blue/30"
		>
			＋ In die Akademie aufnehmen
		</button>
		<button
			onclick={() => oeffne('bearbeiten')}
			class="px-4 py-2 rounded border border-academy-blue/50 text-academy-parchment text-sm hover:bg-academy-blue/30"
		>
			✎ Haus bearbeiten
		</button>
		<button
			onclick={() => oeffne('loeschen')}
			class="px-4 py-2 rounded border border-red-800/60 text-red-300 text-sm hover:bg-red-900/30"
		>
			Haus auflösen
		</button>
	</div>

	<!-- Heldentat eintragen -->
	{#if offen === 'heldentat'}
		<form
			onsubmit={heldentatEintragen}
			class="bg-academy-surface rounded-lg p-5 border border-academy-gold/40 mb-6 space-y-4"
		>
			<h3 class="font-heading text-academy-gold text-lg">Eine Heldentat festhalten</h3>
			<div class="grid grid-cols-1 md:grid-cols-3 gap-3">
				<div class="md:col-span-2">
					<label for="ht-titel" class="block text-sm text-academy-parchment mb-1"
						>Was ist geschehen?</label
					>
					<input
						id="ht-titel"
						type="text"
						bind:value={htTitel}
						required
						class={eingabeKlasse}
						placeholder="z.B. Das Haus hat die Bibliothek hergerichtet"
					/>
				</div>
				<div>
					<label for="ht-datum" class="block text-sm text-academy-parchment mb-1">Wann?</label>
					<input id="ht-datum" type="date" bind:value={htDatum} required class={eingabeKlasse} />
				</div>
			</div>

			<div>
				<label for="ht-wer" class="block text-sm text-academy-parchment mb-1">Wer?</label>
				<select id="ht-wer" bind:value={htSchueler} class={eingabeKlasse}>
					<option value="">Das ganze Haus</option>
					{#each schueler as s}
						<option value={s.id}>{s.akademiename}</option>
					{/each}
				</select>
			</div>

			<div>
				<label for="ht-text" class="block text-sm text-academy-parchment mb-1"
					>Erzähl es (kann leer bleiben)</label
				>
				<textarea id="ht-text" bind:value={htText} rows="3" class={eingabeKlasse}></textarea>
			</div>

			<div>
				<label for="ht-bilder" class="block text-sm text-academy-parchment mb-1">Bilder</label>
				<input
					id="ht-bilder"
					type="file"
					accept="image/*"
					multiple
					onchange={dateienGewaehlt}
					class="block w-full text-sm text-academy-steel file:mr-3 file:py-2 file:px-4 file:rounded file:border-0 file:bg-academy-blue/40 file:text-academy-parchment hover:file:bg-academy-blue/60"
				/>
				<p class="text-xs text-academy-steel mt-1">
					Höchstens 10 MB je Bild. Die Bilder sind nur für angemeldete Personen sichtbar.
				</p>
				{#if htVorschau.length > 0}
					<div class="flex gap-2 mt-3 flex-wrap">
						{#each htVorschau as v}
							<img
								src={v}
								alt="Vorschau"
								class="w-24 h-24 object-cover rounded border border-academy-blue/40"
							/>
						{/each}
					</div>
				{/if}
			</div>

			{#if htFehler}
				<p class="text-sm text-red-300">{htFehler}</p>
			{/if}

			<button
				type="submit"
				disabled={arbeitet}
				class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 disabled:opacity-50"
			>
				{arbeitet ? 'Einen Moment…' : 'Heldentat festhalten'}
			</button>
		</form>
	{/if}

	<!-- Punkte verleihen -->
	{#if offen === 'punkte'}
		<form
			onsubmit={punkteVerleihen}
			class="bg-academy-surface rounded-lg p-5 border border-academy-blue/30 mb-6 space-y-3"
		>
			<h3 class="font-heading text-academy-gold text-lg">Punkte verleihen</h3>
			<div class="grid grid-cols-1 md:grid-cols-3 gap-3">
				<div>
					<label for="p-wer" class="block text-sm text-academy-parchment mb-1">An wen?</label>
					<select id="p-wer" bind:value={punkteSchueler} required class={eingabeKlasse}>
						<option value="">— wählen —</option>
						{#each schueler as s}
							<option value={s.id}>{s.akademiename}</option>
						{/each}
					</select>
				</div>
				<div>
					<label for="p-betrag" class="block text-sm text-academy-parchment mb-1">Wie viel?</label>
					<input
						id="p-betrag"
						type="number"
						bind:value={punkteBetrag}
						required
						class={eingabeKlasse}
					/>
				</div>
				<div>
					<label for="p-kat" class="block text-sm text-academy-parchment mb-1">Wofür?</label>
					<select id="p-kat" bind:value={punkteKategorie} class={eingabeKlasse}>
						{#each kategorien as k}
							<option value={k.value}>{k.label}</option>
						{/each}
					</select>
				</div>
			</div>
			<div>
				<label for="p-grund" class="block text-sm text-academy-parchment mb-1">Begründung</label>
				<input
					id="p-grund"
					type="text"
					bind:value={punkteGrund}
					required
					class={eingabeKlasse}
					placeholder="Was genau war es?"
				/>
			</div>
			<p class="text-xs text-academy-steel">
				Ein negativer Betrag zieht Guthaben ab, lässt die Erfahrung aber unberührt.
			</p>
			<button
				type="submit"
				disabled={arbeitet}
				class="px-4 py-2 bg-academy-cyan text-white rounded font-bold text-sm hover:bg-academy-cyan/80 disabled:opacity-50"
			>
				Punkte verleihen
			</button>
		</form>
	{/if}

	<!-- Aufnehmen -->
	{#if offen === 'aufnehmen'}
		<form
			onsubmit={aufnehmen}
			class="bg-academy-surface rounded-lg p-5 border border-academy-blue/30 mb-6 space-y-3"
		>
			<h3 class="font-heading text-academy-gold text-lg">In die Akademie aufnehmen</h3>
			<div>
				<label for="akademiename" class="block text-sm text-academy-parchment mb-1"
					>Akademiename</label
				>
				<input
					id="akademiename"
					type="text"
					bind:value={neuerName}
					required
					class={eingabeKlasse}
					placeholder="z.B. Raven"
				/>
			</div>
			{#if aufnahmeFehler}
				<p class="text-sm text-red-300">{aufnahmeFehler}</p>
			{/if}
			<p class="text-xs text-academy-steel">
				Kinder melden sich nicht selbst an. Der Akademiename genügt.
			</p>
			<button
				type="submit"
				class="px-4 py-2 rounded border border-academy-blue/50 text-academy-parchment text-sm hover:bg-academy-blue/30"
			>
				Aufnehmen
			</button>
		</form>
	{/if}

	<!-- Bearbeiten -->
	{#if offen === 'bearbeiten'}
		<form
			onsubmit={hausSpeichern}
			class="bg-academy-surface rounded-lg p-5 border border-academy-blue/30 mb-6 space-y-3"
		>
			<h3 class="font-heading text-academy-gold text-lg">Haus bearbeiten</h3>
			<div class="grid grid-cols-1 md:grid-cols-2 gap-3">
				<div>
					<label for="b-hausname" class="block text-sm text-academy-parchment mb-1">Hausname</label>
					<input
						id="b-hausname"
						type="text"
						bind:value={bHausname}
						required
						class={eingabeKlasse}
					/>
				</div>
				<div>
					<label for="b-name" class="block text-sm text-academy-parchment mb-1"
						>Klasse oder Kurs</label
					>
					<input id="b-name" type="text" bind:value={bName} required class={eingabeKlasse} />
				</div>
			</div>
			<div>
				<label for="b-motto" class="block text-sm text-academy-parchment mb-1">Motto</label>
				<input id="b-motto" type="text" bind:value={bMotto} class={eingabeKlasse} />
			</div>
			<div>
				<label for="b-text" class="block text-sm text-academy-parchment mb-1">Beschreibung</label>
				<textarea id="b-text" bind:value={bBeschreibung} rows="2" class={eingabeKlasse}></textarea>
			</div>
			<div class="grid grid-cols-2 gap-3 max-w-xs">
				<div>
					<label for="b-f1" class="block text-sm text-academy-parchment mb-1">Hauptfarbe</label>
					<input
						id="b-f1"
						type="color"
						bind:value={bFarbe1}
						class="w-full h-10 rounded bg-academy-bg"
					/>
				</div>
				<div>
					<label for="b-f2" class="block text-sm text-academy-parchment mb-1">Zweitfarbe</label>
					<input
						id="b-f2"
						type="color"
						bind:value={bFarbe2}
						class="w-full h-10 rounded bg-academy-bg"
					/>
				</div>
			</div>

			<div>
				<label for="b-wappen" class="block text-sm text-academy-parchment mb-1">Wappen</label>
				<div class="flex items-center gap-4 flex-wrap">
					{#if bWappenVorschau}
						<img src={bWappenVorschau} alt="Neues Wappen" class="w-20 h-20 object-cover rounded" />
					{:else if haus.logo_pfad && links[haus.logo_pfad]}
						<img
							src={links[haus.logo_pfad]}
							alt="Aktuelles Wappen"
							class="w-20 h-20 object-cover rounded"
						/>
					{/if}
					<input
						id="b-wappen"
						type="file"
						accept="image/*"
						onchange={wappenGewaehlt}
						class="block text-sm text-academy-steel file:mr-3 file:py-2 file:px-4 file:rounded file:border-0 file:bg-academy-blue/40 file:text-academy-parchment hover:file:bg-academy-blue/60"
					/>
					{#if haus.logo_pfad}
						<button
							type="button"
							onclick={wappenEntfernen}
							class="text-xs px-2 py-1 rounded border border-academy-steel/50 text-academy-steel hover:bg-academy-steel/20"
						>
							Wappen entfernen
						</button>
					{/if}
				</div>
			</div>

			<button
				type="submit"
				disabled={arbeitet}
				class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 disabled:opacity-50"
			>
				{arbeitet ? 'Speichere…' : 'Speichern'}
			</button>
		</form>
	{/if}

	<!-- Auflösen -->
	{#if offen === 'loeschen'}
		<div class="bg-red-950/30 rounded-lg p-5 border border-red-800/60 mb-6 space-y-3">
			<h3 class="font-heading text-red-300 text-lg">Haus auflösen</h3>
			{#if umfang === null}
				<p class="text-academy-steel text-sm">Prüfe, was daran hängt…</p>
			{:else}
				<p class="text-academy-parchment text-sm">Mit dem Haus verschwindet unwiderruflich:</p>
				<ul class="text-sm text-academy-steel list-disc list-inside">
					<li>{umfang.schueler} aufgenommene Schüler*innen samt Punkteständen</li>
					<li>{umfang.heldentaten} Heldentaten samt aller Bilder</li>
					<li>{umfang.buchungen} Punktebuchungen</li>
					<li>die Chronik dieses Hauses</li>
				</ul>
				<p class="text-sm text-academy-parchment">
					Tippe zum Bestätigen den Hausnamen: <span class="font-bold">{haus.hausname}</span>
				</p>
				<input
					type="text"
					bind:value={loeschBestaetigung}
					class="{eingabeKlasse} max-w-sm"
					placeholder={haus.hausname}
				/>
				<div class="flex gap-3">
					<button
						type="button"
						onclick={hausLoeschen}
						disabled={arbeitet || loeschBestaetigung.trim() !== haus.hausname}
						class="px-4 py-2 rounded bg-red-800 text-white font-bold text-sm hover:bg-red-700 disabled:opacity-40 disabled:cursor-not-allowed"
					>
						{arbeitet ? 'Löse auf…' : 'Endgültig auflösen'}
					</button>
					<button
						type="button"
						onclick={() => (offen = '')}
						class="px-4 py-2 rounded border border-academy-steel/50 text-academy-steel text-sm hover:bg-academy-steel/20"
					>
						Abbrechen
					</button>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Heldentaten -->
	<section class="mb-8">
		<h3 class="text-xl font-heading text-academy-gold mb-3">⚔️ Heldentaten</h3>
		{#if heldentaten.length === 0}
			<p
				class="text-academy-steel text-sm bg-academy-surface rounded-lg p-5 border border-academy-blue/20"
			>
				Noch nichts festgehalten. Der erste Eintrag lohnt sich – Kinder lesen so etwas erstaunlich
				oft nach.
			</p>
		{:else}
			<div class="space-y-4">
				{#each heldentaten as h}
					<article class="bg-academy-surface rounded-lg p-5 border border-academy-blue/30">
						<div class="flex items-start justify-between gap-4">
							<div>
								<h4 class="font-heading text-academy-parchment font-bold">{h.titel}</h4>
								<p class="text-xs text-academy-steel">
									{datum(h.geschehen_am)}
									· {h.schueler?.akademiename ?? 'das ganze Haus'}
								</p>
							</div>
							<button
								type="button"
								onclick={() => heldentatLoeschen(h)}
								disabled={arbeitet}
								class="text-xs px-2 py-1 rounded border border-academy-steel/40 text-academy-steel hover:bg-academy-steel/20 shrink-0"
							>
								Löschen
							</button>
						</div>
						{#if h.beschreibung}
							<p class="text-sm text-academy-steel mt-2">{h.beschreibung}</p>
						{/if}
						{#if h.bilder?.length}
							<div class="flex gap-2 mt-3 flex-wrap">
								{#each h.bilder as pfad}
									{#if links[pfad]}
										<a href={links[pfad]} target="_blank" rel="noopener noreferrer">
											<img
												src={links[pfad]}
												alt={h.titel}
												class="w-28 h-28 object-cover rounded border border-academy-blue/40 hover:border-academy-gold/60 transition-colors"
											/>
										</a>
									{:else}
										<div
											class="w-28 h-28 rounded border border-academy-blue/20 flex items-center justify-center text-xs text-academy-steel"
										>
											Bild nicht ladbar
										</div>
									{/if}
								{/each}
							</div>
						{/if}
					</article>
				{/each}
			</div>
		{/if}
	</section>

	<!-- Mitglieder -->
	<section class="mb-8">
		<h3 class="text-xl font-heading text-academy-gold mb-3">🎓 Mitglieder des Hauses</h3>
		{#if schueler.length === 0}
			<p class="text-academy-steel text-sm">Noch niemand aufgenommen.</p>
		{:else}
			<div class="space-y-2">
				{#each schueler as s}
					<div class="rounded bg-academy-surface border border-academy-blue/20 overflow-hidden">
						<div class="flex items-center justify-between p-3 gap-3 flex-wrap">
							<div class="min-w-0">
								<span class="text-academy-parchment font-bold">{s.akademiename}</span>
								<span class="text-xs text-academy-steel ml-2">Stufe {s.level}</span>
								{#if s.login_name}
									<span
										class="text-xs ml-2 px-2 py-0.5 rounded-full border border-academy-cyan/40 text-academy-cyan"
										title="Dieses Kind hat einen eigenen Zugang"
									>
										🔑 {s.login_name}
									</span>
								{/if}
								{#if klarnamen[s.id]}
									<div class="text-xs text-academy-steel mt-0.5">
										{klarnamen[s.id]}
										<span class="opacity-70">· nur für dich sichtbar</span>
									</div>
								{/if}
							</div>
							<div class="flex items-center gap-3 shrink-0">
								<span class="text-sm text-academy-cyan">{s.xp} XP</span>
								<span class="text-sm text-academy-gold font-bold">{s.punkte} Punkte</span>
								<button
									type="button"
									onclick={() => zugangOeffnen(s)}
									class="text-xs px-2 py-1 rounded border border-academy-blue/50 text-academy-parchment hover:bg-academy-blue/30"
								>
									{s.login_name ? 'Zugang' : 'Zugang einrichten'}
								</button>
								<button
									type="button"
									onclick={() => entlassen(s)}
									class="text-xs px-2 py-1 rounded border border-academy-steel/40 text-academy-steel hover:bg-academy-steel/20"
								>
									Entfernen
								</button>
							</div>
						</div>

						{#if zugangFuer === s.id}
							<div class="border-t border-academy-blue/20 p-4 bg-academy-bg/40 space-y-3">
								<div class="grid grid-cols-1 md:grid-cols-2 gap-3">
									<div>
										<label for="klar-{s.id}" class="block text-xs text-academy-parchment mb-1">
											Klarname (bleibt für alle anderen unsichtbar)
										</label>
										<input
											id="klar-{s.id}"
											type="text"
											bind:value={zKlarname}
											class={eingabeKlasse}
											placeholder="Vor- und Nachname"
										/>
									</div>
									<div>
										<label for="login-{s.id}" class="block text-xs text-academy-parchment mb-1">
											Loginname
										</label>
										<input
											id="login-{s.id}"
											type="text"
											bind:value={zLogin}
											disabled={!!s.login_name}
											class="{eingabeKlasse} disabled:opacity-50"
											autocapitalize="none"
											spellcheck="false"
										/>
									</div>
								</div>

								{#if !s.login_name}
									<div>
										<label for="pw-{s.id}" class="block text-xs text-academy-parchment mb-1">
											Passwort
										</label>
										<div class="flex gap-2">
											<input
												id="pw-{s.id}"
												type="text"
												bind:value={zPasswort}
												class={eingabeKlasse}
											/>
											<button
												type="button"
												onclick={() => (zPasswort = passwortVorschlag())}
												class="text-xs px-3 rounded border border-academy-blue/50 text-academy-parchment shrink-0"
											>
												Neu würfeln
											</button>
										</div>
										<p class="text-xs text-academy-steel mt-1">
											Bewusst zum Vorlesen gemacht. Notiere es, bevor du speicherst — danach ist es
											nicht mehr einsehbar.
										</p>
									</div>
								{/if}

								{#if zHinweis}
									<div
										class="bg-academy-green/25 border border-academy-green text-academy-parchment p-3 rounded text-sm"
									>
										{zHinweis}
									</div>
								{/if}
								{#if zFehler}
									<div
										class="bg-red-900/30 border border-red-700/50 text-red-200 p-3 rounded text-sm"
									>
										{zFehler}
									</div>
								{/if}

								<div class="flex gap-2 flex-wrap">
									<button
										type="button"
										onclick={() => zugangSpeichern(s)}
										disabled={arbeitet}
										class="px-3 py-1.5 text-sm rounded bg-academy-cyan text-white font-bold disabled:opacity-50"
									>
										{s.login_name ? 'Klarname speichern' : 'Zugang anlegen'}
									</button>
									{#if s.login_name}
										<button
											type="button"
											onclick={() => passwortNeu(s)}
											disabled={arbeitet}
											class="px-3 py-1.5 text-sm rounded border border-academy-gold/60 text-academy-gold disabled:opacity-50"
										>
											Neues Passwort
										</button>
										<button
											type="button"
											onclick={() => zugangWeg(s)}
											disabled={arbeitet}
											class="px-3 py-1.5 text-sm rounded border border-red-800/60 text-red-300 disabled:opacity-50"
										>
											Zugang entziehen
										</button>
									{/if}
								</div>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</section>

	<!-- Buchungen -->
	<section class="mb-8">
		<h3 class="text-xl font-heading text-academy-gold mb-3">📜 Letzte Punktebuchungen</h3>
		{#if buchungen.length === 0}
			<p class="text-academy-steel text-sm">Noch keine Buchungen.</p>
		{:else}
			<div class="space-y-2">
				{#each buchungen as b}
					<div
						class="flex items-center justify-between p-3 rounded bg-academy-surface border border-academy-blue/20 text-sm"
					>
						<div>
							<span class="text-academy-parchment">{b.schueler?.akademiename ?? '—'}</span>
							<span class="text-academy-steel"> · {katLabel(b.kategorie)} · {b.grund}</span>
						</div>
						<div class="flex items-center gap-4 shrink-0">
							<span class="text-xs text-academy-steel">{datumZeit(b.created_at)}</span>
							<span
								class={b.betrag >= 0 ? 'text-academy-gold font-bold' : 'text-red-400 font-bold'}
							>
								{b.betrag >= 0 ? '+' : ''}{b.betrag}
							</span>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</section>

	<!-- Chronik -->
	{#if chronik.length > 0}
		<section class="mb-8">
			<h3 class="text-xl font-heading text-academy-gold mb-3">🕮 Chronik</h3>
			<div class="space-y-2">
				{#each chronik as c}
					<div class="p-3 rounded bg-academy-surface border border-academy-blue/20 text-sm">
						<div class="text-academy-parchment">{c.titel}</div>
						{#if c.beschreibung}
							<div class="text-academy-steel text-xs">{c.beschreibung}</div>
						{/if}
						<div class="text-academy-steel text-xs mt-1">{datumZeit(c.created_at)}</div>
					</div>
				{/each}
			</div>
		</section>
	{/if}
{/if}
