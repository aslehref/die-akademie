<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { supabase, getCurrentUser } from '$lib/supabase.js';

	let bereiche = $state<any[]>([]);
	let chronik = $state<any[]>([]);
	let schuelerInfo = $state<any>(null);
	let kapitel = $state<any[]>([]);
	let aktuellesKapitel = $state<any>(null);
	let loading = $state(true);

	onMount(async () => {
		loading = true;
		const user = await getCurrentUser();
		const [bResult, cResult, sResult, kResult] = await Promise.all([
			supabase.from('bereiche').select('*').order('typ').order('name'),
			supabase
				.from('chronik')
				.select('*, haus:haus_id(hausname)')
				.order('created_at', { ascending: false })
				.limit(10),
			user
				? supabase.from('schueler').select('*, haus:haus_id(*)').eq('user_id', user.id).single()
				: Promise.resolve({ data: null, error: null }),
			supabase.from('kapitel').select('*').order('nummer')
		]);
		bereiche = bResult.data ?? [];
		chronik = cResult.data ?? [];
		if (!sResult.error) schuelerInfo = sResult.data;
		kapitel = kResult.data ?? [];
		// Determine current chapter based on today
		const heute = new Date();
		aktuellesKapitel =
			kapitel.find((k) => {
				const start = new Date(k.startdatum);
				const end = k.enddatum ? new Date(k.enddatum) : null;
				return heute >= start && (!end || heute <= end);
			}) || null;
		loading = false;
	});
</script>

<svelte:head>
	<title>Dashboard · Die Akademie</title>
</svelte:head>

