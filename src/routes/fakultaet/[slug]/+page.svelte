<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { supabase, getStundenglaeser, getWochenquest } from '$lib/supabase.js';
	import type { Stundenglas as Glas } from '$lib/supabase.js';
	import Stundenglas from '$lib/Stundenglas.svelte';

	// Diese Seite ist der Kursbereich und braucht KEINE Anmeldung.
	// Wer hereinschaut, soll die Stundengläser und die laufende Quest
	// sehen – das ist der Aushang, nicht die Akte.

	let bereich = $state<any>(null);
	let glaeser = $state<Glas[]>([]);
	let quest = $state<any>(null);
	let loading = $state(true);
	let fehler = $state('');

	const spitze = $derived(Math.max(0, ...glaeser.map((g) => g.gesammelt ?? 0)));
	const gesamtVerfuegbar = $derived(glaeser.reduce((s, g) => s + (g.verfuegbar ?? 0), 0));

	function titelVon(b: any) {
		return b?.titel?.trim() || b?.name || 'Fakultät';
	}

	onMount(async () => {
		loading = true;
		fehler = '';
		try {
			const slug = $page.params.slug;
			const { data: b, error: bFehler } = await supabase
				.from('bereiche')
				.select('*')
				.eq('slug', slug)
				.maybeSingle();
			if (bFehler) throw bFehler;
			bereich = b;
			if (!b) return;

			const [gErgebnis, qErgebnis] = await Promise.all([
				getStundenglaeser(b.id),
				getWochenquest(b.id)
			]);
			if (gErgebnis.error) throw gErgebnis.error;
			glaeser = (gErgebnis.data ?? []) as Glas[];
			quest = qErgebnis.data;
		} catch (e: any) {
			fehler = e?.message ?? 'Die Akademie ist gerade nicht erreichbar.';
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>{titelVon(bereich)} – Die Akademie</title>
</svelte:head>

<div class="max-w-5xl mx-auto">
	<a href="{base}/" class="text-sm text-academy-steel hover:text-academy-parchment">
		← Eingangshalle
	</a>

	{#if loading}
		<div class="text-academy-steel text-center py-16">Lade Fakultät…</div>
	{:else if fehler}
		<div class="mt-6 bg-red-900/30 border border-red-700/50 text-red-200 p-4 rounded">
			<p class="font-bold mb-1">Die Fakultät lässt sich gerade nicht öffnen.</p>
			<p class="text-sm">{fehler}</p>
		</div>
	{:else if !bereich}
		<div class="text-center py-16">
			<div class="text-4xl mb-4">🔍</div>
			<h1 class="text-2xl font-heading text-academy-gold mb-2">Diese Fakultät gibt es nicht</h1>
			<p class="text-academy-steel text-sm">
				Vielleicht wurde sie umbenannt. In der <a href="{base}/">Eingangshalle</a> stehen alle, die es
				gibt.
			</p>
		</div>
	{:else}
		<!-- Kopf -->
		<header
			class="mt-4 mb-10 text-center relative overflow-hidden rounded-lg border p-8 bg-academy-surface"
			style="border-color: {(bereich.farbe_sekundär || '#d4a74a') + '55'}"
		>
			<div
				class="absolute -top-24 left-1/2 -translate-x-1/2 w-96 h-64 rounded-full blur-3xl opacity-20"
				style="background: {bereich.farbe_primär || '#24406a'}"
				aria-hidden="true"
			></div>
			<div class="relative">
				<div class="text-3xl mb-2" aria-hidden="true">
					{bereich.typ === 'klassenstufe' ? '🎓' : bereich.typ === 'allgemein' ? '✦' : '📖'}
				</div>
				<h1 class="text-4xl font-heading mb-1" style="color: {bereich.farbe_sekundär || '#d4a74a'}">
					{titelVon(bereich)}
				</h1>
				<p class="text-academy-steel tracking-[0.25em] text-xs uppercase">
					{bereich.name}
				</p>
				{#if bereich.motto}
					<hr class="zierlinie my-4 max-w-xs mx-auto" />
					<p class="italic text-academy-steel text-sm">„{bereich.motto}“</p>
				{/if}
			</div>
		</header>

		<!-- Wochenquest: hängt öffentlich aus -->
		{#if quest}
			<section
				class="mb-10 bg-academy-surface rounded-lg p-6 border border-academy-gold/40 relative overflow-hidden"
			>
				<div
					class="absolute -top-16 -right-16 w-56 h-56 rounded-full opacity-[0.07] bg-academy-gold blur-2xl"
					aria-hidden="true"
				></div>
				<div class="relative">
					<h2 class="text-xl font-heading text-academy-gold mb-2">⚔️ Die Wochenquest</h2>
					<h3 class="text-lg font-bold text-academy-parchment mb-1">{quest.titel}</h3>
					<p class="text-academy-steel mb-3 whitespace-pre-line">{quest.beschreibung}</p>
					<div class="flex items-center gap-3 text-sm flex-wrap">
						<span class="text-academy-gold" aria-label="Schwierigkeit {quest.schwierigkeit} von 5">
							{'⭐'.repeat(quest.schwierigkeit)}
						</span>
						{#if quest.belohnung_hauspunkte > 0}
							<span class="text-academy-cyan font-bold">
								+{quest.belohnung_hauspunkte} Hauspunkte
							</span>
						{/if}
						{#if quest.belohnung_xp > 0}
							<span class="text-academy-cyan font-bold">+{quest.belohnung_xp} XP</span>
						{/if}
						{#if quest.enddatum}
							<span class="text-academy-steel">
								bis {new Date(quest.enddatum).toLocaleDateString('de-DE')}
							</span>
						{/if}
					</div>
				</div>
			</section>
		{/if}

		<!-- Die Stundengläser -->
		<section class="mb-10">
			<div class="flex items-end justify-between flex-wrap gap-2 mb-6">
				<h2 class="text-2xl font-heading text-academy-gold">Die Stundengläser</h2>
				{#if glaeser.length > 0}
					<p class="text-xs text-academy-steel">
						zusammen <span class="text-academy-cyan font-bold"
							>{gesamtVerfuegbar.toLocaleString('de-DE')}</span
						> Punkte verfügbar
					</p>
				{/if}
			</div>

			{#if glaeser.length === 0}
				<div
					class="text-center py-12 text-academy-steel bg-academy-surface rounded-lg border border-academy-blue/30"
				>
					<div class="text-4xl mb-3">⏳</div>
					<p>In dieser Fakultät steht noch kein Haus.</p>
					<p class="text-sm mt-1">Sobald Häuser gegründet sind, füllen sich hier die Gläser.</p>
				</div>
			{:else}
				<div
					class="grid gap-6 justify-items-center"
					style="grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));"
				>
					{#each glaeser as g, i (g.haus_id)}
						<div
							class="w-full bg-academy-surface rounded-lg border p-5 {i === 0 && g.gesammelt > 0
								? 'schimmert'
								: ''}"
							style="border-color: {(g.farbe_primaer || '#24406a') + '66'}"
						>
							<Stundenglas
								gesammelt={g.gesammelt}
								verfuegbar={g.verfuegbar}
								mitglieder={g.mitglieder}
								{spitze}
								farbe={g.farbe_primaer}
								zierfarbe={g.farbe_sekundaer}
								name={g.hausname}
								untertitel={g.motto ?? ''}
								gross={glaeser.length <= 3}
							/>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Türen -->
		<section class="grid grid-cols-1 sm:grid-cols-2 gap-4">
			<a
				href="{base}/login"
				class="bg-academy-surface rounded-lg p-5 border border-academy-blue/30 hover:border-academy-gold/50"
			>
				<div class="text-2xl mb-1">🪄</div>
				<h3 class="font-heading text-academy-gold font-bold">Schüler*innen-Zugang</h3>
				<p class="text-sm text-academy-steel">
					Punkte, Heldentaten und der Markt – mit Loginname und Passwort.
				</p>
			</a>
			<a
				href="{base}/login"
				class="bg-academy-surface rounded-lg p-5 border border-academy-blue/30 hover:border-academy-gold/50"
			>
				<div class="text-2xl mb-1">🕯️</div>
				<h3 class="font-heading text-academy-gold font-bold">Lehrkraft-Zugang</h3>
				<p class="text-sm text-academy-steel">Punkte vergeben, Häuser und Quests verwalten.</p>
			</a>
		</section>
	{/if}
</div>
