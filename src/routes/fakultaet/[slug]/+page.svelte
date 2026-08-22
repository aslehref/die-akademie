<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import {
		supabase,
		getCurrentUser,
		getUserRole,
		getStundenglaeser,
		getWochenquest,
		type UserRole
	} from '$lib/supabase.js';
	import type { Stundenglas as Glas } from '$lib/supabase.js';
	import {
		meineDaten,
		heldentatEinreichen,
		meineEinreichungen,
		heldentatenDerFakultaet,
		type MeineDaten
	} from '$lib/meins.js';
	import { ladeBildHoch, pruefeBild, bildLinks } from '$lib/bilder.js';
	import Stundenglas from '$lib/Stundenglas.svelte';

	// Diese Seite ist der Kursbereich und braucht KEINE Anmeldung.
	// Wer hereinschaut, sieht die Stundengläser und die laufende Quest –
	// das ist der Aushang, nicht die Akte.
	//
	// Ist ein Kind angemeldet und ist dies SEINE Fakultät, kommt der
	// Handlungsteil dazu: sein Haus, sein Guthaben, sein Einreichen.
	// In fremden Fakultäten bleibt es Zuschauer.

	let bereich = $state<any>(null);
	let glaeser = $state<Glas[]>([]);
	let quest = $state<any>(null);
	let loading = $state(true);
	let fehler = $state('');

	let rolle = $state<UserRole | null>(null);
	let ich = $state<MeineDaten | null>(null);

	let heldentaten = $state<any[]>([]);
	let eigene = $state<any[]>([]);
	let bildLink = $state<Record<string, string>>({});

	// Einreichen
	let formularOffen = $state(false);
	let eTitel = $state('');
	let eText = $state('');
	let eDateien = $state<File[]>([]);
	let eFehler = $state('');
	let eMeldung = $state('');
	let sendet = $state(false);

	const spitze = $derived(Math.max(0, ...glaeser.map((g) => g.gesammelt ?? 0)));
	const gesamtVerfuegbar = $derived(glaeser.reduce((s, g) => s + (g.verfuegbar ?? 0), 0));

	// Gehört das Kind hierher? Das entscheidet, ob es hier handeln darf.
	const meineFakultaet = $derived(!!ich && !!bereich && ich.bereich.id === bereich.id);

	const meinGlas = $derived(ich ? (glaeser.find((g) => g.haus_id === ich!.haus.id) ?? null) : null);

	function titelVon(b: any) {
		return b?.titel?.trim() || b?.name || 'Fakultät';
	}

	const STATUS_TEXT: Record<string, string> = {
		eingereicht: '⏳ wartet auf die Lehrkraft',
		sichtbar: '✓ anerkannt',
		abgelehnt: '– nicht angenommen'
	};

	onMount(laden);

	async function laden() {
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

			const [gErgebnis, qErgebnis, user] = await Promise.all([
				getStundenglaeser(b.id),
				getWochenquest(b.id),
				getCurrentUser()
			]);
			if (gErgebnis.error) throw gErgebnis.error;
			glaeser = (gErgebnis.data ?? []) as Glas[];
			quest = qErgebnis.data;

			if (user) {
				rolle = await getUserRole(user.id);
				if (rolle === 'schueler') ich = await meineDaten(user.id);
			}

			// Heldentaten sind nur für Angemeldete lesbar, und für Kinder
			// nur die der eigenen Fakultät. Ein Fehler hier darf die Seite
			// nicht kippen – dann bleibt der Abschnitt eben leer.
			if (user) await ladeHeldentaten();
		} catch (e: any) {
			fehler = e?.message ?? 'Die Akademie ist gerade nicht erreichbar.';
		} finally {
			loading = false;
		}
	}

	async function ladeHeldentaten() {
		const ids = glaeser.map((g) => g.haus_id);
		const { data } = await heldentatenDerFakultaet(ids);
		heldentaten = data ?? [];

		if (ich && meineFakultaet) {
			const { data: meine } = await meineEinreichungen(ich.schueler.id);
			eigene = meine ?? [];
		}

		const pfade = [...heldentaten, ...eigene].flatMap((h) => h.bilder ?? []);
		if (pfade.length > 0) bildLink = await bildLinks(pfade);
	}

	function dateienGewaehlt(e: Event) {
		eFehler = '';
		const liste = Array.from((e.target as HTMLInputElement).files ?? []);
		for (const d of liste) {
			const f = pruefeBild(d);
			if (f) {
				eFehler = f;
				return;
			}
		}
		if (liste.length > 4) {
			eFehler = 'Höchstens vier Bilder auf einmal.';
			return;
		}
		eDateien = liste;
	}

	async function einreichen(e: Event) {
		e.preventDefault();
		if (!ich || sendet) return;
		if (eTitel.trim().length < 3) {
			eFehler = 'Gib deiner Heldentat eine Überschrift.';
			return;
		}
		sendet = true;
		eFehler = '';
		eMeldung = '';
		try {
			// Der Ordner ist derselbe, den die Zugriffsregel erlaubt.
			// Steht hier ein anderer Pfad, lehnt die Datenbank den Upload ab.
			const pfade: string[] = [];
			for (const datei of eDateien) {
				pfade.push(await ladeBildHoch(datei, `haeuser/${ich.haus.id}/einreichungen`));
			}

			const { error } = await heldentatEinreichen({
				schuelerId: ich.schueler.id,
				hausId: ich.haus.id,
				titel: eTitel,
				beschreibung: eText,
				bilder: pfade
			});
			if (error) throw error;

			eMeldung =
				'Eingereicht. Deine Lehrkraft sieht es jetzt im Lehrerzimmer und entscheidet über die Punkte.';
			eTitel = '';
			eText = '';
			eDateien = [];
			formularOffen = false;
			await ladeHeldentaten();
		} catch (err: any) {
			eFehler = err?.message ?? 'Das Einreichen ist fehlgeschlagen.';
		} finally {
			sendet = false;
		}
	}
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
			class="mt-4 mb-8 text-center relative overflow-hidden rounded-lg border p-8 bg-academy-surface"
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

		<!-- Bin ich hier zu Hause? -->
		{#if ich && meineFakultaet}
			<section
				class="mb-8 rounded-lg border p-5 bg-academy-surface"
				style="border-color: {(ich.haus.farbe_sekundär || '#d4a74a') + '66'}"
			>
				<div class="flex flex-wrap items-center justify-between gap-4">
					<div>
						<p class="text-xs uppercase tracking-[0.2em] text-academy-steel">Dein Haus</p>
						<p class="font-heading text-2xl" style="color: {ich.haus.farbe_sekundär || '#d4a74a'}">
							{ich.haus.hausname}
						</p>
						<p class="text-sm text-academy-steel">als {ich.schueler.akademiename}</p>
					</div>
					<div class="flex gap-4 text-center">
						<div>
							<div class="font-heading text-2xl text-academy-gold">{ich.schueler.punkte}</div>
							<div class="text-[0.65rem] uppercase tracking-[0.15em] text-academy-steel">
								dein Guthaben
							</div>
						</div>
						<div>
							<div class="font-heading text-2xl text-academy-cyan">{ich.schueler.xp}</div>
							<div class="text-[0.65rem] uppercase tracking-[0.15em] text-academy-steel">
								Erfahrung
							</div>
						</div>
						<div>
							<div class="font-heading text-2xl text-academy-parchment">{ich.schueler.level}</div>
							<div class="text-[0.65rem] uppercase tracking-[0.15em] text-academy-steel">Stufe</div>
						</div>
					</div>
					<div class="flex gap-2">
						<a
							href="{base}/dashboard/markt"
							class="px-4 py-2 rounded bg-academy-gold text-academy-bg font-bold text-sm"
						>
							Zum Markt
						</a>
						<button
							onclick={() => (formularOffen = !formularOffen)}
							class="px-4 py-2 rounded border border-academy-gold/50 text-academy-gold text-sm"
						>
							{formularOffen ? 'Abbrechen' : 'Heldentat einreichen'}
						</button>
					</div>
				</div>

				{#if eMeldung}
					<div
						class="mt-4 bg-academy-green/25 border border-academy-green text-academy-parchment p-3 rounded text-sm"
					>
						{eMeldung}
					</div>
				{/if}

				{#if formularOffen}
					<form onsubmit={einreichen} class="mt-5 pt-5 border-t border-academy-blue/30 space-y-4">
						<p class="text-sm text-academy-steel">
							Erzähl, was du geschafft hast. Deine Lehrkraft liest es und entscheidet, wie viele
							Punkte es wert ist.
						</p>
						{#if eFehler}
							<div class="bg-red-900/30 border border-red-700/50 text-red-200 p-3 rounded text-sm">
								{eFehler}
							</div>
						{/if}
						<div>
							<label for="e-titel" class="block text-sm text-academy-parchment mb-1">
								Überschrift
							</label>
							<input
								id="e-titel"
								type="text"
								bind:value={eTitel}
								required
								maxlength="120"
								class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
								placeholder="z. B. Ich habe der Klasse vorgelesen"
							/>
						</div>
						<div>
							<label for="e-text" class="block text-sm text-academy-parchment mb-1">
								Was ist passiert?
							</label>
							<textarea
								id="e-text"
								bind:value={eText}
								rows={3}
								maxlength="1000"
								class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
							></textarea>
						</div>
						<div>
							<label for="e-bilder" class="block text-sm text-academy-parchment mb-1">
								Bilder dazu (bis zu vier)
							</label>
							<input
								id="e-bilder"
								type="file"
								accept="image/*"
								multiple
								onchange={dateienGewaehlt}
								class="w-full text-sm text-academy-steel file:mr-3 file:px-3 file:py-1.5 file:rounded file:border-0 file:bg-academy-blue/40 file:text-academy-parchment"
							/>
							{#if eDateien.length > 0}
								<p class="text-xs text-academy-steel mt-1">
									{eDateien.length}
									{eDateien.length === 1 ? 'Bild' : 'Bilder'} ausgewählt
								</p>
							{/if}
						</div>
						<button
							type="submit"
							disabled={sendet}
							class="px-5 py-2 rounded bg-academy-gold text-academy-bg font-bold text-sm disabled:opacity-50"
						>
							{sendet ? 'Wird gesendet…' : 'Einreichen'}
						</button>
					</form>
				{/if}
			</section>

			{#if eigene.length > 0}
				<section class="mb-10">
					<h2 class="text-xl font-heading text-academy-gold mb-3">Deine Einreichungen</h2>
					<div class="space-y-2">
						{#each eigene as h (h.id)}
							<div
								class="bg-academy-surface rounded-lg border border-academy-blue/25 p-4 flex flex-wrap items-start justify-between gap-3"
							>
								<div class="min-w-0">
									<div class="text-academy-parchment font-bold">{h.titel}</div>
									{#if h.beschreibung}
										<p class="text-sm text-academy-steel">{h.beschreibung}</p>
									{/if}
									{#if h.rueckmeldung}
										<p class="text-sm text-academy-cyan mt-1">„{h.rueckmeldung}“</p>
									{/if}
								</div>
								<div class="text-right shrink-0">
									<div class="text-xs text-academy-steel">
										{STATUS_TEXT[h.status] ?? h.status}
									</div>
									{#if h.punkte > 0}
										<div class="text-academy-gold font-bold">+{h.punkte}</div>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				</section>
			{/if}
		{:else if ich}
			<!-- Ein Kind aus einer anderen Fakultät: sehen ja, mitmachen nein. -->
			<div
				class="mb-8 rounded-lg border border-academy-blue/30 bg-academy-surface p-5 text-sm text-academy-steel"
			>
				Du gehörst zu <a href="{base}/fakultaet/{ich.bereich.slug}" class="font-bold"
					>{ich.bereich.titel?.trim() || ich.bereich.name}</a
				>. Hier darfst du zuschauen, einreichen und einlösen kannst du nur in deiner eigenen
				Fakultät.
			</div>
		{:else if rolle === 'admin' || rolle === 'teacher'}
			<div class="mb-8 text-sm">
				<a href="{base}/admin/bereiche/{bereich.slug}" class="underline">
					Diese Fakultät im Lehrerzimmer verwalten →
				</a>
			</div>
		{/if}

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
							style="border-color: {(g.haus_id === meinGlas?.haus_id
								? g.farbe_sekundaer || '#d4a74a'
								: g.farbe_primaer || '#24406a') + (g.haus_id === meinGlas?.haus_id ? 'cc' : '66')}"
						>
							<Stundenglas
								gesammelt={g.gesammelt}
								verfuegbar={g.verfuegbar}
								mitglieder={g.mitglieder}
								{spitze}
								farbe={g.farbe_primaer}
								zierfarbe={g.farbe_sekundaer}
								name={g.hausname}
								untertitel={g.haus_id === meinGlas?.haus_id ? 'dein Haus' : (g.motto ?? '')}
								gross={glaeser.length <= 3}
							/>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Anerkannte Heldentaten -->
		{#if heldentaten.length > 0}
			<section class="mb-10">
				<h2 class="text-2xl font-heading text-academy-gold mb-4">Heldentaten</h2>
				<div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
					{#each heldentaten as h (h.id)}
						<article class="bg-academy-surface rounded-lg border border-academy-blue/25 p-4">
							<h3 class="font-heading text-academy-gold">{h.titel}</h3>
							{#if h.beschreibung}
								<p class="text-sm text-academy-steel mt-1">{h.beschreibung}</p>
							{/if}
							{#if (h.bilder ?? []).length > 0}
								<div class="flex gap-2 mt-3 flex-wrap">
									{#each h.bilder as pfad}
										{#if bildLink[pfad]}
											<img
												src={bildLink[pfad]}
												alt=""
												class="w-20 h-20 object-cover rounded border border-academy-blue/30"
											/>
										{/if}
									{/each}
								</div>
							{/if}
							<p class="text-xs text-academy-steel mt-3">
								{new Date(h.geschehen_am).toLocaleDateString('de-DE')}
								{#if h.punkte > 0}
									· <span class="text-academy-gold">+{h.punkte} Punkte</span>
								{/if}
							</p>
						</article>
					{/each}
				</div>
			</section>
		{/if}

		<!-- Türen, nur für Gäste -->
		{#if !rolle}
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
	{/if}
</div>
