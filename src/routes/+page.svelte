<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { supabase, getStundenglaeser, getWochenquest } from '$lib/supabase.js';
	import type { Stundenglas as Glas } from '$lib/supabase.js';

	// Die Startseite ist die Eingangshalle. Sie funktioniert ohne
	// Anmeldung: hier wählt man seine Fakultät, hier hängt die
	// Wochenquest aus, hier steht der Hauspokal.

	let bereiche = $state<any[]>([]);
	let glaeser = $state<Glas[]>([]);
	let wochenquest = $state<any>(null);
	let karteOrte = $state<any[]>([]);
	let loading = $state(true);
	let ladeFehler = $state('');

	const currentYear = '2026 / 27';

	const spitze = $derived(Math.max(0, ...glaeser.map((g) => g.gesammelt ?? 0)));
	const pokal = $derived([...glaeser].sort((a, b) => b.gesammelt - a.gesammelt).slice(0, 10));

	// Wie viele Häuser hängen an welcher Fakultät
	const haeuserJeBereich = $derived.by(() => {
		const m: Record<string, { anzahl: number; punkte: number }> = {};
		for (const g of glaeser) {
			const e = (m[g.bereich_id] ??= { anzahl: 0, punkte: 0 });
			e.anzahl += 1;
			e.punkte += g.gesammelt ?? 0;
		}
		return m;
	});

	const TYP_ZEICHEN: Record<string, string> = {
		fach: '📖',
		klassenstufe: '🎓',
		allgemein: '✦'
	};

	function titelVon(b: any) {
		return b?.titel?.trim() || b?.name || 'Fakultät';
	}

	function untertitelVon(b: any) {
		const t = b?.titel?.trim();
		return t && t !== b.name ? b.name : '';
	}

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
			const [bErgebnis, gErgebnis, qErgebnis, kErgebnis] = await Promise.all([
				supabase.from('bereiche').select('*'),
				getStundenglaeser(null),
				getWochenquest(null),
				supabase.from('karte_orte').select('*').order('freischaltung_monat')
			]);

			if (bErgebnis.error) throw bErgebnis.error;
			if (gErgebnis.error) throw gErgebnis.error;

			bereiche = (bErgebnis.data ?? []).sort((a, b) =>
				titelVon(a).localeCompare(titelVon(b), 'de')
			);
			glaeser = (gErgebnis.data ?? []) as Glas[];
			wochenquest = qErgebnis.data;
			// Die Karte ist nur für Angemeldete lesbar. Fehlt sie, ist das
			// kein Fehler – dann bleibt der Abschnitt einfach leer.
			karteOrte = kErgebnis.error ? [] : (kErgebnis.data ?? []);
		} catch (e: any) {
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
		<!-- Die Fakultäten: der eigentliche Eingang -->
		<section class="mb-12">
			<h2 class="text-2xl font-heading text-academy-gold mb-1">Die Fakultäten</h2>
			<p class="text-sm text-academy-steel mb-5">Wähle deinen Kurs.</p>

			{#if bereiche.length === 0}
				<div
					class="text-center py-10 text-academy-steel bg-academy-surface rounded-lg border border-academy-blue/30"
				>
					<div class="text-4xl mb-3">✦</div>
					<p>Noch keine Fakultät gegründet.</p>
					<p class="text-sm mt-1">
						Im <a href="{base}/admin/bereiche">Lehrerzimmer</a> lässt sich die erste anlegen.
					</p>
				</div>
			{:else}
				<div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
					{#each bereiche as b (b.id)}
						{@const stand = haeuserJeBereich[b.id] ?? { anzahl: 0, punkte: 0 }}
						<a
							href="{base}/fakultaet/{b.slug}"
							class="group relative overflow-hidden bg-academy-surface rounded-lg p-5 border transition-all hover:shadow-[0_0_28px_-8px_rgba(212,167,74,0.45)]"
							style="border-color: {(b.farbe_sekundär || '#d4a74a') +
								'40'}; border-left: 4px solid {b.farbe_primär || '#24406a'}"
						>
							<div
								class="absolute -top-16 -right-10 w-40 h-40 rounded-full blur-2xl opacity-[0.13] transition-opacity group-hover:opacity-25"
								style="background: {b.farbe_primär || '#24406a'}"
								aria-hidden="true"
							></div>
							<div class="relative">
								<div class="text-2xl mb-2" aria-hidden="true">
									{TYP_ZEICHEN[b.typ] ?? '✦'}
								</div>
								<h3
									class="font-heading text-xl leading-tight"
									style="color: {b.farbe_sekundär || '#d4a74a'}"
								>
									{titelVon(b)}
								</h3>
								{#if untertitelVon(b)}
									<p class="text-xs text-academy-steel tracking-[0.15em] uppercase mt-1">
										{untertitelVon(b)}
									</p>
								{/if}
								{#if b.motto}
									<p class="text-sm text-academy-steel italic mt-2">„{b.motto}“</p>
								{/if}
								<div class="mt-4 flex items-center gap-4 text-xs text-academy-steel">
									<span>
										{stand.anzahl}
										{stand.anzahl === 1 ? 'Haus' : 'Häuser'}
									</span>
									{#if stand.punkte > 0}
										<span class="text-academy-gold font-bold">
											{stand.punkte.toLocaleString('de-DE')} Punkte
										</span>
									{/if}
								</div>
							</div>
						</a>
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
				<p class="text-academy-steel mb-3 whitespace-pre-line">{wochenquest.beschreibung}</p>
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

		<!-- Hauspokal -->
		<section class="mb-10 bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
			<h2 class="text-2xl font-heading text-academy-gold mb-4">🏆 Der große Hauspokal</h2>
			{#if pokal.length === 0}
				<p class="text-academy-steel text-center py-4">
					Noch steht kein Haus im Wettstreit. Sobald das erste gegründet ist, erscheint es hier.
				</p>
			{:else}
				<div class="space-y-3">
					{#each pokal as haus, i (haus.haus_id)}
						{@const anteil = spitze > 0 ? Math.max(3, ((haus.gesammelt ?? 0) / spitze) * 100) : 3}
						<div
							class="relative overflow-hidden rounded-lg bg-academy-bg/60 border border-academy-blue/20 {i ===
								0 && haus.gesammelt > 0
								? 'schimmert'
								: ''}"
							style="border-left: 4px solid {haus.farbe_primaer || '#24406a'}"
						>
							<!-- Der Balken zeigt den Abstand zur Spitze, nicht nur die Zahl. -->
							<div
								class="absolute inset-y-0 left-0 opacity-25"
								style="width: {anteil}%; background: linear-gradient(90deg, {haus.farbe_primaer ||
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
										{#if i === 0 && haus.gesammelt > 0}
											<div class="text-xs text-academy-gold">an der Spitze</div>
										{/if}
									</div>
								</div>
								<span class="text-academy-gold font-bold font-heading shrink-0">
									{haus.gesammelt?.toLocaleString('de-DE') ?? 0}
								</span>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Die beiden Türen -->
		<section class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-10">
			<a
				href="{base}/login"
				class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors"
			>
				<div class="text-3xl mb-2">🪄</div>
				<h3 class="font-heading text-academy-gold font-bold">Schüler*innen</h3>
				<p class="text-sm text-academy-steel">Anmelden mit Loginname</p>
			</a>
			<a
				href="{base}/login"
				class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors"
			>
				<div class="text-3xl mb-2">🕯️</div>
				<h3 class="font-heading text-academy-gold font-bold">Lehrkräfte</h3>
				<p class="text-sm text-academy-steel">Anmelden mit E-Mail</p>
			</a>
			<a
				href="{base}/dashboard/markt"
				class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors"
			>
				<div class="text-3xl mb-2">🛒</div>
				<h3 class="font-heading text-academy-gold font-bold">Der Markt</h3>
				<p class="text-sm text-academy-steel">Punkte einlösen</p>
			</a>
		</section>

		<!-- Akademie-Karte: nur für Angemeldete gefüllt -->
		{#if karteOrte.length > 0}
			<section class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
				<h2 class="text-2xl font-heading text-academy-gold mb-4">🗺️ Akademie-Karte</h2>
				<div class="grid grid-cols-2 md:grid-cols-4 gap-3">
					{#each karteOrte as ort (ort.id)}
						{#if !istOffen(ort)}
							<div
								class="p-3 rounded bg-academy-bg/50 border text-center border-academy-blue/10 opacity-40"
							>
								<div class="text-3xl mb-2">{ort.icon}</div>
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
			</section>
		{/if}
	{/if}
</div>
