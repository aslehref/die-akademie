<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase, createAbzeichen, updateAbzeichen, deleteAbzeichen } from '$lib/supabase.js';

	let abzeichen = $state<any[]>([]);
	let loading = $state(true);

	let showCreateForm = $state(false);
	let newName = $state('');
	let newSymbol = $state('');
	let newBeschreibung = $state('');
	let newBedingung = $state<
		'manuell' | 'anzahl_aktionen' | 'quest' | 'punktzahl' | 'besondere_leistung'
	>('manuell');
	let newBedingungWert = $state<number | null>(null);
	let newGeltungsbereich = $state<'global' | 'fach' | 'klassenstufe' | 'klasse'>('global');
	let newBereichId = $state<string | null>(null);

	let editId = $state<string | null>(null);
	let editName = $state('');
	let editSymbol = $state('');
	let editBeschreibung = $state('');
	let editBedingung = $state<
		'manuell' | 'anzahl_aktionen' | 'quest' | 'punktzahl' | 'besondere_leistung'
	>('manuell');
	let editBedingungWert = $state<number | null>(null);
	let editGeltungsbereich = $state<'global' | 'fach' | 'klassenstufe' | 'klasse'>('global');
	let editBereichId = $state<string | null>(null);

	onMount(async () => {
		await load();
	});

	async function load() {
		loading = true;
		const { data } = await supabase.from('abzeichen').select('*');
		abzeichen = data ?? [];
		loading = false;
	}

	async function handleCreate(e: Event) {
		e.preventDefault();
		const { error } = await createAbzeichen({
			name: newName,
			symbol: newSymbol,
			beschreibung: newBeschreibung,
			bedingung: newBedingung,
			bedingung_wert: newBedingungWert,
			gültigkeitsbereich: newGeltungsbereich,
			bereich_id: newBereichId
		});
		if (!error) {
			showCreateForm = false;
			newName = '';
			newSymbol = '';
			newBeschreibung = '';
			newBedingung = 'manuell';
			newBedingungWert = null;
			newBereichId = null;
			await load();
		}
	}

	async function handleUpdate(e: Event) {
		e.preventDefault();
		if (!editId) return;
		const { error } = await updateAbzeichen(editId, {
			name: editName,
			symbol: editSymbol,
			beschreibung: editBeschreibung,
			bedingung: editBedingung,
			bedingung_wert: editBedingungWert,
			gültigkeitsbereich: editGeltungsbereich,
			bereich_id: editBereichId
		});
		if (!error) {
			editId = null;
			editName = '';
			editSymbol = '';
			editBeschreibung = '';
			editBedingung = 'manuell';
			editBedingungWert = null;
			editBereichId = null;
			await load();
		}
	}

	async function handleDelete(id: string) {
		if (!confirm('Abzeichen wirklich löschen?')) return;
		await deleteAbzeichen(id);
		await load();
	}

	function startEdit(abz: any) {
		editId = abz.id;
		editName = abz.name;
		editSymbol = abz.symbol;
		editBeschreibung = abz.beschreibung;
		editBedingung = abz.bedingung;
		editBedingungWert = abz.bedingung_wert;
		editGeltungsbereich = abz.gültigkeitsbereich;
		editBereichId = abz.bereich_id;
	}

	function cancelEdit() {
		editId = null;
		editName = '';
		editSymbol = '';
		editBeschreibung = '';
		editBedingung = 'manuell';
		editBedingungWert = null;
		editBereichId = null;
	}
</script>

<div class="flex justify-between items-center mb-6">
	<h2 class="text-2xl font-heading text-academy-gold">Abzeichen verwalten</h2>
	<button
		onclick={() => (showCreateForm = !showCreateForm)}
		class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 transition-colors"
	>
		{showCreateForm ? 'Abbrechen' : '+ Neues Abzeichen'}
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
					placeholder="z.B. Teamplayer"
				/>
			</div>
			<div>
				<label for="new-symbol" class="block text-sm text-academy-parchment mb-1">Symbol</label>
				<input
					id="new-symbol"
					type="text"
					bind:value={newSymbol}
					required
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					placeholder="z.B. 🤝"
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
			<div>
				<label for="new-bedingung" class="block text-sm text-academy-parchment mb-1"
					>Bedingung</label
				>
				<select
					id="new-bedingung"
					bind:value={newBedingung}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				>
					<option value="manuell">✋ Manuell vergeben</option>
					<option value="anzahl_aktionen">🔢 Anzahl bestimmter Aktionen</option>
					<option value="quest">⚔️ Quest abgeschlossen</option>
					<option value="punktzahl">🎯 Certain Punktzahl</option>
					<option value="besondere_leistung">🌟 Besondere Leistung</option>
				</select>
			</div>
			<div>
				<label for="new-bedingung-wert" class="block text-sm text-academy-parchment mb-1"
					>Bedingungswert (falls zutreffend)</label
				>
				<input
					id="new-bedingung-wert"
					type="number"
					bind:value={newBedingungWert}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					placeholder="z.B. 5 für 5 Aktionen"
				/>
			</div>
			<div class="md:col-span-2">
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
					>Zu welchem Bereich (optional, Bereichs-ID)</label
				>
				<input
					id="new-bereich-id"
					type="text"
					bind:value={newBereichId}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					placeholder="Bereichs-ID oder leer für global"
				/>
			</div>
		</div>
		<button
			type="submit"
			class="px-6 py-2 bg-academy-cyan text-white rounded font-bold text-sm hover:bg-academy-cyan/80 transition-colors"
		>
			Abzeichen erstellen
		</button>
	</form>
{/if}

