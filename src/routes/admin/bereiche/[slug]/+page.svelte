<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { supabase, createHaus } from '$lib/supabase.js';

	let bereich = $state<any>(null);
	let haeuser = $state<any[]>([]);
	let loading = $state(true);

	let showCreateForm = $state(false);
	let newName = $state('');
	let newHausname = $state('');
	let newMotto = $state('');
	let newFarbePrimär = $state('#1e3a5f');
	let newFarbeSekundär = $state('#d4a74a');
	let newBeschreibung = $state('');

	onMount(async () => {
		await load();
	});

	async function load() {
		loading = true;
		const slug = $page.params.slug;
		const { data: b } = await supabase.from('bereiche').select('*').eq('slug', slug).single();
		bereich = b;
		if (b) {
			const { data: h } = await supabase
				.from('haeuser')
				.select('*')
				.eq('bereich_id', b.id)
				.order('hausname');
			haeuser = h ?? [];
		}
		loading = false;
	}

	async function handleCreate(e: Event) {
		e.preventDefault();
		if (!bereich) return;
		const { error } = await createHaus({
			bereich_id: bereich.id,
			name: newName,
			hausname: newHausname,
			motto: newMotto,
			farbe_primär: newFarbePrimär,
			farbe_sekundär: newFarbeSekundär,
			beschreibung: newBeschreibung
		});
		if (!error) {
			showCreateForm = false;
			newName = '';
			newHausname = '';
			newMotto = '';
			newBeschreibung = '';
			await load();
		}
	}
</script>

{#if loading}
	<div class="text-academy-steel">Lade…</div>
{:else if !bereich}
	<div class="text-academy-steel">Bereich nicht gefunden.</div>
{:else}
	<div class="flex justify-between items-start mb-6">
		<div>
			<a
				href="{base}/admin/bereiche"
				class="text-academy-steel text-sm hover:text-academy-parchment">← Bereiche</a
			>
			<h2 class="text-2xl font-heading text-academy-gold mt-1">
				{bereich.typ === 'fach' ? '📖' : '🎓'}
				{bereich.name}
			</h2>
			{#if bereich.motto}
				<p class="text-sm text-academy-steel italic">„{bereich.motto}“</p>
			{/if}
		</div>
		<button
			onclick={() => (showCreateForm = !showCreateForm)}
			class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 transition-colors"
		>
			{showCreateForm ? 'Abbrechen' : '+ Neues Haus'}
		</button>
	</div>

	{#if showCreateForm}
		<form
			onsubmit={handleCreate}
			class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30 mb-6 space-y-4"
		>
			<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
				<div>
					<label for="new-name" class="block text-sm text-academy-parchment mb-1">Klassenname</label
					>
					<input
						id="new-name"
						type="text"
						bind:value={newName}
						required
						class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
						placeholder="z.B. 7A"
					/>
				</div>
				<div>
					<label for="new-hausname" class="block text-sm text-academy-parchment mb-1"
						>Hausname</label
					>
					<input
						id="new-hausname"
						type="text"
						bind:value={newHausname}
						required
						class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
						placeholder="z.B. Haus Schattenfels"
					/>
				</div>
				<div>
					<label for="new-farbe-primär" class="block text-sm text-academy-parchment mb-1"
						>Hausfarbe (primär)</label
					>
					<input
						id="new-farbe-primär"
						type="color"
						bind:value={newFarbePrimär}
						class="w-full h-10 rounded bg-academy-bg border border-academy-blue/50 cursor-pointer"
					/>
				</div>
				<div>
					<label for="new-farbe-sekundär" class="block text-sm text-academy-parchment mb-1"
						>Hausfarbe (sekundär)</label
					>
					<input
						id="new-farbe-sekundär"
						type="color"
						bind:value={newFarbeSekundär}
						class="w-full h-10 rounded bg-academy-bg border border-academy-blue/50 cursor-pointer"
					/>
				</div>
				<div>
					<label for="new-motto" class="block text-sm text-academy-parchment mb-1">Motto</label>
					<input
						id="new-motto"
						type="text"
						bind:value={newMotto}
						class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					/>
				</div>
				<div>
					<label for="new-beschreibung" class="block text-sm text-academy-parchment mb-1"
						>Beschreibung</label
					>
					<textarea
						id="new-beschreibung"
						bind:value={newBeschreibung}
						rows={2}
						class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					></textarea>
				</div>
			</div>
			<button
				type="submit"
				class="px-6 py-2 bg-academy-cyan text-white rounded font-bold text-sm hover:bg-academy-cyan/80 transition-colors"
			>
				Haus erstellen
			</button>
		</form>
	{/if}

	{#if haeuser.length === 0}
		<div class="text-center py-12 text-academy-steel">
			<div class="text-4xl mb-4">🏰</div>
			<p>Noch keine Häuser in diesem Bereich.</p>
			<p class="text-sm mt-2">Erstelle ein Haus, z.B. „Haus Schattenfels“ für die Klasse 7A.</p>
		</div>
	{:else}
		<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
			{#each haeuser as haus}
				<a
					href="{base}/admin/bereiche/{bereich.slug}/haeuser/{haus.slug}"
					class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 hover:border-academy-gold/50 transition-colors block"
				>
					<div class="flex items-center gap-3">
						<div
							class="w-10 h-10 rounded-full flex items-center justify-center text-lg font-bold"
							style="background: {haus.farbe_primär}; color: {haus.farbe_sekundär}"
						>
							{haus.hausname[0]}
						</div>
						<div class="flex-1">
							<div class="font-bold text-academy-parchment">{haus.hausname}</div>
							<div class="text-xs text-academy-steel">
								{haus.name}
								{#if haus.motto}
									· „{haus.motto}“{/if}
							</div>
						</div>
						<div class="text-right">
							<div class="text-academy-gold font-bold">{haus.hauspunkte}</div>
							<div class="text-xs text-academy-steel">Punkte</div>
						</div>
					</div>
				</a>
			{/each}
		</div>
	{/if}
{/if}
