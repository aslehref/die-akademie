import js from '@eslint/js';
import ts from 'typescript-eslint';
import svelte from 'eslint-plugin-svelte';
import globals from 'globals';
import svelteConfig from './svelte.config.js';

export default ts.config(
	js.configs.recommended,
	...ts.configs.recommended,
	...svelte.configs['flat/recommended'],
	{
		languageOptions: {
			globals: { ...globals.browser, ...globals.node }
		},
		rules: {
			// Die Supabase-Antworten sind bewusst locker typisiert; das hier
			// laut zu melden bringt in diesem Projekt keinen Erkenntnisgewinn.
			'@typescript-eslint/no-explicit-any': 'off'
		}
	},
	{
		// Ohne diesen Block versteht ESLint <script lang="ts"> in .svelte nicht.
		files: ['**/*.svelte', '**/*.svelte.ts', '**/*.svelte.js'],
		languageOptions: {
			parserOptions: {
				parser: ts.parser,
				extraFileExtensions: ['.svelte'],
				svelteConfig
			}
		}
	},
	{
		ignores: ['build/', '.svelte-kit/', 'node_modules/', 'static/']
	}
);