<div class="max-w-4xl mx-auto">
	<div class="flex items-start justify-between mb-8">
		<h1 class="text-3xl font-heading text-academy-gold">🏠 Dashboard</h1>
		{#if schuelerInfo}
			<div class="flex items-center gap-3 text-right">
				<div>
					<div class="font-bold text-academy-parchment">{schuelerInfo.akademiename}</div>
					<div class="text-xs text-academy-steel">
						{schuelerInfo.haus?.hausname ?? '—'}
					</div>
				</div>
				<div
					class="bg-academy-surface rounded-lg px-3 py-2 border border-academy-blue/30 text-center"
				>
					<div class="text-academy-gold font-bold">{schuelerInfo.punkte}</div>
					<div class="text-xs text-academy-steel">🪙 Punkte</div>
				</div>
				<div class="text-center">
					<div class="text-academy-cyan font-bold">⭐ {schuelerInfo.level}</div>
					<div class="text-xs text-academy-steel">{schuelerInfo.xp} XP</div>
				</div>
			</div>
		{/if}
	</div>

	{#if loading}
		<div class="text-academy-steel text-center py-12">Lade Dashboard…</div>
	{:else}
		<!-- Aktuelles Kapitel -->
		<section class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30 mb-6">
			<h2 class="text-xl font-heading text-academy-gold mb-4">📖 Aktuelles Kapitel</h2>
			{#if aktuellesKapitel}
				<div class="space-y-3">
					<div class="font-bold text-academy-parchment">{aktuellesKapitel.name}</div>
					<p class="text-academy-steel">{aktuellesKapitel.beschreibung}</p>
					<div class="flex items-center gap-3 text-sm">
						<span class="text-academy-cyan">Kapitel {aktuellesKapitel.nummer}</span>
						<span class="text-academy-steel"
							>· {#if aktuellesKapitel.freigeschaltet}🔓 freigeschaltet{:else}🔒 noch nicht{/if}</span
						>
					</div>
				</div>
			{:else}
				<p class="text-academy-steel">Kein aktuelles Kapitel gefunden.</p>
			{/if}
		</section>

		<!-- Meine Fächer / Klassenstufen -->
		<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
			<section class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
				<h2 class="text-xl font-heading text-academy-gold mb-4">📚 Bereiche</h2>
				{#if bereiche.length === 0}
					<p class="text-academy-steel text-sm">Noch keine Bereiche vorhanden.</p>
				{:else}
					<div class="space-y-2">
						{#each bereiche as b}
							<a
								href="{base}/admin/bereiche/{b.slug}"
								class="flex items-center gap-3 p-3 rounded bg-academy-bg/50 border border-academy-blue/20 hover:border-academy-gold/50 transition-colors"
							>
								<span class="text-xl">{b.typ === 'fach' ? '📖' : '🎓'}</span>
								<div>
									<div class="font-bold text-academy-parchment">{b.name}</div>
									<div class="text-xs text-academy-steel">
										{b.typ === 'fach' ? 'Fach' : 'Klassenstufe'}
									</div>
								</div>
							</a>
						{/each}
					</div>
				{/if}
			</section>

			<!-- Schüler-Profil (falls eingeloggt) -->
			{#if schuelerInfo}
				<section class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
					<h2 class="text-xl font-heading text-academy-gold mb-4">🧙 Mein Profil</h2>
					<div class="space-y-2">
						<div class="flex justify-between p-2 rounded bg-academy-bg/50">
							<span class="text-academy-steel">Akademiename</span>
							<span class="text-academy-parchment font-bold">{schuelerInfo.akademiename}</span>
						</div>
						<div class="flex justify-between p-2 rounded bg-academy-bg/50">
							<span class="text-academy-steel">Haus</span>
							<span class="text-academy-parchment">{schuelerInfo.haus?.hausname ?? '—'}</span>
						</div>
						<div class="flex justify-between p-2 rounded bg-academy-bg/50">
							<span class="text-academy-steel">Level</span>
							<span class="text-academy-cyan font-bold">{schuelerInfo.level}</span>
						</div>
						<div class="flex justify-between p-2 rounded bg-academy-bg/50">
							<span class="text-academy-steel">XP</span>
							<span class="text-academy-cyan">{schuelerInfo.xp}</span>
						</div>
						<div class="flex justify-between p-2 rounded bg-academy-bg/50">
							<span class="text-academy-steel">Punkte</span>
							<span class="text-academy-gold font-bold">{schuelerInfo.punkte}</span>
						</div>
						{#if schuelerInfo.motto}
							<div class="flex justify-between p-2 rounded bg-academy-bg/50">
								<span class="text-academy-steel">Motto</span>
								<span class="text-academy-parchment italic">„{schuelerInfo.motto}“</span>
							</div>
						{/if}
					</div>
				</section>
			{/if}
		</div>

		<!-- Letzte Aktivitäten -->
		<section class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
			<h2 class="text-xl font-heading text-academy-gold mb-4">📜 Letzte Aktivitäten</h2>
			{#if chronik.length === 0}
				<p class="text-academy-steel text-sm">Noch keine Aktivitäten.</p>
			{:else}
				<div class="space-y-2 text-sm">
					{#each chronik as eintrag}
						<div
							class="flex items-start justify-between p-2 border-b border-academy-blue/10 last:border-b-0"
						>
							<div>
								<span class="text-academy-parchment">{eintrag.titel}</span>
								{#if eintrag.haus}
									<span class="text-academy-steel text-xs ml-1">· {eintrag.haus.hausname}</span>
								{/if}
							</div>
							<div class="flex items-center gap-2 whitespace-nowrap">
								<span class="text-xs text-academy-steel">
									{new Date(eintrag.created_at).toLocaleDateString('de-DE', {
										day: '2-digit',
										month: '2-digit'
									})}
								</span>
								{#if eintrag.typ === 'quest'}
									<span class="text-academy-cyan text-xs">⚔️</span>
								{:else if eintrag.typ === 'abzeichen'}
									<span class="text-academy-gold text-xs">🏅</span>
								{:else if eintrag.typ === 'transaktion'}
									<span class="text-academy-cyan text-xs">🪙</span>
								{/if}
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Schnellzugriff -->
		<section class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
			<a
				href="{base}/dashboard/markt"
				class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors block text-center"
			>
				<div class="text-4xl mb-2">🛒</div>
				<h3 class="font-heading text-academy-gold">Punkteladen</h3>
				<p class="text-academy-steel text-sm">Punkte einlösen</p>
			</a>
			<a
				href="{base}/admin"
				class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors block text-center"
			>
				<div class="text-4xl mb-2">⚙️</div>
				<h3 class="font-heading text-academy-gold">Administration</h3>
				<p class="text-academy-steel text-sm">Bereiche verwalten</p>
			</a>
		</section>
	{/if}
</div>
