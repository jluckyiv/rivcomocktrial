import prettier from 'eslint-config-prettier';
import path from 'node:path';
import { includeIgnoreFile } from '@eslint/compat';
import js from '@eslint/js';
import svelte from 'eslint-plugin-svelte';
import { defineConfig } from 'eslint/config';
import globals from 'globals';
import ts from 'typescript-eslint';
import svelteConfig from './svelte.config.js';

const gitignorePath = path.resolve(import.meta.dirname, '.gitignore');

export default defineConfig(
	includeIgnoreFile(gitignorePath),
	js.configs.recommended,
	ts.configs.recommended,
	svelte.configs.recommended,
	prettier,
	svelte.configs.prettier,
	{
		ignores: ['src/lib/pocketbase-types.ts', 'docs/**']
	},
	{
		languageOptions: { globals: { ...globals.browser, ...globals.node } },
		rules: {
			// typescript-eslint strongly recommend that you do not use the no-undef lint rule on TypeScript projects.
			// see: https://typescript-eslint.io/troubleshooting/faqs/eslint/#i-get-errors-from-the-no-undef-rule-about-global-variables-not-being-defined-even-though-there-are-no-typescript-errors
			'no-undef': 'off',
			// Allow _-prefixed variables in destructuring patterns (e.g. unused destructured values)
			'@typescript-eslint/no-unused-vars': [
				'error',
				{ varsIgnorePattern: '^_', argsIgnorePattern: '^_' }
			]
		}
	},
	{
		files: ['**/*.svelte', '**/*.svelte.ts', '**/*.svelte.js'],
		languageOptions: {
			parserOptions: {
				projectService: true,
				extraFileExtensions: ['.svelte'],
				parser: ts.parser,
				svelteConfig
			}
		}
	},
	{
		files: ['**/*.{ts,js,svelte}'],
		ignores: ['**/*.spec.ts', '**/*.spec.js', '**/test-helpers/**'],
		rules: {
			'no-restricted-imports': [
				'error',
				{
					patterns: [
						{
							group: [
								'**/test-helpers/**',
								'$lib/test-helpers/**',
								'**/*.spec',
								'**/*.spec.ts',
								'**/*.spec.js'
							],
							message:
								'Test helpers and spec files must not be imported from production code. ' +
								'If you genuinely need this code in production, move it out of test-helpers/ first.'
						}
					]
				}
			]
		}
	},
	{
		rules: {
			// Not using SvelteKit base path — static hrefs are fine everywhere
			'svelte/no-navigation-without-resolve': 'off'
		}
	}
);
