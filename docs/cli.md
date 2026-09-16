# CLI reference

Invocation, either:

```sh
cd cli && dart run booknotes <command> ...      # from a repo checkout
booknotes <command> ...                          # after: dart pub global activate --source path cli
```

Examples below use the bare `booknotes` form.

## Global flags

Global flags may appear before or after the subcommand.

| Flag | Meaning |
|---|---|
| `--db <path>` | SQLite file to use. Precedence: `--db` > `BOOKNOTES_DB` env var > `~/.booknotes/books.db`. Created on first use. |
| `--json` | Emit machine-readable JSON on stdout instead of human tables. |

```sh
booknotes --json --db /tmp/scratch.db book list
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Runtime error: no match for a ref, ambiguous ref, aborted confirmation, empty note body, etc. Message on stderr (or "Aborted." on stdout for declined confirmations). |
| 2 | Usage error: unknown command/flag, missing required flag, malformed number. |

## Reference resolution

**`<book-ref>`** is resolved in this order, first hit wins; the match must be
unique or the command fails with exit 1:

1. exact UUID;
2. UUID prefix (e.g. `fee6c14a` or `fee`);
3. case-insensitive **title substring** (e.g. `moby`).

An ambiguous ref fails and prints the candidates with their 8-char id
prefixes; retry with a UUID prefix.

**`<note-id>`** is an exact note UUID or a unique UUID prefix (no text
matching).

## Book commands

### booknotes book add

```sh
booknotes book add --title "Moby-Dick" [--author "Herman Melville"] [--year 1851] [--edition "Norton Critical, 3rd ed."]
```

`--title` is required; the rest optional. With `--json`, prints the created
book object (fields as in [api.md](api.md), including `id`).

### booknotes book list

Lists all books with note counts and aggregate word counts. With `--json`,
prints an array of book objects.

### booknotes book show <book-ref>

One book plus a table of its notes (position, id, section, words). With
`--json`, prints the book object with a `notes` array.

### booknotes book update <book-ref>

```sh
booknotes book update moby --author "H. Melville" --year 1851 --edition "2nd ed." --title "..."
```

Only the flags you pass change. Clearing: `--author ""` and `--edition ""`
set the field to NULL; `--year ""` clears the year. Passing no field flags is
a usage error.

### booknotes book delete <book-ref> [--yes]

Deletes the book **and all of its notes** (cascade). Prompts `[y/N]` on a
terminal; in scripts pass `--yes`. Declining exits 1 with "Aborted.".

## Note commands

### booknotes note add <book-ref> --section "..." [--text "..."] [--file <path>]

Adds a note at the end of the book's ordering. `--section` (required) is free
text naming the part of the book the note covers, e.g. `"ch. 3-5"` or
`"pp. 112-140"`.

The body comes from the first available source:

1. `--text "..."` — inline argument;
2. `--file <path>` — file contents;
3. piped stdin — `cat notes.md | booknotes note add moby --section "ch. 1"`;
4. otherwise `$EDITOR` (default `vi`) opens on a temp file — interactive
   terminals only.

A body that is empty after trimming exits 1 without adding anything.

### booknotes note list <book-ref>

The book's notes in position order (position, id, section, word count, first-
line preview). With `--json`, an array of note objects.

### booknotes note show <note-id>

Full note including the body. With `--json`, the note object.

### booknotes note update <note-id> [--section "..."] [--text "..."] [--file <path>] [--edit]

Updates section and/or body. Body sources: `--text` / `--file` as in
`note add`; `--edit` opens `$EDITOR` pre-filled with the current body.
Passing nothing to change is a usage error.

### booknotes note move <note-id> <position>

Moves the note to the 1-based `<position>` within its book (values past the
end clamp to last). All of the book's notes are renumbered to a contiguous
`1..n`.

### booknotes note delete <note-id> [--yes]

Deletes the note and renumbers the remaining notes. Prompts unless `--yes`.

## serve

```sh
booknotes serve [--port 8080] [--web-root <dir>]
```

Serves the read-only JSON API ([api.md](api.md)) and the built Flutter web UI
on `http://localhost:<port>`, until Ctrl-C. `--web-root` defaults to
`app/build/web`, looked up from the current directory and one level up (so it
works from the repo root or from `cli/`). If no web build exists the API
still runs and `/` explains how to build the UI.

## JSON output shapes

With `--json`: mutations print the affected object after the change
(`note move` prints the moved note with its new `position`); `book show`
includes a `notes` array; deletions print `{"deleted": "<uuid>"}`. Field
definitions are in [api.md](api.md); word counts follow the rule in
[schema.md](schema.md#word-count-rule).
