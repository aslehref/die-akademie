<script lang="ts" module>
	let zaehler = 0;
	function naechsteId() {
		zaehler += 1;
		return `sg${zaehler}`;
	}
</script>

<script lang="ts">
	/**
	 * Ein Stundenglas als Punkteanzeige eines Hauses.
	 *
	 * Der Sand unten zeigt, wie weit das Haus im Vergleich zum
	 * führenden Haus gekommen ist – eine Zahl allein sagt einem Kind
	 * wenig, ein volles Glas neben einem halbleeren sofort alles.
	 *
	 * Bewusst KEIN Wettbewerb nach unten: das schwächste Haus behält
	 * einen sichtbaren Sockel, damit sein Glas nie leer wirkt.
	 */
	let {
		gesammelt = 0,
		verfuegbar = 0,
		spitze = 0,
		farbe = '#24406a',
		zierfarbe = '#d4a74a',
		name = '',
		untertitel = '',
		mitglieder = 0,
		gross = false
	}: {
		gesammelt?: number;
		verfuegbar?: number;
		spitze?: number;
		farbe?: string | null;
		zierfarbe?: string | null;
		name?: string;
		untertitel?: string;
		mitglieder?: number;
		gross?: boolean;
	} = $props();

	const primaer = $derived(farbe || '#24406a');
	const sekundaer = $derived(zierfarbe || '#d4a74a');

	// Anteil am Führenden, mit Sockel. 0 Punkte heißt: eine dünne Lage
	// Sand, kein leeres Glas.
	const anteil = $derived(
		spitze > 0 ? Math.min(1, Math.max(0.06, gesammelt / spitze)) : gesammelt > 0 ? 1 : 0.06
	);

	// Die untere Kammer reicht von y=78 bis y=128.
	const KAMMER_OBEN = 78;
	const KAMMER_UNTEN = 128;
	const sandHoehe = $derived((KAMMER_UNTEN - KAMMER_OBEN) * anteil);
	const sandY = $derived(KAMMER_UNTEN - sandHoehe);

	// Was oben noch liegt, ist das Gegenstück – zusammen bleibt die
	// Menge im Glas gleich, das Bild also stimmig.
	const OBEN_SPITZE = 22;
	const OBEN_NECK = 72;
	const restHoehe = $derived((OBEN_NECK - OBEN_SPITZE) * (1 - anteil) * 0.85);

	// Die Verläufe und Masken brauchen im ganzen Dokument eindeutige
	// Namen. Stehen zwei Gläser nebeneinander und teilen sich eine id,
	// zeigen beide denselben Füllstand.
	const id = naechsteId();
</script>

<div class="flex flex-col items-center text-center">
	<svg
		viewBox="0 0 100 150"
		class={gross ? 'w-36 h-52' : 'w-24 h-36'}
		role="img"
		aria-label="{name}: {gesammelt} Punkte gesammelt, {verfuegbar} verfügbar"
	>
		<defs>
			<clipPath id="unten-{id}">
				<polygon points="50,74 86,126 14,126" />
			</clipPath>
			<clipPath id="oben-{id}">
				<polygon points="14,22 86,22 50,74" />
			</clipPath>
			<linearGradient id="sand-{id}" x1="0" y1="0" x2="0" y2="1">
				<stop offset="0%" stop-color={sekundaer} stop-opacity="0.95" />
				<stop offset="100%" stop-color={sekundaer} stop-opacity="0.6" />
			</linearGradient>
			<linearGradient id="glas-{id}" x1="0" y1="0" x2="1" y2="0">
				<stop offset="0%" stop-color="#ffffff" stop-opacity="0.16" />
				<stop offset="45%" stop-color="#ffffff" stop-opacity="0.03" />
				<stop offset="100%" stop-color="#ffffff" stop-opacity="0.12" />
			</linearGradient>
		</defs>

		<!-- Rahmen oben und unten -->
		<rect
			x="8"
			y="10"
			width="84"
			height="9"
			rx="3"
			fill={primaer}
			stroke={sekundaer}
			stroke-width="1.5"
		/>
		<rect
			x="8"
			y="130"
			width="84"
			height="10"
			rx="3"
			fill={primaer}
			stroke={sekundaer}
			stroke-width="1.5"
		/>
		<rect x="12" y="19" width="4" height="111" fill={primaer} opacity="0.8" />
		<rect x="84" y="19" width="4" height="111" fill={primaer} opacity="0.8" />

		<!-- Glaskörper -->
		<polygon points="14,22 86,22 50,74" fill="url(#glas-{id})" />
		<polygon points="50,74 86,126 14,126" fill="url(#glas-{id})" />

		<!-- Sand, der noch oben liegt -->
		<g clip-path="url(#oben-{id})">
			<rect
				x="0"
				y={OBEN_NECK - restHoehe}
				width="100"
				height={restHoehe + 2}
				fill="url(#sand-{id})"
				opacity="0.55"
			/>
		</g>

		<!-- Rieselnder Faden -->
		{#if anteil < 0.99 && gesammelt > 0}
			<line
				x1="50"
				y1="72"
				x2="50"
				y2={sandY}
				stroke={sekundaer}
				stroke-width="1.4"
				opacity="0.7"
				class="rieselt"
			/>
		{/if}

		<!-- Sand unten -->
		<g clip-path="url(#unten-{id})">
			<rect x="0" y={sandY} width="100" height={sandHoehe + 2} fill="url(#sand-{id})" />
			<!-- kleiner Kegel an der Auftreffstelle -->
			{#if gesammelt > 0}
				<ellipse cx="50" cy={sandY} rx={6 + anteil * 22} ry="3" fill={sekundaer} opacity="0.85" />
			{/if}
		</g>

		<!-- Glaskanten zuletzt, damit sie über dem Sand liegen -->
		<polygon
			points="14,22 86,22 50,74 86,126 14,126 50,74"
			fill="none"
			stroke={sekundaer}
			stroke-width="1.6"
			stroke-linejoin="round"
			opacity="0.9"
		/>
	</svg>

	{#if name}
		<div class="font-heading {gross ? 'text-lg' : 'text-sm'} mt-1" style="color: {sekundaer}">
			{name}
		</div>
	{/if}
	{#if untertitel}
		<div class="text-xs text-academy-steel">{untertitel}</div>
	{/if}

	<div class="mt-2 leading-tight">
		<div class="font-heading {gross ? 'text-3xl' : 'text-2xl'} text-academy-gold">
			{gesammelt.toLocaleString('de-DE')}
		</div>
		<div class="text-[0.65rem] uppercase tracking-[0.2em] text-academy-steel">gesammelt</div>
	</div>

	<div class="mt-1 text-xs text-academy-steel">
		<span class="text-academy-cyan font-bold">{verfuegbar.toLocaleString('de-DE')}</span> verfügbar
		{#if mitglieder > 0}
			· {mitglieder}
			{mitglieder === 1 ? 'Mitglied' : 'Mitglieder'}
		{/if}
	</div>
</div>

<style>
	@keyframes rieseln {
		0%,
		100% {
			opacity: 0.25;
		}
		50% {
			opacity: 0.8;
		}
	}
	.rieselt {
		animation: rieseln 1.6s ease-in-out infinite;
	}
	@media (prefers-reduced-motion: reduce) {
		.rieselt {
			animation: none;
		}
	}
</style>
