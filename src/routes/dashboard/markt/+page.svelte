<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { goto } from '$app/navigation';
	import {
		supabase,
		getCurrentUser,
		getUserRole,
		getBelohnungen,
		createEinloesung,
		getEinloesungen,
		stornoEinloesung,
		addChronik,
		type UserRole
	} from '$lib/supabase.js';

	// Kinder haben in diesem System bewusst keinen eigenen Zugang.
	// Der Markt wird deshalb von der Lehrkraft bedient: sie wählt
	// ein Kind aus und löst die Belohnung für dieses Kind ein.

	let rolle = $state<UserRole | null>(null);
	let lehrerId = $state<string | null>(null);

	let haeuser = $state<any[]>([]);
	let schuelerListe = $state<any[]>([]);
	let belohnungen = $state<any[]>([]);
	let einloesungen = $state<any[]>([]);

	let hausId = $state('');
	let schuelerId = $state('');

	let laedt = $state(true);
	let ladeFehler = $state('');
	let meldung = $state('');
	let fehler = $state('');
	let bestaetigung = $state<any>(null);
	let arbeitet = $state(false);

	const gewaehltesHaus = $derived(haeuser.find((h) => h.id === hausId) ?? null);
	const gewaehlterSchueler = $derived(schuelerListe.find((s) => s.id === schuelerId) ?? null);

	const kategorieLabel: Record<string, string> = {
		joker: '🃏 Joker',
		wahlmöglichkeit: '🎯 Wahlmöglichkeit',
		aktivität: '🎲 Aktivität',
		challenge: '⚔️ Challenge',
		legendär: '👑 Legendär'
	};

	onMount(async () => {
		try {
			const user = await getCurrentUser();
			if (!user) {
				await goto(`${base}/login`);
				return;
			}
			lehrerId = user.id;
			rolle = await getUserRole(user.id);

			const { data, error } = await supabase
				.from('haeuser')
				.select('id, hausname, name, bereich_id')
				.order('hausname');
			if (error) throw error;
			haeuser = data ?? [];
		} catch (e: any) {
			ladeFehler = e?.message ?? 'Die Daten konnten nicht geladen werden.';
		} finally {
			laedt = false;
		}
	});

	async function hausGewaehlt() {
		schuelerId = '';
		schuelerListe = [];
		belohnungen = [];
		einloesungen = [];
		fehler = '';
		meldung = '';
		if (!hausId) return;

		try {
			const [s, b] = await Promise.all([
				supabase
					.from('schueler')
					.select('id, akademiename, punkte, xp, level, haus_id')
					.eq('haus_id', hausId)
					.order('akademiename'),
				getBelohnungen(gewaehltesHaus?.bereich_id)
			]);
			if (s.error) throw s.error;
			if (b.error) throw b.error;
			schuelerListe = s.data ?? [];
			belohnungen = b.data ?? [];
		} catch (e: any) {
			fehler = e?.message ?? 'Unbekannter Fehler.';
		}
	}

	async function schuelerGewaehlt() {
		einloesungen = [];
		fehler = '';
		meldung = '';
		if (!schuelerId) return;
		const { data, error } = await getEinloesungen(schuelerId);
		if (error) fehler = error.message;
		else einloesungen = data ?? [];
	}

	async function aktualisiereSchueler() {
		const { data } = await supabase
			.from('schueler')
			.select('id, akademiename, punkte, xp, level, haus_id')
			.eq('haus_id', hausId)
			.order('akademiename');
		schuelerListe = data ?? [];
	}

	function kaufAnfragen(b: any) {
		fehler = '';
		meldung = '';
		bestaetigung = b;
	}

	async function kaufBestaetigen() {
		const b = bestaetigung;
		if (!b || !gewaehlterSchueler) return;
		arbeitet = true;
		fehler = '';
		meldung = '';

		try {
			// Das Guthaben wird zusätzlich in der Datenbank geprüft, damit ein
			// veralteter Punktestand im Browser kein Minus erzeugen kann.
			const { error } = await createEinloesung({
				schueler_id: gewaehlterSchueler.id,
				belohnung_id: b.id,
				belohnung_name: b.name,
				kosten: b.kosten,
				eingeloest_von: lehrerId
			});
			if (error) throw error;

			await addChronik({
				haus_id: gewaehlterSchueler.haus_id,
				bereich_id: gewaehltesHaus?.bereich_id,
				typ: 'belohnung',
				titel: `${gewaehlterSchueler.akademiename} hat „${b.name}“ eingelöst`,
				beschreibung: `−${b.kosten} Punkte`
			});

			bestaetigung = null;
			meldung = `„${b.name}“ für ${gewaehlterSchueler.akademiename} eingelöst.`;
			await aktualisiereSchueler();
			await schuelerGewaehlt();
		} catch (e: any) {
			fehler = e?.message ?? 'Die Einlösung ist fehlgeschlagen.';
			bestaetigung = null;
		} finally {
			arbeitet = false;
		}
	}

	async function stornieren(e: any) {
		arbeitet = true;
		fehler = '';
		meldung = '';
		try {
			const { error } = await stornoEinloesung(e.id);
			if (error) throw error;
			meldung = `„${e.belohnung_name}“ wurde storniert, die Punkte sind zurück.`;
			await aktualisiereSchueler();
			await schuelerGewaehlt();
		} catch (err: any) {
			fehler = err?.message ?? 'Das Stornieren ist fehlgeschlagen.';
		} finally {
			arbeitet = false;
		}
	}

	function datum(s: string) {
		return new Date(s).toLocaleDateString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}
