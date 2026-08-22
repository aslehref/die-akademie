<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import {
		getCurrentUser,
		getMeldungen,
		meldungErledigen,
		getEinreichungen,
		heldentatAnerkennen,
		heldentatAblehnen
	} from '$lib/supabase.js';
	import { bildLinks } from '$lib/bilder.js';

	// Das Postfach. Hier läuft zusammen, was die Kinder getan haben:
	// eingelöste Privilegien (schon geschehen, kann zurückgenommen
	// werden) und eingereichte Heldentaten (warten auf eine Entscheidung).

	let lehrerId = $state<string | null>(null);
	let meldungen = $state<any[]>([]);
	let einreichungen = $state<any[]>([]);
	let bildLink = $state<Record<string, string>>({});
	let zeigeErledigte = $state(false);
	let laedt = $state(true);
	let fehler = $state('');
	let arbeitet = $state('');

	// Bewertung je Einreichung
	let punkte = $state<Record<string, number>>({});
	let wort = $state<Record<string, string>>({});

	const TYP_ZEICHEN: Record<string, string> = {
		einloesung: '🛒',
		heldentat: '✨'
	};

	onMount(laden);

	async function laden() {
		laedt = true;
		fehler = '';
		try {
			const user = await getCurrentUser();
			lehrerId = user?.id ?? null;

			const [m, e] = await Promise.all([getMeldungen(!zeigeErledigte), getEinreichungen()]);
			if (m.error) throw m.error;
			if (e.error) throw e.error;
			meldungen = m.data ?? [];
			einreichungen = e.data ?? [];

			for (const h of einreichungen) {
				if (punkte[h.id] === undefined) punkte[h.id] = 10;
				if (wort[h.id] === undefined) wort[h.id] = '';
			}

			const pfade = einreichungen.flatMap((h) => h.bilder ?? []);
			if (pfade.length > 0) bildLink = await bildLinks(pfade);
		} catch (e: any) {
			fehler = e?.message ?? 'Das Postfach ließ sich nicht öffnen.';
		} finally {
			laedt = false;
		}
	}

	async function abhaken(m: any) {
		arbeitet = m.id;
		const { error } = await meldungErledigen(m.id, lehrerId);
		arbeitet = '';
		if (error) fehler = error.message;
		else await laden();
	}

	async function anerkennen(h: any) {
		arbeitet = h.id;
		fehler = '';
		const { error } = await heldentatAnerkennen(h, punkte[h.id] ?? 0, wort[h.id] ?? '', lehrerId);
		arbeitet = '';
		if (error) fehler = error.message;
		else await laden();
	}

	async function ablehnen(h: any) {
		arbeitet = h.id;
		fehler = '';
		const { error } = await heldentatAblehnen(h.id, wort[h.id] ?? '', lehrerId);
		arbeitet = '';
		if (error) fehler = error.message;
		else await laden();
	}

	function datum(s: string) {
		return new Date(s).toLocaleString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			hour: '2-digit',
			minute: '2-digit'
		});
	}
</script>

<div class="flex flex-wrap items-end justify-between gap-3 mb-6">
	<div>
		<h2 class="text-2xl font-heading text-academy-gold">Postfach</h2>
		<p class="text-sm text-academy-steel mt-1">
			Was die Kinder getan haben – und was auf deine Entscheidung wartet.
		</p>
	</div>
	<label class="flex items-center gap-2 text-sm text-academy-steel">
		<input
			type="checkbox"
			bind:checked={zeigeErledigte}
			onchange={laden}
			class="accent-[color:var(--color-academy-gold)]"
		/>
		auch Erledigtes zeigen
	</label>
</div>

