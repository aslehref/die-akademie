<script lang="ts">
	import { signIn } from '$lib/supabase';
	import { schuelerAnmelden } from '$lib/schuelerkonten';
	import { base } from '$app/paths';
	import { goto } from '$app/navigation';

	// Zwei Wege in dieselbe Akademie: Lehrkräfte melden sich mit ihrer
	// E-Mail an, Kinder mit einem Loginnamen. Kinder bekommen bewusst
	// keine E-Mail-Adresse.
	let weg = $state<'lehrkraft' | 'schueler'>('schueler');

	let email = $state('');
	let loginName = $state('');
	let passwort = $state('');
	let fehler = $state('');
	let laedt = $state(false);

	function wechsle(zu: typeof weg) {
		weg = zu;
		fehler = '';
		passwort = '';
	}

	async function anmelden(e: Event) {
		e.preventDefault();
		laedt = true;
		fehler = '';
		try {
			if (weg === 'lehrkraft') {
				const { error } = await signIn(email.trim(), passwort);
				if (error) throw new Error('E-Mail oder Passwort stimmt nicht.');
			} else {
				await schuelerAnmelden(loginName, passwort);
			}
			await goto(`${base}/dashboard`);
		} catch (err: any) {
			fehler = err?.message ?? 'Die Anmeldung hat nicht geklappt.';
			laedt = false;
		}
	}

	const eingabe =
		'w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none';
</script>

<svelte:head>
	<title>Anmelden · Die Akademie</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center px-4">
	<div class="w-full max-w-md py-10">
		<div class="text-center mb-8">
			<div class="text-4xl mb-3" aria-hidden="true">✦</div>
			<h1 class="text-4xl font-heading text-academy-gold mb-2">Die Akademie</h1>
			<hr class="zierlinie my-4 max-w-[12rem] mx-auto" />
			<p class="text-academy-steel italic text-sm">Wissen. Gemeinschaft. Verantwortung.</p>
		</div>

		<div class="bg-academy-surface rounded-lg border border-academy-blue/30 overflow-hidden">
			<!-- Wegwahl -->
			<div class="grid grid-cols-2 border-b border-academy-blue/30">
				<button
					type="button"
					onclick={() => wechsle('schueler')}
					class="py-3 text-sm font-heading transition-colors {weg === 'schueler'
						? 'text-academy-gold bg-academy-blue/20'
						: 'text-academy-steel hover:text-academy-parchment'}"
				>
					🎓 Schüler*in
				</button>
				<button
					type="button"
					onclick={() => wechsle('lehrkraft')}
					class="py-3 text-sm font-heading transition-colors {weg === 'lehrkraft'
						? 'text-academy-gold bg-academy-blue/20'
						: 'text-academy-steel hover:text-academy-parchment'}"
				>
					🕯️ Lehrkraft
				</button>
			</div>

			<form onsubmit={anmelden} class="p-6 space-y-4">
				{#if fehler}
					<div class="bg-red-900/30 border border-red-700/50 text-red-200 p-3 rounded text-sm">
						{fehler}
					</div>
				{/if}

				{#if weg === 'lehrkraft'}
					<div>
						<label for="email" class="block text-sm text-academy-parchment mb-1">E-Mail</label>
						<input
							id="email"
							type="email"
							bind:value={email}
							required
							autocomplete="username"
							class={eingabe}
							placeholder="lehrer@schule.de"
						/>
					</div>
				{:else}
					<div>
						<label for="loginname" class="block text-sm text-academy-parchment mb-1">
							Dein Loginname
						</label>
						<input
							id="loginname"
							type="text"
							bind:value={loginName}
							required
							autocomplete="username"
							autocapitalize="none"
							spellcheck="false"
							class={eingabe}
							placeholder="z.B. raven"
						/>
						<p class="text-xs text-academy-steel mt-1">Groß- und Kleinschreibung ist egal.</p>
					</div>
				{/if}

				<div>
					<label for="passwort" class="block text-sm text-academy-parchment mb-1">Passwort</label>
					<input
						id="passwort"
						type="password"
						bind:value={passwort}
						required
						autocomplete="current-password"
						class={eingabe}
					/>
				</div>

				<button
					type="submit"
					disabled={laedt}
					class="w-full py-3 rounded bg-academy-gold text-academy-bg font-bold disabled:opacity-50"
				>
					{laedt ? 'Einen Moment…' : 'Die Tore öffnen'}
				</button>

				{#if weg === 'schueler'}
					<p class="text-xs text-academy-steel text-center pt-1">
						Loginname vergessen oder Passwort verloren? Deine Lehrkraft kann beides neu vergeben.
					</p>
				{/if}
			</form>
		</div>
	</div>
</div>
