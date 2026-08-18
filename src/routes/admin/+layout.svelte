<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { base } from '$app/paths';
	import { getCurrentUser, getUserRole, type UserRole } from '$lib/supabase';

	let { children }: { children: import('svelte').Snippet } = $props();

	// Die eigentliche Absicherung passiert in der Datenbank (Row-Level-
	// Security). Diese Pruefung sorgt nur dafuer, dass niemand versehentlich
	// in einer Oberflaeche landet, in der ohnehin jede Aktion scheitern wuerde.
	let rolle = $state<UserRole | null>(null);
	let geprueft = $state(false);

	onMount(async () => {
		const user = await getCurrentUser();
		if (user) rolle = await getUserRole(user.id);
		geprueft = true;
	});

	const tabs = [
		{ label: 'Überblick', href: base + '/admin', icon: '🏠' },
		{ label: 'Fakultäten', href: base + '/admin/bereiche', icon: '📚' },
		{ label: 'Quests', href: base + '/admin/quests', icon: '⚔️' },
		{ label: 'Privilegien', href: base + '/admin/belohnungen', icon: '🪙' },
		{ label: 'Orden', href: base + '/admin/abzeichen', icon: '🏅' }
	];
</script>

<svelte:head>
	<title>Lehrerzimmer · Die Akademie</title>
</svelte:head>

<div class="max-w-6xl mx-auto">
	<h1 class="text-3xl font-heading text-academy-gold mb-6">⚙️ Lehrerzimmer</h1>

	{#if !geprueft}
		<p class="text-academy-steel">Zugriff wird geprüft…</p>
	{:else if rolle !== 'admin'}
		<div class="bg-academy-surface border border-academy-blue/30 rounded-lg p-6">
			<p class="text-academy-parchment mb-2">
				Das Lehrerzimmer ist der Rolle <span class="text-academy-cyan">admin</span> vorbehalten.
			</p>
			<p class="text-sm text-academy-steel">
				Deine Rolle: <span class="text-academy-parchment">{rolle ?? 'keine'}</span>. Rollen werden
				in der Tabelle <code>user_roles</code> vergeben.
			</p>
			<a href="{base}/dashboard" class="inline-block mt-4 text-sm underline"
				>Zurück zur Großen Halle</a
			>
		</div>
	{:else}
		<nav class="flex gap-1 mb-8 border-b border-academy-blue/30 overflow-x-auto">
			{#each tabs as tab}
				<a
					href={tab.href}
					class="px-4 py-2 text-sm whitespace-nowrap border-b-2 transition-colors
					{$page.url.pathname === tab.href
						? 'border-academy-gold text-academy-gold'
						: 'border-transparent text-academy-steel hover:text-academy-parchment'}"
				>
					{tab.icon}
					{tab.label}
				</a>
			{/each}
		</nav>

		{@render children()}
	{/if}
</div>