{#if loading}
	<div class="text-academy-steel">Lade Abzeichen…</div>
{:else if abzeichen.length === 0}
	<div class="text-center py-12 text-academy-steel">
		<div class="text-4xl mb-4">🏅</div>
		<p>Noch keine Abzeichen angelegt.</p>
		<p class="text-sm mt-2">Erstelle ein Abzeichen, z.B. „Teamplayer“ für gute Zusammenarbeit.</p>
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
						>Symbol</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Beschreibung</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Bedingung</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Wert</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Gültigkeit</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Bereich</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium text-academy-steel uppercase tracking-wider"
						>Aktionen</th
					>
				</tr>
			</thead>
			<tbody class="divide-y divide-academy-blue/10">
				{#each abzeichen as a}
					<tr class="hover:bg-academy-bg/50">
						<td class="px-4 py-2 text-sm font-medium text-academy-parchment">
							{#if editId === a.id}
								<input
									type="text"
									bind:value={editName}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
								/>
							{:else}
								{a.name}
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === a.id}
								<input
									type="text"
									bind:value={editSymbol}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
								/>
							{:else}
								{a.symbol}
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === a.id}
								<textarea
									bind:value={editBeschreibung}
									rows={1}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
								>
								</textarea>
							{:else}
								{a.beschreibung}
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === a.id}
								<select
									bind:value={editBedingung}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
								>
									<option value="manuell">✋ Manuell vergeben</option>
									<option value="anzahl_aktionen">🔢 Anzahl bestimmter Aktionen</option>
									<option value="quest">⚔️ Quest abgeschlossen</option>
									<option value="punktzahl">🎯 Certain Punktzahl</option>
									<option value="besondere_leistung">🌟 Besondere Leistung</option>
								</select>
							{:else}
								<span class="text-academy-cyan">
									{#if a.bedingung === 'manuell'}✋ Manuell vergeben
									{:else if a.bedingung === 'anzahl_aktionen'}🔢 Anzahl bestimmter Aktionen
									{:else if a.bedingung === 'quest'}⚔️ Quest abgeschlossen
									{:else if a.bedingung === 'punktzahl'}🎯 Certain Punktzahl
									{:else if a.bedingung === 'besondere_leistung'}🌟 Besondere Leistung
									{/if}
								</span>
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === a.id}
								<input
									type="number"
									bind:value={editBedingungWert}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
								/>
							{:else}
								{a.bedingung_wert ?? '—'}
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === a.id}
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
									{#if a.gültigkeitsbereich === 'global'}🌍 Global
									{:else if a.gültigkeitsbereich === 'fach'}📚 Fach
									{:else if a.gültigkeitsbereich === 'klassenstufe'}🎓 Klassenstufe
									{:else if a.gültigkeitsbereich === 'klasse'}🏫 Klasse
									{/if}
								</span>
							{/if}
						</td>
						<td class="px-4 py-2 text-sm">
							{#if editId === a.id}
								<input
									type="text"
									bind:value={editBereichId}
									class="w-full px-2 py-1 bg-academy-bg border border-academy-blue/30 text-academy-parchment rounded"
									placeholder="Bereichs-ID (optional)"
								/>
							{:else}
								{a.bereich_id ?? '—'}
							{/if}
						</td>
						<td class="px-4 py-2 space-x-2">
							{#if editId === a.id}
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
									onclick={() => startEdit(a)}
									class="px-3 py-1 text-xs text-academy-cyan hover:text-academy-gold"
								>
									Bearbeiten
								</button>
								<button
									onclick={() => handleDelete(a.id)}
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