{#if fehler}
	<div class="mb-6 bg-red-900/30 border border-red-700/50 text-red-200 p-4 rounded text-sm">
		{fehler}
	</div>
{/if}

{#if laedt}
	<p class="text-academy-steel">Lade…</p>
{:else}
	<!-- Wartet auf Entscheidung -->
	<section class="mb-10">
		<h3 class="text-xl font-heading text-academy-gold mb-3">
			Eingereichte Heldentaten
			{#if einreichungen.length > 0}
				<span class="text-sm text-academy-cyan">({einreichungen.length})</span>
			{/if}
		</h3>

		{#if einreichungen.length === 0}
			<p
				class="text-academy-steel text-sm bg-academy-surface border border-academy-blue/25 rounded-lg p-5"
			>
				Nichts offen. Was Kinder einreichen, erscheint hier.
			</p>
		{:else}
			<div class="space-y-4">
				{#each einreichungen as h (h.id)}
					<article class="bg-academy-surface rounded-lg border border-academy-gold/30 p-5">
						<div class="flex flex-wrap justify-between gap-3">
							<div class="min-w-0">
								<h4 class="font-heading text-lg text-academy-gold">{h.titel}</h4>
								<p class="text-xs text-academy-steel">
									{h.kind?.akademiename ?? 'Unbekannt'} · {h.haus?.hausname ?? ''} ·
									{datum(h.created_at)}
								</p>
							</div>
						</div>

						{#if h.beschreibung}
							<p class="text-academy-parchment text-sm mt-3 whitespace-pre-line">
								{h.beschreibung}
							</p>
						{/if}

						{#if (h.bilder ?? []).length > 0}
							<div class="flex gap-2 mt-3 flex-wrap">
								{#each h.bilder as pfad}
									{#if bildLink[pfad]}
										<a href={bildLink[pfad]} target="_blank" rel="noopener">
											<img
												src={bildLink[pfad]}
												alt=""
												class="w-28 h-28 object-cover rounded border border-academy-blue/30"
											/>
										</a>
									{/if}
								{/each}
							</div>
						{/if}

						<div
							class="mt-4 pt-4 border-t border-academy-blue/25 grid gap-3 sm:grid-cols-[8rem_1fr_auto] sm:items-end"
						>
							<div>
								<label for="p-{h.id}" class="block text-xs text-academy-parchment mb-1">
									Punkte
								</label>
								<input
									id="p-{h.id}"
									type="number"
									min="0"
									max="500"
									bind:value={punkte[h.id]}
									class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
								/>
							</div>
							<div>
								<label for="w-{h.id}" class="block text-xs text-academy-parchment mb-1">
									Rückmeldung an das Kind
								</label>
								<input
									id="w-{h.id}"
									type="text"
									bind:value={wort[h.id]}
									maxlength="200"
									placeholder="optional – ein Satz genügt"
									class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
								/>
							</div>
							<div class="flex gap-2">
								<button
									onclick={() => anerkennen(h)}
									disabled={arbeitet === h.id}
									class="px-4 py-2 rounded bg-academy-gold text-academy-bg font-bold text-sm disabled:opacity-50"
								>
									Anerkennen
								</button>
								<button
									onclick={() => ablehnen(h)}
									disabled={arbeitet === h.id}
									class="px-4 py-2 rounded border border-academy-steel/50 text-academy-steel text-sm disabled:opacity-50"
								>
									Ablehnen
								</button>
							</div>
						</div>
					</article>
				{/each}
			</div>
		{/if}
	</section>

	<!-- Meldungen -->
	<section>
		<h3 class="text-xl font-heading text-academy-gold mb-3">Meldungen</h3>
		{#if meldungen.length === 0}
			<p
				class="text-academy-steel text-sm bg-academy-surface border border-academy-blue/25 rounded-lg p-5"
			>
				{zeigeErledigte ? 'Noch keine Meldungen.' : 'Alles abgehakt.'}
			</p>
		{:else}
			<div class="space-y-2">
				{#each meldungen as m (m.id)}
					<div
						class="flex flex-wrap items-center justify-between gap-3 p-4 rounded-lg bg-academy-surface border border-academy-blue/25"
						class:opacity-50={m.erledigt}
					>
						<div class="flex items-start gap-3 min-w-0">
							<span class="text-xl shrink-0" aria-hidden="true">{TYP_ZEICHEN[m.typ] ?? '•'}</span>
							<div class="min-w-0">
								<div class="text-academy-parchment">{m.titel}</div>
								<div class="text-xs text-academy-steel">
									{datum(m.created_at)}
									{#if m.beschreibung}
										· {m.beschreibung}
									{/if}
									{#if m.lehrer_id === lehrerId}
										· <span class="text-academy-cyan">dein Haus</span>
									{/if}
								</div>
							</div>
						</div>
						{#if !m.erledigt}
							<button
								onclick={() => abhaken(m)}
								disabled={arbeitet === m.id}
								class="px-3 py-1.5 text-xs rounded border border-academy-gold/40 text-academy-gold disabled:opacity-50 shrink-0"
							>
								Gesehen
							</button>
						{/if}
					</div>
				{/each}
			</div>
		{/if}

		<p class="text-xs text-academy-steel mt-4">
			Ein Privileg, das ein Kind selbst eingelöst hat, gilt sofort. Zurücknehmen kannst du es im
			<a href="{base}/dashboard/markt" class="underline">Markt</a> – die Punkte sind dann wieder da.
		</p>
	</section>
{/if}
