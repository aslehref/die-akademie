<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import {
		supabase,
		createBereich,
		updateBereich,
		deleteBereich,
		bereichLoeschUmfang
	} from '$lib/supabase.js';

	// Eine Fakultät hat jetzt zwei Namen:
	//   titel = der große Name, der oben steht ("Orden der Stillen Wasser")
	//   name  = Fach oder Jahrgang als Untertitel ("Religion, Klasse 7")
	type Bereich = {
		id: string;
		titel: string | null;
		name: string;
		slug: string;
		typ: string;
		beschreibung: string | null;
		motto: string | null;
		farbe_primär: string | null;
		farbe_sekundär: string | null;
	};

	let bereiche = $state<Bereich[]>([]);
	let hausZahl = $state<Record<string, number>>({});
	let loading = $state(true);
	let fehler = $state('');

	// Anlegen
	let zeigeFormular = $state(false);
	let neuTitel = $state('');
	let neuName = $state('');
	let neuTyp = $state<'fach' | 'klassenstufe' | 'allgemein'>('fach');
	let neuBeschreibung = $state('');
	let neuMotto = $state('');
	let neuFarbe = $state('#24406a');
	let neuFarbeZwei = $state('#d4a74a');
	let speichert = $state(false);

	// Bearbeiten
	let bearbeiteId = $state<string | null>(null);
	let bTitel = $state('');
	let bName = $state('');
	let bTyp = $state('fach');
	let bBeschreibung = $state('');
	let bMotto = $state('');
	let bFarbe = $state('#24406a');
	let bFarbeZwei = $state('#d4a74a');

	// Auflösen
	let loeschId = $state<string | null>(null);
	let loeschUmfang = $state<{ haeuser: number; schueler: number } | null>(null);

	const TYP_LABEL: Record<string, string> = {
		fach: 'Fach',
		klassenstufe: 'Jahrgang',
		allgemein: 'Allgemein'
	};

	const TYP_ZEICHEN: Record<string, string> = {
		fach: '📖',
		klassenstufe: '🎓',
		allgemein: '✦'
	};

	function anzeigeTitel(b: Bereich) {
		return b.titel?.trim() || b.name;
	}

	function untertitel(b: Bereich) {
		// Solange kein eigener Titel gepflegt ist, wäre der Untertitel eine
		// wörtliche Wiederholung. Dann lieber nur die Gattung zeigen.
		return b.titel?.trim() && b.titel.trim() !== b.name ? b.name : '';
	}

	/**
	 * Die kleine Zeile unter dem Namen. Bewusst in einer Funktion und
	 * nicht als Kette von {#if} im Text: dort verschluckt die Vorlage die
	 * Leerzeichen an den Rändern, und heraus kommt „Klasse 7 ·Fach“.
	 */
	function zeile(b: Bereich) {
		const anzahl = hausZahl[b.id] ?? 0;
		return [
			untertitel(b),
			TYP_LABEL[b.typ] ?? b.typ,
			`${anzahl} ${anzahl === 1 ? 'Haus' : 'Häuser'}`
		]
			.filter(Boolean)
			.join(' · ');
	}

	onMount(load);

	async function load() {
		loading = true;
		fehler = '';
		const { data, error } = await supabase.from('bereiche').select('*').order('typ');
		if (error) {
			fehler = error.message;
			loading = false;
			return;
		}
		bereiche = (data ?? []).sort((a, b) =>
			anzeigeTitel(a).localeCompare(anzeigeTitel(b), 'de')
		) as Bereich[];

		// Für jede Fakultät die Zahl der Häuser – die Übersicht soll zeigen,
		// wo schon etwas steht und wo noch nichts ist.
		const { data: haeuser } = await supabase.from('haeuser').select('bereich_id');
		const zaehler: Record<string, number> = {};
		for (const h of haeuser ?? []) zaehler[h.bereich_id] = (zaehler[h.bereich_id] ?? 0) + 1;
		hausZahl = zaehler;
		loading = false;
	}

	async function anlegen(e: Event) {
		e.preventDefault();
		if (speichert) return;
		speichert = true;
		fehler = '';
		const { error } = await createBereich({
			titel: neuTitel.trim(),
			name: neuName.trim(),
			typ: neuTyp,
			beschreibung: neuBeschreibung.trim() || null,
			motto: neuMotto.trim() || null,
			farbe_primär: neuFarbe,
			farbe_sekundär: neuFarbeZwei
		});
		speichert = false;
		if (error) {
			fehler = error.message;
			return;
		}
		zeigeFormular = false;
		neuTitel = '';
		neuName = '';
		neuBeschreibung = '';
		neuMotto = '';
		await load();
	}

	function bearbeiten(b: Bereich) {
		bearbeiteId = b.id;
		bTitel = anzeigeTitel(b);
		bName = b.name;
		bTyp = b.typ;
		bBeschreibung = b.beschreibung ?? '';
		bMotto = b.motto ?? '';
		bFarbe = b.farbe_primär ?? '#24406a';
		bFarbeZwei = b.farbe_sekundär ?? '#d4a74a';
	}

	async function bearbeitenSpeichern(e: Event) {
		e.preventDefault();
		if (!bearbeiteId || speichert) return;
		speichert = true;
		fehler = '';
		// Der Slug bleibt bewusst stehen. Er steht in der Adresszeile, und wer
		// eine Fakultät umbenennt, will keine toten Links hinterlassen.
		const { error } = await updateBereich(bearbeiteId, {
			titel: bTitel.trim(),
			name: bName.trim(),
			typ: bTyp,
			beschreibung: bBeschreibung.trim() || null,
			motto: bMotto.trim() || null,
			farbe_primär: bFarbe,
			farbe_sekundär: bFarbeZwei
		});
		speichert = false;
		if (error) {
			fehler = error.message;
			return;
		}
		bearbeiteId = null;
		await load();
	}

	async function loeschenFragen(b: Bereich) {
		loeschId = b.id;
		loeschUmfang = null;
		loeschUmfang = await bereichLoeschUmfang(b.id);
	}

	async function loeschenAusfuehren() {
		if (!loeschId) return;
		speichert = true;
		const { error } = await deleteBereich(loeschId);
		speichert = false;
		if (error) {
			fehler = error.message;
			return;
		}
		loeschId = null;
		loeschUmfang = null;
		await load();
	}
