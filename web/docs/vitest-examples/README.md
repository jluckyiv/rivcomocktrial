# Vitest examples

Reference snippets for adding test coverage when we extend the suite.
These files are not collected by `npm run test:unit` or any CI job.

- `greet.spec.ts` — plain Vitest unit test pattern (server project).
- `Welcome.svelte.spec.ts` — Vitest browser-mode component test pattern.

To run the browser example again, restore the `client` project block in
`web/vite.config.ts` and reinstall `@vitest/browser-playwright` and
`vitest-browser-svelte`. See git history for the removed config.
