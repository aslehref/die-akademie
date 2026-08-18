<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase, createBelohnung, updateBelohnung, deleteBelohnung } from '$lib/supabase.js';

	let belohnungen = $state<any[]>([]);
	let loading = $state(true);

	let showCreateForm = $state(false);
	let newName = $state('');
	let newKategorie = $state<'joker' | 'wahlmöglichkeit' | 'aktivität' | 'challenge' | 'legendär'>(
		'joker'
	);
	let newKosten = $state(0);
	let newBeschreibung = $state('');
	let newGeltungsbereich = $state<'global' | 'fach' | 'klassenstufe' | 'klasse'>('global');
	let newBereichId = $state<string | null>(null);

	let editId = $state<string | null>(null);
	let editName = $state('');
	let editKategorie = $state<'joker' | 'wahlmöglichkeit' | 'aktivität' | 'challenge' | 'legendär'>(
		'joker'
	);
	let editKosten = $state(0);
	let editBeschreibung = $state('');
	let editGeltungsbereich = $state<'global' | 'fach' | 'klassenstufe' | 'klasse'>('global');
	let editBereichId = $state<string | null>(null);

	onMount(async () => {
		await load();
	});

	async function load() {
		loading = true;
		const { data } = await supabase.from('belohnungen').select('*').order('kosten');
		belohnungen = data ?? [];
		loading = false;
	}

	async function handleCreate(e: Event) {
		e.preventDefault();
		const { error } = await createBelohnung({
			name: newName,
			kategorie: newKategorie,
			kosten: newKosten,
			beschreibung: newBeschreibung,
			gültigkeitsbereich: newGeltungsbereich,
			bereich_id: newBereichId
		});
		if (!error) {
			showCreateForm = false;
			newName = '';
			newKosten = 0;
			newBeschreibung = '';
			newBereichId = null;
			await load();
		}
	}

	async function handleUpdate(e: Event) {
		e.preventDefault();
		if (!editId) return;
		const { error } = await updateBelohnung(editId, {
			name: editName,
			kategorie: editKategorie,
			kosten: editKosten,
			beschreibung: editBeschreibung,
			gültigkeitsbereich: editGeltungsbereich,
			bereich_id: editBereichId
		});
		if (!error) {
			editId = null;
			editName = '';
			editKosten = 0;
			editBeschreibung = '';
			editBereichId = null;
			await load();
		}
	}

	async function handleDelete(id: string) {
		if (!confirm('Privileg wirklich streichen?')) return;
		await deleteBelohnung(id);
		await load();
	}

	function startEdit(belohnung: any) {
		editId = belohnung.id;
		editName = belohnung.name;
		editKategorie = belohnung.kategorie;
		editKosten = belohnung.kosten;
		editBeschreibung = belohnung.beschreibung;
		editGeltungsbereich = belohnung.gültigkeitsbereich;
		editBereichId = belohnung.bereich_id;
	}

	function cancelEdit() {
		editId = null;
		editName = '';
		editKosten = 0;
		editBeschreibung = '';
		editBereichId = null;
	}
</script>

<div class="flex justify-between items-center mb-6">
	<h2 class="text-2xl font-heading text-academy-gold">Privilegien verwalten</h2>
	<button
		onclick={() => (showCreateForm = !showCreateForm)}
		class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 transition-colors"
	>
		{showCreateForm ? 'Abbrechen' : '+ Neues Privileg'}
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
					placeholder="z.B. Hausaufgaben-Joker"
				/>
			</div>
			<div>
				<label for="new-kategorie" class="block text-sm text-academy-parchment mb-1"
					>Kategorie</label
				>
				<select
					id="new-kategorie"
					bind:value={newKategorie}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				>
					<option value="joker">🃏 Joker</option>
					<option value="wahlmöglichkeit">🎯 Wahlmöglichkeit</option>
					<option value="aktivität">🎲 Aktivität</option>
					<option value="challenge">⚔️ Challenge</option>
					<option value="legendär">👑 Legendär</option>
				</select>
			</div>
			<div>
				<label for="new-kosten" class="block text-sm text-academy-parchment mb-1"
					>Kosten (Punkte)</label
				>
				<input
					id="new-kosten"
					type="number"
					bind:value={newKosten}
					required
					min="0"
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				/>
			</div>
			<div class="md:col-span-2">
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
			<div>
				<label for="new-geltungsbereich" class="block text-sm text-academy-parchment mb-1"
					>Gültigkeitsbereich</label
				>
				<select
					id="new-geltungsbereich"
					bind:value={newGeltungsbereich}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				>
					<option value="global">🌍 Global</option>
					<option value="fach">📚 Fach</option>
					<option value="klassenstufe">🎓 Klassenstufe</option>
					<option value="klasse">🏫 Klasse</option>
				</select>
			</div>
			<div>
				<label for="new-bereich-id" class="block text-sm text-academy-parchment mb-1"
					>Zu welcher Fakultät? (leer = gilt überall)</label
				>
				<input
					id="new-bereich-id"
					type="text"
					bind:value={newBereichId}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					placeholder="Fakultäts-ID oder leer"
				/>
			</div>
		</div>
		<button
			type="submit"
			class="px-6 py-2 bg-academy-cyan text-white rounded font-bold text-sm hover:bg-academy-cyan/80 transition-colors"
		>
			Privileg anlegen
		</button>
	</form>
{/if}

