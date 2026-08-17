<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { supabase } from '$lib/supabase.js';

	let stats = $state({ bereiche: 0, haeuser: 0, schueler: 0, quests: 0 });

	onMount(async () => {
		const [b, h, s, q] = await Promise.all([
			supabase.from('bereiche').select('id', { count: 'exact', head: true }),
			supabase.from('haeuser').select('id', { count: 'exact', head: true }),
			supabase.from('schueler').select('id', { count: 'exact', head: true }),
			supabase.from('quests').select('id', { count: 'exact', head: true })
		]);
		stats = {
			bereiche: b.count ?? 0,
			haeuser: h.count ?? 0,
			schueler: s.count ?? 0,
			quests: q.count ?? 0
		};
	});
</script>

<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
	<div class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30">
		<div class="text-3xl mb-2">📚</div>
		<div class="text-2xl font-bold text-academy-gold">{stats.bereiche}</div>
		<div class="text-sm text-academy-steel">Bereiche (Fächer/Klassenstufen)</div>
	</div>
	<div class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30">
		<div class="text-3xl mb-2">🏰</div>
		<div class="text-2xl font-bold text-academy-gold">{stats.haeuser}</div>
		<div class="text-sm text-academy-steel">Häuser / Klassen</div>
	</div>
	<div class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30">
		<div class="text-3xl mb-2">👤</div>
		<div class="text-2xl font-bold text-academy-gold">{stats.schueler}</div>
		<div class="text-sm text-academy-steel">Schüler</div>
	</div>
	<div class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30">
		<div class="text-3xl mb-2">⚔️</div>
		<div class="text-2xl font-bold text-academy-gold">{stats.quests}</div>
		<div class="text-sm text-academy-steel">Quests</div>
	</div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6">
	<section class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
		<h2 class="text-xl font-heading text-academy-gold mb-4">📚 Bereiche verwalten</h2>
		<p class="text-academy-steel mb-4">
			Fächer (Religion, Sozialkunde) und Klassenstufen anlegen und verwalten.
		</p>
		<a
			href="{base}/admin/bereiche"
			class="inline-block px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 transition-colors"
		>
			Bereiche öffnen
		</a>
	</section>
	<section class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30">
		<h2 class="text-xl font-heading text-academy-gold mb-4">⚔️ Quests verwalten</h2>
		<p class="text-academy-steel mb-4">
			Globale, fachspezifische und klassenbezogene Quests erstellen.
		</p>
		<a
			href="{base}/admin/quests"
			class="inline-block px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 transition-colors"
		>
			Quests öffnen
		</a>
	</section>
</div>
