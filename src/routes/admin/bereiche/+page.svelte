<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { supabase, createBereich, deleteBereich } from '$lib/supabase.js';

	let bereiche = $state<any[]>([]);
	let loading = $state(true);

	let showCreateForm = $state(false);
	let newName = $state('');
	let newTyp = $state<'fach' | 'klassenstufe'>('fach');
	let newDesc = $state('');
	let newMotto = $state('');

	onMount(async () => {
		await load();
	});

	async function load() {
		loading = true;
		const { data } = await supabase.from('bereiche').select('*').order('typ').order('name');
		bereiche = data ?? [];
		loading = false;
	}

	async function handleCreate(e: Event) {
		e.preventDefault();
		const { error } = await createBereich({
			name: newName,
			typ: newTyp,
			beschreibung: newDesc,
			motto: newMotto
		});
		if (!error) {
			showCreateForm = false;
			newName = '';
			newDesc = '';
			newMotto = '';
			await load();
		}
	}

	async function handleDelete(id: string) {
		if (!confirm('Bereich wirklich löschen?')) return;
		await deleteBereich(id);
		await load();
	}
</script>

<div class="flex justify-between items-center mb-6">
	<h2 class="text-2xl font-heading text-academy-gold">Bereiche</h2>
	<button
		onclick={() => (showCreateForm = !showCreateForm)}
		class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 transition-colors"
	>
		{showCreateForm ? 'Abbrechen' : '+ Neuer Bereich'}
	</button>
</div>

{#if showCreateForm}
	<form
		onsubmit={handleCreate}
		class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30 mb-6 space-y-4"
	>
		<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
			<div>
				<label for="new-name" class="block text-sm text-academy-parchment mb-1">Name</label>
				<input
					id="new-name"
					type="text"
					bind:value={newName}
					required
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					placeholder="z.B. Religion"
				/>
			</div>
			<div>
				<label for="new-typ" class="block text-sm text-academy-parchment mb-1">Typ</label>
				<select
					id="new-typ"
					bind:value={newTyp}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				>
					<option value="fach">📚 Fach</option>
					<option value="klassenstufe">🎓 Klassenstufe</option>
				</select>
			</div>
			<div class="md:col-span-2">
				<label for="new-desc" class="block text-sm text-academy-parchment mb-1">Beschreibung</label>
				<textarea
					id="new-desc"
					bind:value={newDesc}
					rows={2}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				></textarea>
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
		</div>
		<button
			type="submit"
			class="px-6 py-2 bg-academy-cyan text-white rounded font-bold text-sm hover:bg-academy-cyan/80 transition-colors"
		>
			Bereich erstellen
		</button>
	</form>
{/if}

{#if loading}
	<div class="text-academy-steel">Lade Bereiche…</div>
{:else if bereiche.length === 0}
	<div class="text-center py-12 text-academy-steel">
		<div class="text-4xl mb-4">📚</div>
		<p>Noch keine Bereiche angelegt.</p>
		<p class="text-sm mt-2">
			Erstelle ein Fach (z.B. Religion) oder eine Klassenstufe (z.B. Klasse 7).
		</p>
	</div>
{:else}
	<div class="space-y-3">
		{#each bereiche as bereich}
			<div
				class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 flex items-center justify-between hover:border-academy-gold/50 transition-colors"
			>
				<a href="{base}/admin/bereiche/{bereich.slug}" class="flex-1">
					<div class="flex items-center gap-3">
						<span class="text-2xl">{bereich.typ === 'fach' ? '📖' : '🎓'}</span>
						<div>
							<div class="font-bold text-academy-parchment">{bereich.name}</div>
							<div class="text-xs text-academy-steel">
								{bereich.typ === 'fach' ? 'Fach' : 'Klassenstufe'}
								{#if bereich.motto}
									· {bereich.motto}{/if}
							</div>
						</div>
					</div>
				</a>
				<button
					onclick={() => handleDelete(bereich.id)}
					class="px-2 py-1 text-xs text-red-400 hover:text-red-300 hover:bg-red-900/30 rounded transition-colors"
				>
					Löschen
				</button>
			</div>
		{/each}
	</div>
{/if}
