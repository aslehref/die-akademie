<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase, getCurrentUser } from '$lib/supabase.js';

	let haeuser = $state<any[]>([]);
	let schueler = $state<any[]>([]);
	let transaktionen = $state<any[]>([]);
	let quests = $state<any[]>([]);
	let loading = $state(true);
	let error = $state('');

	// Computed awards
	let hauspokal = $state<any[]>([]);
	let gemeinschaftspokal = $state<any>(null);
	let wissenspokal = $state<any>(null);
	let fortschrittspokal = $state<any>(null);
	let kreativpokal = $state<any>(null);
	let questpokal = $state<any>(null);
	let demokratiepokal = $state<any>(null);

	onMount(async () => {
		loading = true;
		error = '';
		try {
			// Fetch data
			const [hResult, tResult, qResult, sResult] = await Promise.all([
				supabase.from('haeuser').select('id, hausname, hauspunkte, farbe_primär, farbe_sekundär'),
				supabase.from('punkte_transaktionen').select('betrag, kategorie, schueler_id'),
				supabase.from('quests').select('status, haus_id'),
				supabase.from('schueler').select('id, haus_id, xp, level, punkte')
			]);
			if (hResult.error) throw hResult.error;
			if (tResult.error) throw tResult.error;
			if (qResult.error) throw qResult.error;
			if (sResult.error) throw sResult.error;

			haeuser = hResult.data ?? [];
			transaktionen = tResult.data ?? [];
			quests = qResult.data ?? [];
			schueler = sResult.data ?? [];

			// Build schueler -> haus_id map
			const schuelerHausMap: Record<string, string> = {};
			schueler.forEach((s) => {
				if (s.haus_id) schuelerHausMap[s.id] = s.haus_id;
			});

			// Initialize haus stats
			const hausStats: Record<string, any> = {};
			haeuser.forEach((h) => {
				hausStats[h.id] = {
					haus: h,
					punkte: h.hauspunkte,
					xp: 0,
					level: 0,
					lernen: 0,
					sozialverhalten: 0,
					selbstständigkeit: 0,
					diskussion: 0,
					demokratie: 0,
					persönliche_entwicklung: 0,
					verantwortung: 0,
					quest: 0,
					questsCompleted: 0
				};
			});

			// Aggregate transaktionen per haus
			transaktionen.forEach((t) => {
				const hausId = schuelerHausMap[t.schueler_id];
				if (hausId && hausStats[hausId]) {
					hausStats[hausId].punkte += t.betrag;
					// Assuming betrag can be negative, but we keep separate category sums?
					// We'll add to category if positive? For simplicity, we add absolute? Let's add as is.
					if (hausStats[hausId][t.kategorie] !== undefined) {
						hausStats[hausId][t.kategorie] += t.betrag;
					}
				}
			});

			// Aggregate quests completed per haus
			quests.forEach((q) => {
				if (q.status === 'abgeschlossen' && q.haus_id && hausStats[q.haus_id]) {
					hausStats[q.haus_id].questsCompleted += 1;
				}
			});

			// Compute XP and level from schueler (we already have in schueler, but we can sum per haus)
			schueler.forEach((s) => {
				const hausId = s.haus_id;
				if (hausId && hausStats[hausId]) {
					hausStats[hausId].xp += s.xp;
					hausStats[hausId].level += s.level; // sum of levels, not average
				}
			});

			// Convert to array and compute averages for level
			const hausArray = Object.values(hausStats);
			hausArray.forEach((hs) => {
				const schuelerCount = schueler.filter((s) => s.haus_id === hs.haus.id).length;
				if (schuelerCount > 0) {
					hs.avgLevel = hs.level / schuelerCount;
				} else {
					hs.avgLevel = 0;
				}
			});

			// Hauspokal: top 3 by hauspunkte
			hauspokal = [...hausArray]
				.sort((a, b) => b.punkte - a.punkte)
				.slice(0, 3)
				.map((hs) => hs.haus);

			// Gemeinschaftspokal: highest sum of sozialverhalten + verantwortung
			gemeinschaftspokal = hausArray.reduce((best, hs) => {
				const score = (hs.sozialverhalten || 0) + (hs.verantwortung || 0);
				const bestScore = (best?.sozialverhalten || 0) + (best?.verantwortung || 0);
				return score > bestScore ? hs : best;
			}, null as any)?.haus;

			// Wissenspokal: highest lernen
			wissenspokal = hausArray.reduce((best, hs) => {
				return (hs.lernen || 0) > (best?.lernen || 0) ? hs : best;
			}, null as any)?.haus;

			// Fortschrittspokal: highest average level
			fortschrittspokal = hausArray.reduce((best, hs) => {
				return (hs.avgLevel || 0) > (best?.avgLevel || 0) ? hs : best;
			}, null as any)?.haus;

			// Kreativpokal: placeholder - we'll use highest questsCompleted for now
			kreativpokal = hausArray.reduce((best, hs) => {
				return (hs.questsCompleted || 0) > (best?.questsCompleted || 0) ? hs : best;
			}, null as any)?.haus;

			// Questpokal: most completed quests
			questpokal = hausArray.reduce((best, hs) => {
				return (hs.questsCompleted || 0) > (best?.questsCompleted || 0) ? hs : best;
			}, null as any)?.haus;

			// Demokratiepokal: highest demokratie
			demokratiepokal = hausArray.reduce((best, hs) => {
				return (hs.demokratie || 0) > (best?.demokratie || 0) ? hs : best;
			}, null as any)?.haus;
		} catch (err: any) {
			error = err.message || 'Unbekannter Fehler';
			console.error(err);
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Jahresfinale · Die Akademie</title>
</svelte:head>

<div class="max-w-4xl mx-auto p-6">
	<div class="flex justify-between items-center mb-6">
		<h1 class="text-3xl font-heading text-academy-gold">👑 Jahresfinale</h1>
		{#if loading}
			<span class="text-academy-steel animate-pulse">Lade Finale…</span>
		{/if}
	</div>

	{#if error}
		<div class="bg-red-900/30 border border-red-700/50 text-red-300 p-4 rounded mb-6">
			{error}
		</div>
	{/if}

	{#if !loading}
		<!-- Hauspokal -->
		<section class="mb-8 bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
			<h2 class="text-2xl font-heading text-academy-gold mb-4">🏆 Hauspokal</h2>
			{#if hauspokal.length === 0}
				<p class="text-academy-steel">Keine Daten verfügbar.</p>
			{:else}
				<div class="space-y-4">
					{#each hauspokal as haus, i}
						<div
							class="flex items-center justify-between p-4 rounded bg-academy-bg/50 border border-academy-blue/20"
							style="border-left: 4px solid {haus.farbe_primär || '#1e3a5f'}"
						>
							<div class="flex items-center gap-3">
								<span class="text-2xl">
									{#if i === 0}🥇
									{:else if i === 1}🥈
									{:else}🥉
									{/if}
								</span>
								<div>
									<div class="font-bold text-academy-parchment">{haus.hausname}</div>
									<div class="text-xs text-academy-steel">
										Hauspunkte: {haus.hauspunkte?.toLocaleString() ?? 0}
									</div>
								</div>
							</div>
							<span class="text-academy-gold font-bold text-2xl"
								>{haus.hauspunkte?.toLocaleString() ?? 0}</span
							>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Mehrere Pokale -->
		<section class="mb-8 bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
			<h2 class="text-2xl font-heading text-academy-gold mb-4">🏅 Mehrere Pokale</h2>
			<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
				{#if gemeinschaftspokal}
					<div
						class="bg-academy-surface rounded-lg p-4 border border-academy-cyan/30 hover:border-academy-cyan/50 transition-colors"
					>
						<h3 class="font-heading text-academy-cyan">🤝 Gemeinschaftspokal</h3>
						<p class="text-academy-steel">{gemeinschaftspokal.hausname}</p>
						<p class="text-xs text-academy-steel">Für höchste soziale Werte und Verantwortung</p>
					</div>
				{/if}
				{#if wissenspokal}
					<div
						class="bg-academy-surface rounded-lg p-4 border border-academy-cyan/30 hover:border-academy-cyan/50 transition-colors"
					>
						<h3 class="font-heading text-academy-cyan">🧠 Wissenspokal</h3>
						<p class="text-academy-steel">{wissenspokal.hausname}</p>
						<p class="text-xs text-academy-steel">Für höchste Lernleistung</p>
					</div>
				{/if}
				{#if fortschrittspokal}
					<div
						class="bg-academy-surface rounded-lg p-4 border border-academy-cyan/30 hover:border-academy-cyan/50 transition-colors"
					>
						<h3 class="font-heading text-academy-cyan">🌱 Fortschrittspokal</h3>
						<p class="text-academy-steel">{fortschrittspokal.hausname}</p>
						<p class="text-xs text-academy-steel">Für höchsten durchschnittlichen Level</p>
					</div>
				{/if}
				{#if kreativpokal}
					<div
						class="bg-academy-surface rounded-lg p-4 border border-academy-cyan/30 hover:border-academy-cyan/50 transition-colors"
					>
						<h3 class="font-heading text-academy-cyan">🎨 Kreativpokal</h3>
						<p class="text-academy-steel">{kreativpokal.hausname}</p>
						<p class="text-xs text-academy-steel">Für kreative Leistungen</p>
					</div>
				{/if}
				{#if questpokal}
					<div
						class="bg-academy-surface rounded-lg p-4 border border-academy-cyan/30 hover:border-academy-cyan/50 transition-colors"
					>
						<h3 class="font-heading text-academy-cyan">⚔️ Questpokal</h3>
						<p class="text-academy-steel">{questpokal.hausname}</p>
						<p class="text-xs text-academy-steel">Für meisten abgeschlossene Quests</p>
					</div>
				{/if}
				{#if demokratiepokal}
					<div
						class="bg-academy-surface rounded-lg p-4 border border-academy-cyan/30 hover:border-academy-cyan/50 transition-colors"
					>
						<h3 class="font-heading text-academy-cyan">🏛️ Demokratiepokal</h3>
						<p class="text-academy-steel">{demokratiepokal.hausname}</p>
						<p class="text-xs text-academy-steel">Für demokratisches Engagement</p>
					</div>
				{/if}
			</div>
		</section>

		<!-- Persönliche Auszeichnungen (für den aktuellen Schüler) -->
		<section class="mb-8 bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
			<h2 class="text-2xl font-heading text-academy-gold mb-4">🎖️ Persönliche Auszeichnungen</h2>
			{#await getCurrentUser() then user}
				{#if user}
					{#await supabase
						.from('schueler')
						.select('*, haus:haus_id(*)')
						.eq('user_id', user.id)
						.single() then schuelerData}
						{#if !schuelerData.error && schuelerData.data}
							{@const s = schuelerData.data}
							<div class="space-y-3">
								<div class="flex justify-between p-3 rounded bg-academy-bg/50">
									<span class="text-academy-steel">Akademiename</span>
									<span class="text-academy-parchment font-bold">{s.akademiename}</span>
								</div>
								<div class="flex justify-between p-3 rounded bg-academy-bg/50">
									<span class="text-academy-steel">Haus</span>
									<span class="text-academy-parchment">{s.haus?.hausname ?? '—'}</span>
								</div>
								<div class="flex justify-between p-3 rounded bg-academy-bg/50">
									<span class="text-academy-steel">Level</span>
									<span class="text-academy-cyan font-bold">{s.level}</span>
								</div>
								<div class="flex justify-between p-3 rounded bg-academy-bg/50">
									<span class="text-academy-steel">XP</span>
									<span class="text-academy-cyan">{s.xp}</span>
								</div>
								<div class="flex justify-between p-3 rounded bg-academy-bg/50">
									<span class="text-academy-steel">Punkte</span>
									<span class="text-academy-gold font-bold">{s.punkte}</span>
								</div>
								{#if s.motto}
									<div class="flex justify-between p-3 rounded bg-academy-bg/50">
										<span class="text-academy-steel">Motto</span>
										<span class="text-academy-parchment italic">„{s.motto}“</span>
									</div>
								{/if}
							</div>
							<div class="mt-4 pt-3 border-t border-academy-blue/20">
								<h3 class="font-heading text-academy-gold">Auszeichnungen</h3>
								<div class="space-y-2">
									{#if s.level >= 10}
										<div class="flex items-start gap-3 p-3 rounded bg-academy-cyan/20">
											<div class="text-2xl text-academy-cyan">🏅</div>
											<div>
												<div class="font-bold text-academy-parchment">Level-Meister</div>
												<div class="text-academy-steel text-xs">
													Für das Erreichen von Level 10 oder höher
												</div>
											</div>
										</div>
									{/if}
									{#if s.punkte >= 1000}
										<div class="flex items-start gap-3 p-3 rounded bg-academy-cyan/20">
											<div class="text-2xl text-academy-cyan">🪙</div>
											<div>
												<div class="font-bold text-academy-parchment">Punkte-Legende</div>
												<div class="text-academy-steel text-xs">
													Für die Ansammlung von 1000+ Punkten
												</div>
											</div>
										</div>
									{/if}
									{#if s.xp >= 500}
										<div class="flex items-start gap-3 p-3 rounded bg-academy-cyan/20">
											<div class="text-2xl text-academy-cyan">⭐</div>
											<div>
												<div class="font-bold text-academy-parchment">XP-Held</div>
												<div class="text-academy-steel text-xs">Für die Ansammlung von 500+ XP</div>
											</div>
										</div>
									{/if}
								</div>
							</div>
						{/if}
					{/await}
				{/if}
			{/await}
		</section>
	{/if}
</div>