</script>

<svelte:head>
	<title>Der Markt · Die Akademie</title>
</svelte:head>

<div class="max-w-4xl mx-auto">
	<h1 class="text-3xl font-heading text-academy-gold mb-2">🛒 Der Markt</h1>
	<p class="text-academy-steel mb-6">Wähle ein Haus und ein Kind, um ein Privileg einzulösen.</p>

	{#if laedt}
		<div class="text-academy-steel py-8 text-center">Lade…</div>
	{:else if ladeFehler}
		<div class="bg-red-900/30 border border-red-700/50 text-red-200 p-4 rounded">
			<p class="font-bold mb-1">Die Daten konnten nicht geladen werden.</p>
			<p class="text-sm">{ladeFehler}</p>
		</div>
	{:else if rolle !== 'admin' && rolle !== 'teacher'}
		<div class="bg-academy-surface border border-academy-blue/30 p-6 rounded text-academy-steel">
			Für den Markt brauchst du die Rolle <span class="text-academy-cyan">teacher</span>
			oder <span class="text-academy-cyan">admin</span>.
		</div>
	{:else}
		<!-- Auswahl -->
		<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
			<div>
				<label for="haus-auswahl" class="block text-sm text-academy-parchment mb-1">Haus</label>
				<select
					id="haus-auswahl"
					bind:value={hausId}
					onchange={hausGewaehlt}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				>
					<option value="">— bitte wählen —</option>
					{#each haeuser as h}
						<option value={h.id}>{h.hausname} ({h.name})</option>
					{/each}
				</select>
			</div>

			<div>
				<label for="schueler-auswahl" class="block text-sm text-academy-parchment mb-1"
					>Schüler*in</label
				>
				<select
					id="schueler-auswahl"
					bind:value={schuelerId}
					onchange={schuelerGewaehlt}
					disabled={!hausId || schuelerListe.length === 0}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none disabled:opacity-40"
				>
					<option value="">— bitte wählen —</option>
					{#each schuelerListe as s}
						<option value={s.id}>{s.akademiename} · {s.punkte} Punkte</option>
					{/each}
				</select>
			</div>
		</div>

		{#if hausId && schuelerListe.length === 0}
			<p class="text-academy-steel mb-6">In diesem Haus ist noch niemand angelegt.</p>
		{/if}

		{#if meldung}
			<div
				class="bg-academy-green/30 border border-academy-green text-academy-parchment p-3 rounded mb-4"
			>
				{meldung}
			</div>
		{/if}
		{#if fehler}
			<div class="bg-red-900/30 border border-red-700/50 text-red-200 p-3 rounded mb-4">
				{fehler}
			</div>
		{/if}

		{#if gewaehlterSchueler}
			<!-- Kontostand -->
			<div class="flex flex-wrap gap-4 mb-6">
				<div class="bg-academy-surface rounded-lg px-5 py-3 border border-academy-blue/30">
					<div class="text-2xl font-bold text-academy-gold">{gewaehlterSchueler.punkte}</div>
					<div class="text-sm text-academy-steel">Guthaben</div>
				</div>
				<div class="bg-academy-surface rounded-lg px-5 py-3 border border-academy-blue/30">
					<div class="text-2xl font-bold text-academy-cyan">{gewaehlterSchueler.xp}</div>
					<div class="text-sm text-academy-steel">Erfahrung (bleibt beim Einlösen)</div>
				</div>
				<div class="bg-academy-surface rounded-lg px-5 py-3 border border-academy-blue/30">
					<div class="text-2xl font-bold text-academy-parchment">{gewaehlterSchueler.level}</div>
					<div class="text-sm text-academy-steel">Stufe</div>
				</div>
			</div>

			<!-- Bestätigung -->
			{#if bestaetigung}
				<div class="bg-academy-surface border border-academy-gold/60 rounded-lg p-5 mb-6">
					<p class="text-academy-parchment mb-1">
						<span class="font-bold">{gewaehlterSchueler.akademiename}</span>
						löst <span class="font-bold text-academy-gold">„{bestaetigung.name}“</span>
						für {bestaetigung.kosten} Punkte ein.
					</p>
					<p class="text-sm text-academy-steel mb-4">
						Danach bleiben {gewaehlterSchueler.punkte - bestaetigung.kosten} Punkte. Erfahrung und Hauspunkte
						ändern sich nicht.
					</p>
					<div class="flex gap-3">
						<button
							type="button"
							onclick={kaufBestaetigen}
							disabled={arbeitet}
							class="px-4 py-2 rounded bg-academy-gold text-academy-bg font-bold hover:bg-academy-gold/90 disabled:opacity-50"
						>
							{arbeitet ? 'Einen Moment…' : 'Einlösen'}
						</button>
						<button
							type="button"
							onclick={() => (bestaetigung = null)}
							disabled={arbeitet}
							class="px-4 py-2 rounded border border-academy-steel/50 text-academy-steel hover:bg-academy-steel/20"
						>
							Abbrechen
						</button>
					</div>
				</div>
			{/if}

			<!-- Katalog -->
			<h2 class="text-xl font-heading text-academy-gold mb-3">Privilegien</h2>
			{#if belohnungen.length === 0}
				<div
					class="text-center py-10 text-academy-steel bg-academy-surface rounded-lg border border-academy-blue/30"
				>
					<div class="text-4xl mb-3">🛒</div>
					<p>Für dieses Haus sind noch keine Privilegien angelegt.</p>
					<a href="{base}/admin/belohnungen" class="text-sm underline">Privilegien verwalten</a>
				</div>
			{:else}
				<div class="grid gap-4 mb-8">
					{#each belohnungen as b}
						{@const bezahlbar = gewaehlterSchueler.punkte >= b.kosten}
						<button
							type="button"
							onclick={() => kaufAnfragen(b)}
							disabled={!bezahlbar || arbeitet}
							class="w-full text-left bg-academy-surface rounded-lg p-5 border transition-colors
								{bezahlbar
								? 'border-academy-blue/30 hover:border-academy-gold/60 focus:border-academy-gold cursor-pointer'
								: 'border-academy-blue/10 opacity-50 cursor-not-allowed'}"
						>
							<div class="flex items-start justify-between gap-4">
								<div class="flex-1">
									<h3 class="font-heading text-academy-gold font-bold">{b.name}</h3>
									<p class="text-academy-steel text-sm">{b.beschreibung}</p>
									<p class="text-academy-steel text-xs mt-2">
										{kategorieLabel[b.kategorie] ?? b.kategorie}
									</p>
								</div>
								<div class="text-right shrink-0">
									<div
										class="text-3xl font-bold {bezahlbar
											? 'text-academy-gold'
											: 'text-academy-steel'}"
									>
										{b.kosten}
									</div>
									<div class="text-xs text-academy-steel">Punkte</div>
									{#if !bezahlbar}
										<div class="text-xs text-academy-steel mt-1">
											fehlen {b.kosten - gewaehlterSchueler.punkte}
										</div>
									{/if}
								</div>
							</div>
						</button>
					{/each}
				</div>
			{/if}

			<!-- Verlauf -->
			{#if einloesungen.length > 0}
				<h2 class="text-xl font-heading text-academy-gold mb-3">Bisher eingelöst</h2>
				<div class="space-y-2">
					{#each einloesungen as e}
						<div
							class="flex items-center justify-between gap-3 p-3 rounded bg-academy-surface border border-academy-blue/20"
							class:opacity-50={e.storniert}
						>
							<div>
								<div class="text-academy-parchment">
									{e.belohnung_name}
									{#if e.storniert}
										<span class="text-xs text-academy-steel">(storniert)</span>
									{/if}
								</div>
								<div class="text-xs text-academy-steel">{datum(e.created_at)}</div>
							</div>
							<div class="flex items-center gap-3 shrink-0">
								<span class="text-academy-gold font-bold">−{e.kosten}</span>
								{#if !e.storniert}
									<button
										type="button"
										onclick={() => stornieren(e)}
										disabled={arbeitet}
										class="text-xs px-2 py-1 rounded border border-academy-steel/50 text-academy-steel hover:bg-academy-steel/20 disabled:opacity-50"
									>
										Stornieren
									</button>
								{/if}
							</div>
						</div>
					{/each}
				</div>
			{/if}
		{/if}
	{/if}
</div>