</script>

<div class="flex flex-wrap gap-3 justify-between items-end mb-6">
	<div>
		<h2 class="text-2xl font-heading text-academy-gold">Fakultäten</h2>
		<p class="text-sm text-academy-steel mt-1">
			Jede Fakultät trägt einen Namen und darunter ihr Fach oder ihren Jahrgang.
		</p>
	</div>
	<button
		onclick={() => {
			zeigeFormular = !zeigeFormular;
			bearbeiteId = null;
		}}
		class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm"
	>
		{zeigeFormular ? 'Abbrechen' : '+ Fakultät gründen'}
	</button>
</div>

{#if fehler}
	<div class="mb-6 bg-red-900/30 border border-red-700/50 text-red-200 p-4 rounded text-sm">
		{fehler}
	</div>
{/if}

{#if zeigeFormular}
	<form
		onsubmit={anlegen}
		class="bg-academy-surface rounded-lg p-6 border border-academy-gold/30 mb-6 space-y-4"
	>
		<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
			<div class="md:col-span-2">
				<label for="n-titel" class="block text-sm text-academy-parchment mb-1">
					Name der Fakultät
				</label>
				<input
					id="n-titel"
					type="text"
					bind:value={neuTitel}
					required
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					placeholder="z. B. Orden der Stillen Wasser"
				/>
				<p class="text-xs text-academy-steel mt-1">Steht groß über der Fakultät.</p>
			</div>
			<div>
				<label for="n-name" class="block text-sm text-academy-parchment mb-1">
					Fach oder Jahrgang
				</label>
				<input
					id="n-name"
					type="text"
					bind:value={neuName}
					required
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					placeholder="z. B. Religion, Klasse 7"
				/>
				<p class="text-xs text-academy-steel mt-1">Steht klein als Untertitel darunter.</p>
			</div>
			<div>
				<label for="n-typ" class="block text-sm text-academy-parchment mb-1">Art</label>
				<select
					id="n-typ"
					bind:value={neuTyp}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				>
					<option value="fach">📖 Fach</option>
					<option value="klassenstufe">🎓 Jahrgang</option>
					<option value="allgemein">✦ Allgemein</option>
				</select>
			</div>
			<div>
				<label for="n-motto" class="block text-sm text-academy-parchment mb-1">Wahlspruch</label>
				<input
					id="n-motto"
					type="text"
					bind:value={neuMotto}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					placeholder="z. B. Wer fragt, geht weiter"
				/>
			</div>
			<div class="grid grid-cols-2 gap-3">
				<div>
					<label for="n-farbe" class="block text-sm text-academy-parchment mb-1">Farbe</label>
					<input
						id="n-farbe"
						type="color"
						bind:value={neuFarbe}
						class="w-full h-10 rounded bg-academy-bg border border-academy-blue/50 cursor-pointer"
					/>
				</div>
				<div>
					<label for="n-farbe2" class="block text-sm text-academy-parchment mb-1">Zierfarbe</label>
					<input
						id="n-farbe2"
						type="color"
						bind:value={neuFarbeZwei}
						class="w-full h-10 rounded bg-academy-bg border border-academy-blue/50 cursor-pointer"
					/>
				</div>
			</div>
			<div class="md:col-span-2">
				<label for="n-desc" class="block text-sm text-academy-parchment mb-1">Beschreibung</label>
				<textarea
					id="n-desc"
					bind:value={neuBeschreibung}
					rows={2}
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				></textarea>
			</div>
		</div>
		<button
			type="submit"
			disabled={speichert}
			class="px-6 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm disabled:opacity-50"
		>
			{speichert ? 'Wird gegründet…' : 'Fakultät gründen'}
		</button>
	</form>
{/if}

{#if loading}
	<div class="text-academy-steel">Lade Fakultäten…</div>
{:else if bereiche.length === 0}
	<div class="text-center py-12 text-academy-steel">
		<div class="text-4xl mb-4">✦</div>
		<p>Noch keine Fakultät gegründet.</p>
		<p class="text-sm mt-2">
			Eine Fakultät fasst die Häuser eines Kurses zusammen – etwa „Orden der Stillen Wasser“ für
			Religion in Klasse 7.
		</p>
	</div>
{:else}
	<div class="space-y-3">
		{#each bereiche as bereich (bereich.id)}
			<div
				class="bg-academy-surface rounded-lg border border-academy-blue/30 overflow-hidden"
				style="border-left: 4px solid {bereich.farbe_primär || '#24406a'}"
			>
				<div class="flex flex-wrap items-center justify-between gap-3 p-4">
					<a
						href="{base}/admin/bereiche/{bereich.slug}"
						class="flex items-center gap-4 min-w-0 flex-1"
					>
						<span class="text-2xl shrink-0" aria-hidden="true">
							{TYP_ZEICHEN[bereich.typ] ?? '✦'}
						</span>
						<span class="min-w-0">
							<span
								class="block font-heading text-lg text-academy-parchment truncate"
								style="color: {bereich.farbe_sekundär || '#ece2d0'}"
							>
								{anzeigeTitel(bereich)}
							</span>
							<span class="block text-xs text-academy-steel truncate">
								{zeile(bereich)}
							</span>
							{#if bereich.motto}
								<span class="block text-xs text-academy-steel italic mt-0.5 truncate">
									„{bereich.motto}“
								</span>
							{/if}
						</span>
					</a>
					<div class="flex items-center gap-2 shrink-0">
						<button
							onclick={() => bearbeiten(bereich)}
							class="px-3 py-1.5 text-xs rounded border border-academy-gold/40 text-academy-gold"
						>
							Umbenennen
						</button>
						<button
							onclick={() => loeschenFragen(bereich)}
							class="px-3 py-1.5 text-xs rounded border border-red-700/40 text-red-300"
						>
							Auflösen
						</button>
					</div>
				</div>

				{#if bearbeiteId === bereich.id}
					<form
						onsubmit={bearbeitenSpeichern}
						class="border-t border-academy-blue/30 bg-academy-bg/50 p-4 space-y-4"
					>
						<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
							<div class="md:col-span-2">
								<label for="b-titel-{bereich.id}" class="block text-sm text-academy-parchment mb-1">
									Name der Fakultät
								</label>
								<input
									id="b-titel-{bereich.id}"
									type="text"
									bind:value={bTitel}
									required
									class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
								/>
							</div>
							<div>
								<label for="b-name-{bereich.id}" class="block text-sm text-academy-parchment mb-1">
									Fach oder Jahrgang
								</label>
								<input
									id="b-name-{bereich.id}"
									type="text"
									bind:value={bName}
									required
									class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
								/>
							</div>
							<div>
								<label for="b-typ-{bereich.id}" class="block text-sm text-academy-parchment mb-1">
									Art
								</label>
								<select
									id="b-typ-{bereich.id}"
									bind:value={bTyp}
									class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
								>
									<option value="fach">📖 Fach</option>
									<option value="klassenstufe">🎓 Jahrgang</option>
									<option value="allgemein">✦ Allgemein</option>
								</select>
							</div>
							<div>
								<label for="b-motto-{bereich.id}" class="block text-sm text-academy-parchment mb-1">
									Wahlspruch
								</label>
								<input
									id="b-motto-{bereich.id}"
									type="text"
									bind:value={bMotto}
									class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
								/>
							</div>
							<div class="grid grid-cols-2 gap-3">
								<div>
									<label
										for="b-farbe-{bereich.id}"
										class="block text-sm text-academy-parchment mb-1">Farbe</label
									>
									<input
										id="b-farbe-{bereich.id}"
										type="color"
										bind:value={bFarbe}
										class="w-full h-10 rounded bg-academy-bg border border-academy-blue/50 cursor-pointer"
									/>
								</div>
								<div>
									<label
										for="b-farbe2-{bereich.id}"
										class="block text-sm text-academy-parchment mb-1">Zierfarbe</label
									>
									<input
										id="b-farbe2-{bereich.id}"
										type="color"
										bind:value={bFarbeZwei}
										class="w-full h-10 rounded bg-academy-bg border border-academy-blue/50 cursor-pointer"
									/>
								</div>
							</div>
							<div class="md:col-span-2">
								<label for="b-desc-{bereich.id}" class="block text-sm text-academy-parchment mb-1">
									Beschreibung
								</label>
								<textarea
									id="b-desc-{bereich.id}"
									bind:value={bBeschreibung}
									rows={2}
									class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
								></textarea>
							</div>
						</div>
						<div class="flex gap-2">
							<button
								type="submit"
								disabled={speichert}
								class="px-5 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm disabled:opacity-50"
							>
								{speichert ? 'Speichert…' : 'Speichern'}
							</button>
							<button
								type="button"
								onclick={() => (bearbeiteId = null)}
								class="px-5 py-2 rounded border border-academy-blue/50 text-academy-steel text-sm"
							>
								Verwerfen
							</button>
						</div>
					</form>
				{/if}

				{#if loeschId === bereich.id}
					<div class="border-t border-red-800/40 bg-red-950/30 p-4">
						<p class="text-sm text-red-100 font-bold mb-2">
							„{anzeigeTitel(bereich)}“ wirklich auflösen?
						</p>
						{#if loeschUmfang === null}
							<p class="text-sm text-academy-steel">Prüfe, was daran hängt…</p>
						{:else if loeschUmfang.haeuser === 0}
							<p class="text-sm text-academy-steel mb-3">
								An dieser Fakultät hängt kein Haus. Es geht nichts verloren.
							</p>
						{:else}
							<p class="text-sm text-academy-steel mb-3">
								Damit verschwinden auch
								<strong class="text-red-200">{loeschUmfang.haeuser}</strong>
								{loeschUmfang.haeuser === 1 ? 'Haus' : 'Häuser'} und
								<strong class="text-red-200">{loeschUmfang.schueler}</strong>
								{loeschUmfang.schueler === 1 ? 'Eintrag' : 'Einträge'} von Schüler*innen samt ihren Punkten.
								Das lässt sich nicht rückgängig machen.
							</p>
						{/if}
						<div class="flex gap-2">
							<button
								onclick={loeschenAusfuehren}
								disabled={speichert || loeschUmfang === null}
								class="px-4 py-2 rounded bg-red-800 text-red-50 text-sm font-bold disabled:opacity-50"
							>
								Endgültig auflösen
							</button>
							<button
								onclick={() => {
									loeschId = null;
									loeschUmfang = null;
								}}
								class="px-4 py-2 rounded border border-academy-blue/50 text-academy-steel text-sm"
							>
								Behalten
							</button>
						</div>
					</div>
				{/if}
			</div>
		{/each}
	</div>
{/if}
