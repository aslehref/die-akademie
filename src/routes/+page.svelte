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
	const spitze = $derived(Math.max(0, ...haeuser.map((h) => h.hauspunkte ?? 0)));

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
	<!-- Kopf -->
	<header class="mb-12 text-center">
		<div class="text-5xl mb-3" aria-hidden="true">✦</div>
		<h1 class="text-5xl font-heading text-academy-gold mb-3">Die Akademie</h1>
		<p class="text-academy-steel tracking-[0.3em] text-sm uppercase">
			Schuljahr {currentYear}
		</p>
		<hr class="zierlinie mt-6 max-w-sm mx-auto" />
		<p class="text-academy-steel italic mt-4 text-sm">Wissen. Gemeinschaft. Verantwortung.</p>
	</header>

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
						{@const anteil = spitze > 0 ? Math.max(3, ((haus.hauspunkte ?? 0) / spitze) * 100) : 3}
						<div
							class="relative overflow-hidden rounded-lg bg-academy-bg/60 border border-academy-blue/20 {i ===
							0
								? 'schimmert'
								: ''}"
							style="border-left: 4px solid {haus.farbe_primär || '#24406a'}"
						>
							<!-- Der Balken zeigt den Abstand zur Spitze, nicht nur die Zahl. -->
							<div
								class="absolute inset-y-0 left-0 opacity-25"
								style="width: {anteil}%; background: linear-gradient(90deg, {haus.farbe_primär ||
									'#24406a'}, transparent);"
								aria-hidden="true"
							></div>
							<div class="relative flex items-center justify-between p-4 gap-3">
								<div class="flex items-center gap-4 min-w-0">
									<span
										class="w-9 h-9 shrink-0 rounded-full flex items-center justify-center font-heading text-sm border"
										style="border-color: {['#d4a74a', '#c0c0c0', '#b87333'][i] ??
											'#3a4560'}; color: {['#f2d99b', '#e8e8e8', '#d89a6a'][i] ?? '#97a3ba'};"
									>
										{i + 1}
									</span>
									<div class="min-w-0">
										<div class="font-bold text-academy-parchment truncate">{haus.hausname}</div>
										{#if i === 0}
											<div class="text-xs text-academy-gold">an der Spitze</div>
										{/if}
									</div>
								</div>
								<span class="text-academy-gold font-bold font-heading shrink-0">
									{haus.hauspunkte?.toLocaleString('de-DE') ?? 0}
								</span>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Wochenquest -->
		{#if wochenquest}
			<section
				class="mb-10 bg-academy-surface rounded-lg p-6 border border-academy-gold/40 relative overflow-hidden"
			>
				<div
					class="absolute -top-16 -right-16 w-56 h-56 rounded-full opacity-[0.07] bg-academy-gold blur-2xl"
					aria-hidden="true"
				></div>
				<h2 class="text-2xl font-heading text-academy-gold mb-2 relative">⚔️ Wochenquest</h2>
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
				<h3 class="font-heading text-academy-gold font-bold">Große Halle</h3>
				<p class="text-sm text-academy-steel">Fakultäten, Kapitel und Chronik</p>
			</a>
			<a
				href="{base}/dashboard/markt"
				class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors"
			>
				<div class="text-3xl mb-2">🛒</div>
				<h3 class="font-heading text-academy-gold font-bold">Der Markt</h3>
				<p class="text-sm text-academy-steel">Punkte einlösen</p>
			</a>
			<a
				href="{base}/admin"
				class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors"
			>
				<div class="text-3xl mb-2">⚙️</div>
				<h3 class="font-heading text-academy-gold font-bold">Lehrerzimmer</h3>
				<p class="text-sm text-academy-steel">Fakultäten, Häuser und Orden verwalten</p>
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
								<div class="text-3xl mb-2 transition-transform group-hover:scale-110">
									{ort.icon}
								</div>
								<div class="text-xs font-bold text-academy-steel">{ort.name}</div>
								<div class="text-xs text-academy-steel mt-1">
									🔒 Monat {ort.freischaltung_monat}
								</div>
							</div>
						{:else if istGebaut(ort.route)}
							<a
								href="{base}{ort.route}"
								class="group p-4 rounded-lg bg-academy-bg/50 border text-center transition-all border-academy-blue/20 hover:border-academy-gold/60 hover:bg-academy-bg/80 hover:shadow-[0_0_24px_-6px_rgba(212,167,74,0.5)]"
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
