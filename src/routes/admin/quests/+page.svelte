<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase, createQuest, updateQuest, deleteQuest } from '$lib/supabase.js';

	let quests = $state<any[]>([]);
	let bereiche = $state<any[]>([]);
	let laedt = $state(true);
	let fehler = $state('');
	let meldung = $state('');
	let arbeitet = $state(false);

	let formularOffen = $state(false);
	let bearbeiteId = $state<string | null>(null);

	let fTitel = $state('');
	let fText = $state('');
	let fSchwierigkeit = $state(3);
	let fHauspunkte = $state(50);
	let fXp = $state(100);
	let fBereich = $state('');
	let fStart = $state('');
	let fEnde = $state('');

	const STATUS: Record<string, { label: string; farbe: string }> = {
		entwurf: { label: 'Entwurf', farbe: 'text-academy-steel border-academy-steel/40' },
		aktiv: { label: 'Läuft', farbe: 'text-academy-gold border-academy-gold/50' },
		abgeschlossen: { label: 'Bestanden', farbe: 'text-academy-cyan border-academy-cyan/50' },
		archiviert: { label: 'Archiviert', farbe: 'text-academy-steel border-academy-steel/25' }
	};

	onMount(async () => {
		const heute = new Date();
		fStart = heute.toISOString().slice(0, 10);
		fEnde = new Date(heute.getTime() + 7 * 864e5).toISOString().slice(0, 10);
		await laden();
	});

	async function laden() {
		laedt = true;
		fehler = '';
		try {
			const [q, b] = await Promise.all([
				supabase
					.from('quests')
					.select('*, bereich:bereich_id(name)')
					.order('startdatum', { ascending: false }),
				supabase.from('bereiche').select('id, name').order('name')
			]);
			if (q.error) throw q.error;
			quests = q.data ?? [];
			bereiche = b.data ?? [];
		} catch (e: any) {
			fehler = e?.message ?? 'Die Quests konnten nicht geladen werden.';
		} finally {
			laedt = false;
		}
	}

	function neueQuest() {
		bearbeiteId = null;
		fTitel = '';
		fText = '';
		fSchwierigkeit = 3;
		fHauspunkte = 50;
		fXp = 100;
		fBereich = '';
		const heute = new Date();
		fStart = heute.toISOString().slice(0, 10);
		fEnde = new Date(heute.getTime() + 7 * 864e5).toISOString().slice(0, 10);
		formularOffen = true;
		meldung = '';
	}

	function bearbeiten(q: any) {
		bearbeiteId = q.id;
		fTitel = q.titel;
		fText = q.beschreibung ?? '';
		fSchwierigkeit = q.schwierigkeit;
		fHauspunkte = q.belohnung_hauspunkte;
		fXp = q.belohnung_xp;
		fBereich = q.bereich_id ?? '';
		fStart = q.startdatum?.slice(0, 10) ?? '';
		fEnde = q.enddatum?.slice(0, 10) ?? '';
		formularOffen = true;
		meldung = '';
	}

	async function speichern(e: Event) {
		e.preventDefault();
		arbeitet = true;
		fehler = '';
		try {
			const werte = {
				titel: fTitel.trim(),
				beschreibung: fText.trim(),
				schwierigkeit: fSchwierigkeit,
				belohnung_hauspunkte: fHauspunkte,
				belohnung_xp: fXp,
				gültigkeitsbereich: fBereich ? 'fach' : 'global',
				bereich_id: fBereich || null,
				startdatum: fStart,
				enddatum: fEnde || null
			};

			const { error } = bearbeiteId
				? await updateQuest(bearbeiteId, werte)
				: await createQuest(werte as any);
			if (error) throw error;

			formularOffen = false;
			meldung = bearbeiteId ? 'Quest geändert.' : 'Quest angelegt – noch als Entwurf.';
			bearbeiteId = null;
			await laden();
		} catch (err: any) {
			fehler = err?.message ?? 'Speichern fehlgeschlagen.';
		} finally {
			arbeitet = false;
		}
	}

	async function statusSetzen(q: any, status: string) {
		arbeitet = true;
		fehler = '';
		const { error } = await updateQuest(q.id, { status });
		arbeitet = false;
		if (error) fehler = error.message;
		else {
			meldung =
				status === 'aktiv'
					? `„${q.titel}“ läuft jetzt und erscheint auf der Startseite.`
					: 'Status geändert.';
			await laden();
		}
	}

	async function entfernen(q: any) {
		if (!confirm(`„${q.titel}“ wirklich löschen?`)) return;
		const { error } = await deleteQuest(q.id);
		if (error) fehler = error.message;
		else await laden();
	}

	function datum(s: string | null) {
		return s ? new Date(s).toLocaleDateString('de-DE') : '—';
	}

	const eingabe =
		'w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none';
