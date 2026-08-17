<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { supabase } from '$lib/supabase.js';

	let haeuser = $state<any[]>([]);
	let wochenquest = $state<any>(null);
	let karteOrte = $state<any[]>([]);
	let loading = $state(true);
	let ladeFehler = $state('');

	const currentYear = '2026 / 27';

	// Das Schuljahr laeuft von September bis August und damit ueber den
	// Jahreswechsel. Ein reiner Vergleich der Kalendermonate ist deshalb
	// falsch: Januar (1) ist im Schuljahr SPAETER als September (9).
	const SCHULJAHR_START = 9;

	function schuljahrPosition(monat: number) {
		return monat >= SCHULJAHR_START
			? monat - SCHULJAHR_START + 1
			: monat + (12 - SCHULJAHR_START) + 1;
	}

	// Diese Seiten gibt es schon. Alle anderen Orte der Karte sind zwar in
	// der Datenbank angelegt, aber noch nicht gebaut – sie als Link
	// anzubieten würde nur in eine Fehlerseite führen.
	const GEBAUTE_SEITEN = ['/dashboard', '/dashboard/markt', '/dashboard/finale'];

	function istGebaut(route: string | null) {
		return GEBAUTE_SEITEN.includes(route ?? '');
	}

	function istOffen(ort: { freigeschaltet?: boolean; freischaltung_monat: number }) {
		if (ort.freigeschaltet) return true;
		return (
			schuljahrPosition(new Date().getMonth() + 1) >= schuljahrPosition(ort.freischaltung_monat)
		);
	}

	onMount(async () => {
		loading = true;
		ladeFehler = '';
		try {
			const [hResult, qResult, kResult] = await Promise.all([
				supabase
					.from('haeuser')
					.select('hausname, hauspunkte, farbe_primär, farbe_sekundär')
					.order('hauspunkte', { ascending: false })
					.limit(10),
				supabase
					.from('quests')
					.select('*')
					.eq('status', 'aktiv')
					.order('startdatum', { ascending: false })
					.limit(1)
					.single(),
				supabase.from('karte_orte').select('*').order('freischaltung_monat')
			]);
			// Eine fehlende Wochenquest ist kein Fehler, die anderen beiden schon.
			if (hResult.error) throw hResult.error;
			if (kResult.error) throw kResult.error;

			haeuser = hResult.data ?? [];
			if (!qResult.error) wochenquest = qResult.data;
			karteOrte = kResult.data ?? [];
		} catch (e: any) {
			// Ohne diesen Zweig blieb die Seite bei nicht erreichbarer
			// Datenbank dauerhaft auf "Lade Akademie…" stehen.
			ladeFehler = e?.message ?? 'Die Akademie ist gerade nicht erreichbar.';
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Die Akademie</title>
</svelte:head>

<div class="max-w-4xl mx-auto">
	<!-- Header -->
	<div class="mb-10">
		<h1 class="text-4xl font-heading text-academy-gold mb-2">Die Akademie</h1>
		<p class="text-academy-steel text-lg">Schuljahr {currentYear}</p>
	</div>

	{#if loading}
		<div class="text-academy-steel text-center py-8">Lade Akademie…</div>
	{:else if ladeFehler}
		<div class="bg-red-900/30 border border-red-700/50 text-red-200 p-4 rounded">
			<p class="font-bold mb-1">Die Akademie ist gerade nicht erreichbar.</p>
			<p class="text-sm">{ladeFehler}</p>
			<p class="text-sm mt-2 text-academy-steel">
				Prüfe, ob VITE_SUPABASE_URL und VITE_SUPABASE_ANON_KEY gesetzt sind.
			</p>
		</div>
	{:else}
		<!-- Hauspokal -->
		<section class="mb-10 bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
			<h2 class="text-2xl font-heading text-academy-gold mb-4">🏆 Der große Hauspokal</h2>
			{#if haeuser.length === 0}
				<p class="text-academy-steel text-center py-4">Noch keine Häuser angelegt.</p>
			{:else}
				<div class="space-y-3">
					{#each haeuser as haus, i}
						<div
							class="flex items-center justify-between p-3 rounded bg-academy-bg/50 border border-academy-blue/20"
							style="border-left: 4px solid {haus.farbe_primär || '#1e3a5f'}"
						>
							<div class="flex items-center gap-3">
								<span class="text-xl">
									{#if i === 0}🥇
									{:else if i === 1}🥈
									{:else if i === 2}🥉
									{:else}{i + 1}.
									{/if}
								</span>
								<div>
									<span class="font-bold text-academy-parchment">{haus.hausname}</span>
								</div>
							</div>
							<span class="text-academy-gold font-bold"
								>{haus.hauspunkte?.toLocaleString() ?? 0} Punkte</span
							>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Wochenquest -->
		{#if wochenquest}
			<section class="mb-10 bg-academy-surface rounded-lg p-6 border border-academy-gold/30">
				<h2 class="text-2xl font-heading text-academy-gold mb-2">⚔️ Wochenquest</h2>
				<h3 class="text-lg font-bold text-academy-parchment mb-1">{wochenquest.titel}</h3>
				<p class="text-academy-steel mb-3">{wochenquest.beschreibung}</p>
				<div class="flex items-center gap-3 text-sm flex-wrap">
					<span class="text-academy-gold">{'⭐'.repeat(wochenquest.schwierigkeit)}</span>
					{#if wochenquest.belohnung_hauspunkte > 0}
						<span class="text-academy-cyan font-bold"
							>+{wochenquest.belohnung_hauspunkte} Hauspunkte</span
						>
					{/if}
					{#if wochenquest.belohnung_xp > 0}
						<span class="text-academy-cyan font-bold">+{wochenquest.belohnung_xp} XP</span>
					{/if}
				</div>
			</section>
		{/if}

		<!-- Schnellzugriff -->
		<section class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-10">
			<a
				href="{base}/dashboard"
				class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors"
			>
				<div class="text-3xl mb-2">🏠</div>
				<h3 class="font-heading text-academy-gold font-bold">Dashboard</h3>
				<p class="text-sm text-academy-steel">Meine Bereiche und Aktivitäten</p>
			</a>
			<a
				href="{base}/dashboard/markt"
				class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors"
			>
				<div class="text-3xl mb-2">🛒</div>
				<h3 class="font-heading text-academy-gold font-bold">Markt</h3>
				<p class="text-sm text-academy-steel">Punkte einlösen</p>
			</a>
			<a
				href="{base}/admin"
				class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors"
			>
				<div class="text-3xl mb-2">⚙️</div>
				<h3 class="font-heading text-academy-gold font-bold">Administration</h3>
				<p class="text-sm text-academy-steel">Bereiche, Häuser, Quests verwalten</p>
			</a>
		</section>

		<!-- Akademie-Karte -->
		<section class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
			<h2 class="text-2xl font-heading text-academy-gold mb-4">🗺️ Akademie-Karte</h2>
			{#if karteOrte.length === 0}
				<p class="text-academy-steel text-center py-4">Noch keine Orte freigeschaltet.</p>
			{:else}
				<div class="grid grid-cols-2 md:grid-cols-4 gap-3">
					{#each karteOrte as ort}
						{#if !istOffen(ort)}
							<div
								class="p-3 rounded bg-academy-bg/50 border text-center border-academy-blue/10 opacity-40"
							>
								<div class="text-2xl mb-1">{ort.icon}</div>
								<div class="text-xs font-bold text-academy-steel">{ort.name}</div>
								<div class="text-xs text-academy-steel mt-1">
									🔒 Monat {ort.freischaltung_monat}
								</div>
							</div>
						{:else if istGebaut(ort.route)}
							<a
								href="{base}{ort.route}"
								class="p-3 rounded bg-academy-bg/50 border text-center transition-colors border-academy-blue/20 hover:border-academy-gold/50"
							>
								<div class="text-2xl mb-1">{ort.icon}</div>
								<div class="text-xs font-bold text-academy-parchment">{ort.name}</div>
							</a>
						{:else}
							<div
								class="p-3 rounded bg-academy-bg/50 border text-center border-academy-blue/10 opacity-60"
								title="Diese Seite ist noch nicht gebaut."
							>
								<div class="text-2xl mb-1">{ort.icon}</div>
								<div class="text-xs font-bold text-academy-steel">{ort.name}</div>
								<div class="text-xs text-academy-steel mt-1">in Arbeit</div>
							</div>
						{/if}
					{/each}
				</div>
			{/if}
		</section>
	{/if}
</div>
