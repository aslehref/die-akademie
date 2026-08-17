<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { supabase, getSchueler, createSchueler, awardPoints, getChronik } from '$lib/supabase.js';

	let haus = $state<any>(null);
	let schueler = $state<any[]>([]);
	let transaktionen = $state<any[]>([]);
	let chronik = $state<any[]>([]);
	let loading = $state(true);

	// Schüler anlegen
	let showAddStudent = $state(false);
	let newAkademiename = $state('');
	let addStudentError = $state('');

	// Punkte vergeben
	let showAwardPoints = $state(false);
	let selectedSchueler = $state('');
	let pointBetrag = $state(10);
	let pointKategorie = $state('lernen');
	let pointGrund = $state('');
	let lehrerId = $state('');

	const categories = [
		{ value: 'lernen', label: '📚 Lernen & Leistung' },
		{ value: 'sozialverhalten', label: '🤝 Sozialverhalten' },
		{ value: 'selbstständigkeit', label: '🧠 Selbstständigkeit' },
		{ value: 'diskussion', label: '🗣️ Diskussion' },
		{ value: 'demokratie', label: '🏛️ Demokratie' },
		{ value: 'persönliche_entwicklung', label: '🌱 Persönliche Entwicklung' },
		{ value: 'verantwortung', label: '🧹 Verantwortung' },
		{ value: 'quest', label: '⚔️ Quest' }
	];

	onMount(async () => {
		await load();
	});

	async function load() {
		loading = true;
		const houslug = $page.params.houslug;
		const { data: h } = await supabase.from('haeuser').select('*').eq('slug', houslug).single();
		haus = h;
		if (h) {
			const [s, t, c] = await Promise.all([
				getSchueler(h.id),
				getHausTransaktionen(h.id),
				getChronik(h.id)
			]);
			schueler = s.data ?? [];
			transaktionen = t.data ?? [];
			chronik = c.data ?? [];
		}
		// Get current user as fallback lehrer
		const {
			data: { user }
		} = await supabase.auth.getUser();
		if (user) lehrerId = user.id;
		loading = false;
	}

	async function getHausTransaktionen(hausId: string) {
		return await supabase
			.from('punkte_transaktionen')
			.select('*, schueler:schueler_id(akademiename)')
			.eq('haus_id', hausId)
			.order('created_at', { ascending: false })
			.limit(50);
	}

	async function handleAddStudent(e: Event) {
		e.preventDefault();
		if (!haus) return;
		addStudentError = '';

		// Kinder bekommen bewusst keinen eigenen Zugang: kein Login, kein
		// Passwort, keine E-Mail-Adresse. Der Datensatz gehoert der Lehrkraft.
		const { error } = await createSchueler({
			haus_id: haus.id,
			akademiename: newAkademiename.trim()
		});

		if (error) {
			addStudentError =
				error.code === '23505'
					? `„${newAkademiename.trim()}“ gibt es in diesem Haus schon.`
					: error.message;
			return;
		}

		showAddStudent = false;
		newAkademiename = '';
		await load();
	}
	async function handleAwardPoints(e: Event) {
		e.preventDefault();
		if (!haus || !selectedSchueler) return;
		const schuelerId = selectedSchueler;
		const { error } = await awardPoints({
			schueler_id: schuelerId,
			haus_id: haus.id,
			betrag: pointBetrag,
			kategorie: pointKategorie,
			grund: pointGrund,
			lehrer_id: lehrerId
		});
		if (error) {
			alert(error.message);
			return;
		}
		showAwardPoints = false;
		pointGrund = '';
		await load();
	}

	async function handleEnergyChange(delta: number) {
		if (!haus) return;
		const newEnergie = Math.max(0, Math.min(haus.energie_max, haus.energie + delta));
		await supabase.from('haeuser').update({ energie: newEnergie }).eq('id', haus.id);
		haus.energie = newEnergie;
	}

	function formatDate(dateStr: string) {
		return new Date(dateStr).toLocaleDateString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function catLabel(value: string) {
		return categories.find((c) => c.value === value)?.label ?? value;
	}
</script>

{#if loading}
	<div class="text-academy-steel">Lade…</div>
{:else if !haus}
	<div class="text-academy-steel">Haus nicht gefunden.</div>
{:else}
	<!-- Haus-Header -->
	<div class="flex items-center gap-4 mb-6">
		<a href="{base}/admin/bereiche" class="text-academy-steel text-sm hover:text-academy-parchment"
			>← Bereiche</a
		>
	</div>

	<div
		class="bg-academy-surface rounded-lg p-6 border mb-6"
		style="border-color: {haus.farbe_primär}44;"
	>
		<div class="flex items-start justify-between">
			<div class="flex items-center gap-4">
				<div
					class="w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold"
					style="background: {haus.farbe_primär}; color: {haus.farbe_sekundär}"
				>
					{haus.hausname[0]}
				</div>
				<div>
					<h2 class="text-2xl font-heading text-academy-gold">{haus.hausname}</h2>
					<p class="text-academy-steel">
						{haus.name}
						{#if haus.motto}
							· „{haus.motto}“{/if}
					</p>
				</div>
			</div>
			<div class="text-right">
				<div class="text-3xl font-bold text-academy-gold">{haus.hauspunkte}</div>
				<div class="text-sm text-academy-steel">Hauspunkte</div>
				<div class="flex items-center gap-2 mt-2 justify-end">
					<span class="text-xs text-academy-steel"
						>⚡ Energie: {haus.energie}/{haus.energie_max}</span
					>
					<button
						onclick={() => handleEnergyChange(-5)}
						class="text-xs px-2 py-1 bg-red-900/30 text-red-400 rounded hover:bg-red-900/50"
						>−5</button
					>
					<button
						onclick={() => handleEnergyChange(5)}
						class="text-xs px-2 py-1 bg-green-900/30 text-green-400 rounded hover:bg-green-900/50"
						>+5</button
					>
				</div>
			</div>
		</div>
	</div>

	<!-- Aktionen -->
	<div class="flex gap-3 mb-6">
		<button
			onclick={() => {
				showAddStudent = !showAddStudent;
				showAwardPoints = false;
			}}
			class="px-4 py-2 bg-academy-cyan text-white rounded font-bold text-sm hover:bg-academy-cyan/80 transition-colors"
		>
			+ Schüler hinzufügen
		</button>
		<button
			onclick={() => {
				showAwardPoints = !showAwardPoints;
				showAddStudent = false;
			}}
			class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 transition-colors"
		>
			+ Punkte vergeben
		</button>
	</div>

	<!-- Schüler hinzufügen Form -->
	{#if showAddStudent}
		<form
			onsubmit={handleAddStudent}
			class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 mb-6 space-y-3"
		>
			<div class="grid grid-cols-1 md:grid-cols-2 gap-3">
				<div>
					<label for="akademiename" class="block text-sm text-academy-parchment mb-1"
						>Akademiename</label
					>
					<input
						id="akademiename"
						type="text"
						bind:value={newAkademiename}
						required
						class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
						placeholder="z.B. Raven"
					/>
				</div>
			</div>
			{#if addStudentError}
				<p class="text-sm text-red-300">{addStudentError}</p>
			{/if}
			<p class="text-xs text-academy-steel">
				Kinder melden sich nicht selbst an. Der Akademiename genügt.
			</p>
			<button
				type="submit"
				class="px-4 py-2 bg-academy-cyan text-white rounded font-bold text-sm hover:bg-academy-cyan/80 transition-colors"
			>
				Schüler hinzufügen
			</button>
		</form>
	{/if}

	<!-- Punkte vergeben Form -->
	{#if showAwardPoints}
		<form
			onsubmit={handleAwardPoints}
			class="bg-academy-surface rounded-lg p-4 border border-academy-gold/30 mb-6 space-y-3"
		>
			<h3 class="font-heading text-academy-gold font-bold">Punkte vergeben</h3>
			<div class="grid grid-cols-1 md:grid-cols-3 gap-3">
				<div>
					<label for="selected-schueler" class="block text-sm text-academy-parchment mb-1"
						>Schüler</label
					>
					<select
						id="selected-schueler"
						bind:value={selectedSchueler}
						required
						class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					>
						<option value="">Auswählen…</option>
						{#each schueler as s}
							<option value={s.id}>{s.akademiename} (Level {s.level}, {s.punkte} Punkte)</option>
						{/each}
					</select>
				</div>
				<div>
					<label for="point-betrag" class="block text-sm text-academy-parchment mb-1">Betrag</label>
					<input
						id="point-betrag"
						type="number"
						bind:value={pointBetrag}
						required
						min="-50"
						max="100"
						class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					/>
				</div>
				<div>
					<label for="point-kategorie" class="block text-sm text-academy-parchment mb-1"
						>Kategorie</label
					>
					<select
						id="point-kategorie"
						bind:value={pointKategorie}
						class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					>
						{#each categories as cat}
							<option value={cat.value}>{cat.label}</option>
						{/each}
					</select>
				</div>
				<div class="md:col-span-3">
					<label for="point-grund" class="block text-sm text-academy-parchment mb-1">Grund</label>
					<input
						id="point-grund"
						type="text"
						bind:value={pointGrund}
						required
						class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
						placeholder="z.B. Hervorragende Diskussionsbeteiligung"
					/>
				</div>
			</div>
			<button
				type="submit"
				class="px-6 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm hover:bg-academy-gold/90 transition-colors"
			>
				Punkte verbuchen
			</button>
		</form>
	{/if}

	<!-- Zweispaltig: Schüler + Transaktionen -->
	<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
		<!-- Schülerliste -->
		<section class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30">
			<h3 class="font-heading text-academy-gold font-bold mb-3">👤 Schüler ({schueler.length})</h3>
			{#if schueler.length === 0}
				<p class="text-academy-steel text-sm">Noch keine Schüler in diesem Haus.</p>
			{:else}
				<div class="space-y-2">
					{#each schueler as s}
						<div
							class="flex items-center justify-between p-2 rounded bg-academy-bg/50 border border-academy-blue/10"
						>
							<div>
								<span class="font-bold text-academy-parchment">{s.akademiename}</span>
								<span class="text-xs text-academy-steel ml-2">⭐ Level {s.level}</span>
							</div>
							<div class="text-right text-sm">
								<span class="text-academy-cyan">{s.xp} XP</span>
								<span class="text-academy-gold ml-2">{s.punkte} 🪙</span>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Letzte Transaktionen -->
		<section class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30">
			<h3 class="font-heading text-academy-gold font-bold mb-3">📜 Letzte Transaktionen</h3>
			{#if transaktionen.length === 0}
				<p class="text-academy-steel text-sm">Noch keine Transaktionen.</p>
			{:else}
				<div class="space-y-2 max-h-96 overflow-y-auto">
					{#each transaktionen as t}
						<div
							class="flex items-start justify-between p-2 rounded bg-academy-bg/50 border border-academy-blue/10 text-sm"
						>
							<div class="flex-1">
								<div class="text-academy-parchment">
									{t.schueler?.akademiename ?? '—'}
								</div>
								<div class="text-xs text-academy-steel">{catLabel(t.kategorie)} · {t.grund}</div>
								<div class="text-xs text-academy-steel">{formatDate(t.created_at)}</div>
							</div>
							<div
								class="font-bold whitespace-nowrap {t.betrag >= 0
									? 'text-academy-cyan'
									: 'text-red-400'}"
							>
								{t.betrag >= 0 ? '+' : ''}{t.betrag}
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</section>
	</div>

	<!-- Chronik -->
	<section class="bg-academy-surface rounded-lg p-4 border border-academy-blue/30 mt-6">
		<h3 class="font-heading text-academy-gold font-bold mb-3">📜 Chronik</h3>
		{#if chronik.length === 0}
			<p class="text-academy-steel text-sm">Noch keine Chronik-Einträge.</p>
		{:else}
			<div class="space-y-2 max-h-48 overflow-y-auto">
				{#each chronik as e}
					<div class="flex items-start gap-2 p-2 rounded bg-academy-bg/50 text-sm">
						<div class="text-xs text-academy-steel mt-0.5">{formatDate(e.created_at)}</div>
						<div>
							<span class="text-academy-parchment font-medium">{e.titel}</span>
							{#if e.beschreibung}
								<p class="text-academy-steel text-xs">{e.beschreibung}</p>
							{/if}
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</section>
{/if}