</script>

<svelte:head>
	<title>Quests · Die Akademie</title>
</svelte:head>

<div class="flex items-center justify-between mb-4 flex-wrap gap-3">
	<div>
		<h2 class="text-2xl font-heading text-academy-gold">Quests</h2>
		<p class="text-sm text-academy-steel">
			Eine laufende Quest erscheint auf der Startseite als Wochenquest.
		</p>
	</div>
	<button
		onclick={() => (formularOffen ? (formularOffen = false) : neueQuest())}
		class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm"
	>
		{formularOffen ? 'Abbrechen' : '+ Neue Quest'}
	</button>
</div>

{#if meldung}
	<div
		class="bg-academy-green/30 border border-academy-green text-academy-parchment p-3 rounded mb-4"
	>
		{meldung}
	</div>
{/if}
{#if fehler}
	<div class="bg-red-900/30 border border-red-700/50 text-red-200 p-3 rounded mb-4">{fehler}</div>
{/if}

{#if formularOffen}
	<form
		onsubmit={speichern}
		class="bg-academy-surface rounded-lg p-5 border border-academy-gold/40 mb-6 space-y-4"
	>
		<h3 class="font-heading text-academy-gold">
			{bearbeiteId ? 'Quest ändern' : 'Eine neue Quest ausrufen'}
		</h3>

		<div>
			<label for="q-titel" class="block text-sm text-academy-parchment mb-1">Titel</label>
			<input
				id="q-titel"
				type="text"
				bind:value={fTitel}
				required
				class={eingabe}
				placeholder="z.B. Die Bibliothek des Wissens"
			/>
		</div>

		<div>
			<label for="q-text" class="block text-sm text-academy-parchment mb-1">Die Aufgabe</label>
			<textarea
				id="q-text"
				bind:value={fText}
				rows="3"
				required
				class={eingabe}
				placeholder="Was genau ist zu tun? Formuliere es so, dass es ohne Rückfrage verständlich ist."
			></textarea>
		</div>

		<div class="grid grid-cols-1 md:grid-cols-3 gap-3">
			<div>
				<label for="q-schwer" class="block text-sm text-academy-parchment mb-1">
					Schwierigkeit: {'⭐'.repeat(fSchwierigkeit)}
				</label>
				<input
					id="q-schwer"
					type="range"
					min="1"
					max="5"
					bind:value={fSchwierigkeit}
					class="w-full accent-academy-gold"
				/>
			</div>
			<div>
				<label for="q-hp" class="block text-sm text-academy-parchment mb-1">Hauspunkte</label>
				<input id="q-hp" type="number" min="0" bind:value={fHauspunkte} class={eingabe} />
			</div>
			<div>
				<label for="q-xp" class="block text-sm text-academy-parchment mb-1">Erfahrung (XP)</label>
				<input id="q-xp" type="number" min="0" bind:value={fXp} class={eingabe} />
			</div>
		</div>

		<div class="grid grid-cols-1 md:grid-cols-3 gap-3">
			<div>
				<label for="q-start" class="block text-sm text-academy-parchment mb-1">Beginn</label>
				<input id="q-start" type="date" bind:value={fStart} required class={eingabe} />
			</div>
			<div>
				<label for="q-ende" class="block text-sm text-academy-parchment mb-1">Ende</label>
				<input id="q-ende" type="date" bind:value={fEnde} class={eingabe} />
			</div>
			<div>
				<label for="q-fak" class="block text-sm text-academy-parchment mb-1">Fakultät</label>
				<select id="q-fak" bind:value={fBereich} class={eingabe}>
					<option value="">Gilt für die ganze Akademie</option>
					{#each bereiche as b}
						<option value={b.id}>{b.name}</option>
					{/each}
				</select>
			</div>
		</div>

		<p class="text-xs text-academy-steel">
			Die Hauspunkte zählen für den Hauspokal, die Erfahrung nur für das Kind. Beim Abschließen
			werden beide getrennt gebucht.
		</p>

		<button
			type="submit"
			disabled={arbeitet}
			class="px-4 py-2 bg-academy-gold text-academy-bg rounded font-bold text-sm disabled:opacity-50"
		>
			{arbeitet ? 'Speichere…' : bearbeiteId ? 'Änderungen speichern' : 'Quest anlegen'}
		</button>
	</form>
{/if}

{#if laedt}
	<div class="text-academy-steel">Lade Quests…</div>
{:else if quests.length === 0}
	<div
		class="text-center py-12 text-academy-steel bg-academy-surface rounded-lg border border-academy-blue/20"
	>
		<div class="text-4xl mb-3">⚔️</div>
		<p>Noch keine Quest ausgerufen.</p>
		<p class="text-sm mt-2">
			Eine gute erste Quest ist gemeinsam lösbar und in einer Woche zu schaffen.
		</p>
	</div>
{:else}
	<div class="space-y-3">
		{#each quests as q}
			<article
				class="bg-academy-surface rounded-lg p-5 border {q.status === 'aktiv'
					? 'border-academy-gold/50'
					: 'border-academy-blue/25'}"
			>
				<div class="flex items-start justify-between gap-4 flex-wrap">
					<div class="flex-1 min-w-[16rem]">
						<div class="flex items-center gap-3 flex-wrap">
							<h3 class="font-heading text-academy-parchment font-bold">{q.titel}</h3>
							<span
								class="text-xs px-2 py-0.5 rounded-full border {STATUS[q.status]?.farbe ??
									'text-academy-steel border-academy-steel/40'}"
							>
								{STATUS[q.status]?.label ?? q.status}
							</span>
						</div>
						<p class="text-sm text-academy-steel mt-1">{q.beschreibung}</p>
						<div class="flex items-center gap-3 mt-2 text-xs flex-wrap">
							<span class="text-academy-gold">{'⭐'.repeat(q.schwierigkeit)}</span>
							<span class="text-academy-cyan">+{q.belohnung_hauspunkte} Hauspunkte</span>
							<span class="text-academy-cyan">+{q.belohnung_xp} XP</span>
							<span class="text-academy-steel">
								{datum(q.startdatum)} – {datum(q.enddatum)}
							</span>
							<span class="text-academy-steel">
								{q.bereich?.name ?? 'ganze Akademie'}
							</span>
						</div>
					</div>

					<div class="flex flex-wrap gap-2 shrink-0">
						{#if q.status !== 'aktiv'}
							<button
								onclick={() => statusSetzen(q, 'aktiv')}
								disabled={arbeitet}
								class="text-xs px-3 py-1.5 rounded bg-academy-gold text-academy-bg font-bold disabled:opacity-50"
							>
								Ausrufen
							</button>
						{:else}
							<button
								onclick={() => statusSetzen(q, 'abgeschlossen')}
								disabled={arbeitet}
								class="text-xs px-3 py-1.5 rounded border border-academy-cyan/60 text-academy-cyan disabled:opacity-50"
							>
								Bestanden
							</button>
						{/if}
						{#if q.status !== 'archiviert'}
							<button
								onclick={() => statusSetzen(q, 'archiviert')}
								disabled={arbeitet}
								class="text-xs px-3 py-1.5 rounded border border-academy-steel/40 text-academy-steel"
							>
								Archivieren
							</button>
						{/if}
						<button
							onclick={() => bearbeiten(q)}
							class="text-xs px-3 py-1.5 rounded border border-academy-blue/50 text-academy-parchment"
						>
							Ändern
						</button>
						<button
							onclick={() => entfernen(q)}
							class="text-xs px-3 py-1.5 rounded border border-red-800/60 text-red-300"
						>
							Löschen
						</button>
					</div>
				</div>
			</article>
		{/each}
	</div>
{/if}
