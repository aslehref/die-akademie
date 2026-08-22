<script lang="ts">
	import '../app.css';

	// Selbst ausgeliefert statt von Google geladen: ein eingebundenes
	// Google-Font überträgt die IP jedes Besuchers an Google.
	import '@fontsource/cinzel/latin-400.css';
	import '@fontsource/cinzel/latin-600.css';
	import '@fontsource/cinzel/latin-700.css';
	import '@fontsource/lora/latin-400.css';
	import '@fontsource/lora/latin-400-italic.css';
	import '@fontsource/lora/latin-600.css';
	import '@fontsource/lora/latin-700.css';
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { supabase, getCurrentUser, getUserRole, signOut } from '$lib/supabase';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import type { User } from '@supabase/supabase-js';
	import type { UserRole } from '$lib/supabase';

	let user: User | null = $state(null);
	let role: UserRole | null = $state(null);
	let loading = $state(true);

	onMount(() => {
		// onMount allein genügt nicht: Nach dem Anmelden wechselt die App per
		// goto() die Seite, ohne neu zu laden – das Layout hätte den frisch
		// angemeldeten Menschen sonst gar nicht bemerkt und weiter den
		// Abgemeldet-Bildschirm gezeigt, bis jemand F5 drückt.
		const { data } = supabase.auth.onAuthStateChange(async (_ereignis, sitzung) => {
			user = sitzung?.user ?? null;
			role = user ? await getUserRole(user.id) : null;
			loading = false;
		});

		// Für den ersten Aufruf, falls schon eine Sitzung besteht.
		(async () => {
			const currentUser = await getCurrentUser();
			user = currentUser;
			if (currentUser) role = await getUserRole(currentUser.id);
			loading = false;
		})();

		return () => data.subscription.unsubscribe();
	});

	async function handleSignOut() {
		await signOut();
		user = null;
		role = null;
		goto(`${base}/login`);
	}

	let { children }: { children: import('svelte').Snippet } = $props();
</script>

{#if loading}
	<div class="flex items-center justify-center min-h-screen">
		<div class="text-academy-gold text-2xl font-heading animate-pulse">Die Akademie</div>
	</div>
{:else if $page.url.pathname === '/login' || (!$page.url.pathname.includes('/dashboard') && !user)}
	{@render children()}
{:else if user}
	<div class="flex h-screen bg-academy-bg">
		<!-- Sidebar -->
		<aside class="w-64 bg-academy-surface border-r border-academy-blue/30 flex flex-col">
			<div class="p-4 border-b border-academy-blue/30">
				<h1 class="text-xl font-heading text-academy-gold">Die Akademie</h1>
				<p class="text-xs text-academy-steel mt-1">
					{user.email}
					{#if role}
						· <span class="text-academy-cyan">{role}</span>
					{/if}
				</p>
			</div>

			<nav class="flex-1 p-4 space-y-2">
				<a
					href="{base}/dashboard"
					class="block px-3 py-2 rounded hover:bg-academy-blue/40 text-academy-parchment transition-colors"
				>
					🏰 Große Halle
				</a>
				<a
					href="{base}/dashboard/markt"
					class="block px-3 py-2 rounded hover:bg-academy-blue/40 text-academy-parchment transition-colors"
				>
					🛒 Der Markt
				</a>
				<a
					href="{base}/dashboard/finale"
					class="block px-3 py-2 rounded hover:bg-academy-blue/40 text-academy-parchment transition-colors"
				>
					👑 Das Finale
				</a>

				<div class="border-t border-academy-blue/30 my-4 pt-4">
					{#if role === 'admin'}
						<a
							href="{base}/admin"
							class="block px-3 py-2 rounded hover:bg-academy-magenta/30 text-academy-gold transition-colors"
						>
							⚙️ Lehrerzimmer
						</a>
					{/if}
				</div>
			</nav>

			<div class="p-4 border-t border-academy-blue/30">
				<button
					onclick={handleSignOut}
					class="w-full px-3 py-2 text-sm rounded border border-academy-steel/50 text-academy-steel hover:bg-academy-steel/20 transition-colors"
				>
					Abmelden
				</button>
			</div>
		</aside>

		<!-- Main Content -->
		<main class="flex-1 overflow-y-auto p-8">
			{@render children()}
		</main>
	</div>
{:else}
	<div class="flex items-center justify-center min-h-screen">
		<div class="text-center">
			<h1 class="text-3xl font-heading text-academy-gold mb-4">Die Akademie</h1>
			<p class="text-academy-parchment mb-6">Wissen. Gemeinschaft. Verantwortung.</p>
			<a
				href="{base}/login"
				class="inline-block px-6 py-3 bg-academy-gold text-academy-bg rounded font-bold hover:bg-academy-gold/90 transition-colors"
			>
				Zum Login
			</a>
		</div>
	</div>
{/if}

<style>
	:global(body) {
		margin: 0;
	}
</style>