{#if loading}
	<div class="text-academy-steel">Lade Privilegien…</div>
{:else if belohnungen.length === 0}
	<div class="text-center py-12 text-academy-steel">
		<div class="text-4xl mb-4">🪙</div>
		<p>Noch keine Privilegien angelegt.</p>
		<p class="text-sm mt-2">Lege ein Privileg an, z.B. „Hausaufgaben-Joker“ für 50 Punkte.</p>
	</div>
{:else}
	<div class="overflow-x-auto">
		<table class="min-w-full bg-academy-surface rounded-lg border border-academy-blue/30">
			<thead>
				<tr class="bg-academy-bg/50">
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Name</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Kategorie</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Kosten</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Beschreibung</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Gültigkeit</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Fakultät</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Aktionen</th
					>
				</tr>
			</thead>
			<tbody class="divide-y divide-academy-blue/10">
				{#each belohnungen as b}
					<tr class="hover:bg-academy-bg/50">
						<td class="px-4 py-2 text-sm font-medium text-academy-parchment">
							{#if editId === b.id}
								<input
									type="text"
									bind:value={editName}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
								/>
							{:else}
								{b.name}
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === b.id}
								<select
									bind:value={editKategorie}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
								>
									<option value="joker">🃏 Joker</option>
									<option value="wahlmöglichkeit">🎯 Wahlmöglichkeit</option>
									<option value="aktivität">🎲 Aktivität</option>
									<option value="challenge">⚔️ Challenge</option>
									<option value="legendär">👑 Legendär</option>
								</select>
							{:else}
								<span class="text-academy-cyan">
									{#if b.kategorie === 'joker'}🃏 Joker
									{:else if b.kategorie === 'wahlmöglichkeit'}🎯 Wahlmöglichkeit
									{:else if b.kategorie === 'aktivität'}🎲 Aktivität
									{:else if b.kategorie === 'challenge'}⚔️ Challenge
									{:else if b.kategorie === 'legendär'}👑 Legendär
									{/if}
								</span>
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === b.id}
								<input
									type="number"
									bind:value={editKosten}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
									min="0"
								/>
							{:else}
								{b.kosten}
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === b.id}
								<textarea
									bind:value={editBeschreibung}
									rows={1}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
								>
								</textarea>
							{:else}
								{b.beschreibung}
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === b.id}
								<select
									bind:value={editGeltungsbereich}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
								>
									<option value="global">🌍 Global</option>
									<option value="fach">📚 Fach</option>
									<option value="klassenstufe">🎓 Klassenstufe</option>
									<option value="klasse">🏫 Klasse</option>
								</select>
							{:else}
								<span class="text-academy-cyan">
									{#if b.gültigkeitsbereich === 'global'}🌍 Global
									{:else if b.gültigkeitsbereich === 'fach'}📚 Fach
									{:else if b.gültigkeitsbereich === 'klassenstufe'}🎓 Klassenstufe
									{:else if b.gültigkeitsbereich === 'klasse'}🏫 Klasse
									{/if}
								</span>
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === b.id}
								<input
									type="text"
									bind:value={editBereichId}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
									placeholder="Fakultäts-ID (optional)"
								/>
							{:else}
								{b.bereich_id ?? '—'}
							{/if}
						</td>
						<td class="px-4 py-2 space-x-2">
							{#if editId === b.id}
								<button
									onclick={handleUpdate}
									class="px-3 py-1 bg-academy-cyan text-white text-sm rounded hover:bg-academy-cyan/80"
								>
									Speichern
								</button>
								<button
									onclick={cancelEdit}
									class="px-3 py-1 bg-academy-steel/30 text-academy-steel text-sm rounded hover:bg-academy-steel/50"
								>
									Abbrechen
								</button>
							{:else}
								<button
									onclick={() => startEdit(b)}
									class="px-3 py-1 text-xs text-academy-cyan hover:text-academy-gold"
								>
									Bearbeiten
								</button>
								<button
									onclick={() => handleDelete(b.id)}
									class="px-3 py-1 text-xs text-red-400 hover:text-red-300"
								>
									Löschen
								</button>
							{/if}
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}
