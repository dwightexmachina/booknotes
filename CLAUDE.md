# booknotes

Canonical documentation is in `docs/` — read `docs/README.md` first.

- Executing CLI operations (adding/editing books and notes): follow
  `docs/agents.md`, with the full command reference in `docs/cli.md`.
- Changing the schema or word-count behavior: `docs/schema.md` states the
  invariants; keep code and docs in sync.
- All writes go through the CLI (`cli/`); the web UI (`app/`) is read-only.
  After UI changes, rebuild with `cd app && flutter build web --release`.
- Publishing to GitHub Pages: `docs/deploy.md`. The live site reads a
  committed snapshot, so notes only appear there after `booknotes export`
  and a push to `main`.
