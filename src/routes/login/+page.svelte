<script lang="ts">
	import { signIn } from '$lib/supabase';
	import { base } from '$app/paths';
	import { goto } from '$app/navigation';

	let email = $state('');
	let password = $state('');
	let error = $state('');
	let loading = $state(false);

	async function handleLogin(e: Event) {
		e.preventDefault();
		loading = true;
		error = '';

		const { error: authError } = await signIn(email, password);

		if (authError) {
			error = authError.message;
			loading = false;
			return;
		}

		goto(`${base}/dashboard`);
	}
</script>

<svelte:head>
	<title>Anmelden · Die Akademie</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-academy-bg">
	<div class="w-full max-w-md p-8">
		<div class="text-center mb-8">
			<h1 class="text-4xl font-heading text-academy-gold mb-2">Die Akademie</h1>
			<p class="text-academy-steel">Wissen. Gemeinschaft. Verantwortung.</p>
		</div>

		<form
			onsubmit={handleLogin}
			class="bg-academy-surface rounded-lg p-6 border border-academy-blue/30 space-y-4"
		>
			<h2 class="text-xl font-heading text-academy-gold text-center">Anmelden</h2>

			{#if error}
				<div class="bg-red-900/30 border border-red-700/50 text-red-300 p-3 rounded text-sm">
					{error}
				</div>
			{/if}

			<div>
				<label for="email" class="block text-sm text-academy-parchment mb-1">E-Mail</label>
				<input
					id="email"
					type="email"
					bind:value={email}
					required
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
					placeholder="lehrer@schule.de"
				/>
			</div>

			<div>
				<label for="password" class="block text-sm text-academy-parchment mb-1">Passwort</label>
				<input
					id="password"
					type="password"
					bind:value={password}
					required
					class="w-full px-3 py-2 rounded bg-academy-bg border border-academy-blue/50 text-academy-parchment focus:border-academy-gold focus:outline-none"
				/>
			</div>

			<button
				type="submit"
				disabled={loading}
				class="w-full py-3 rounded bg-academy-gold text-academy-bg font-bold hover:bg-academy-gold/90 transition-colors disabled:opacity-50"
			>
				{loading ? 'Wird geladen…' : 'Anmelden'}
			</button>
		</form>
	</div>
</div>
