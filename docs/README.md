# booknotes documentation

booknotes is a local-only book-notes manager. Notes live in a single SQLite
file; all writes go through a CLI; a read-only web UI shows books, notes, and
word counts.

This folder is the canonical documentation. It is written so that a human or
an agent (Claude, Codex, etc.) can operate the app from these pages alone,
without reading the source.

| Page | What it covers |
|---|---|
| [architecture.md](architecture.md) | Components, data flow, repository layout |
| [schema.md](schema.md) | SQLite tables, invariants, the word-count rule |
| [cli.md](cli.md) | Complete CLI reference: every command, flag, exit code, JSON output |
| [api.md](api.md) | The read-only HTTP JSON API served by `booknotes serve` |
| [agents.md](agents.md) | Playbook for AI agents executing CLI commands non-interactively |

## Quickstart

Prerequisites: Dart SDK ≥ 3.11 (Flutter SDK only if rebuilding the web UI).

```sh
# from the repository root
cd cli && dart pub get

# add a book and a note
dart run booknotes book add --title "Moby-Dick" --author "Herman Melville" --year 1851
dart run booknotes note add moby --section "ch. 1-16" --text "Ishmael before the Pequod..."

# see it
dart run booknotes book list

# serve the web UI + API at http://localhost:8080
dart run booknotes serve
```

Optional: install the CLI onto your PATH so `booknotes` works anywhere:

```sh
dart pub global activate --source path cli
```

The database defaults to `~/.booknotes/books.db` and is created on first use.
Override with `--db <path>` or the `BOOKNOTES_DB` environment variable.

## Rebuilding the web UI

The server hosts a prebuilt Flutter web bundle from `app/build/web`. After
changing anything under `app/`, rebuild it:

```sh
cd app && flutter build web --release
```
