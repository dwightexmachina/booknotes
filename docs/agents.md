# Agent playbook

How an AI agent (Claude, Codex, or any tool-using model) should execute
booknotes operations, typically to file note content provided by the user.
Full command semantics: [cli.md](cli.md). Data model: [schema.md](schema.md).

## Ground rules

1. **Always pass `--json`** and parse stdout; never scrape the human tables.
2. **Never rely on interactivity.** Pass `--yes` on every `delete`; never let
   `note add`/`note update` fall through to `$EDITOR` — always supply the
   body via `--text`, `--file`, or piped stdin.
3. **Prefer `--file` for real note content.** Shell quoting mangles prose;
   write the user's text to a temp file verbatim and pass the path. Do not
   reformat, summarize, or "fix" the user's text.
4. **Check exit codes**: 0 success, 1 runtime error (stderr explains; e.g.
   ambiguous ref → retry with a UUID prefix from the listed candidates),
   2 usage error (your command line was malformed).
5. **Resolve, then act.** For anything destructive, resolve the ref first
   (`book show`, `note show`), confirm the id is the intended target, then
   act on the UUID (or its 8-char prefix from the JSON), not on a title
   substring.
6. **Don't touch the SQLite file directly.** The CLI maintains invariants
   (contiguous positions, timestamps, cascades); raw SQL writes can break
   them.
7. The database defaults to `~/.booknotes/books.db`. Only pass `--db`/`BOOKNOTES_DB`
   when the user asks for a different database.

## Recipes

Filing a note the user provided ("add this to my Moby-Dick notes, it covers
chapters 36-41: <content>"):

```sh
# 1. find the book (or create it if missing)
booknotes --json book list
# no match? -> booknotes --json book add --title "Moby-Dick" --author "Herman Melville" --year 1851

# 2. write the user's content verbatim to a temp file, then:
booknotes --json note add fee6c14a --section "ch. 36-41" --file /tmp/note.md
# stdout: the created note object; verify "word_count" and "position"
```

Reordering ("make that note the first one"):

```sh
booknotes --json note list moby            # find the note id
booknotes --json note move 29f05dd6 1      # renumbers the rest automatically
```

Editing metadata ("it's actually the 1851 first edition"):

```sh
booknotes --json book update moby --year 1851 --edition "1st ed."
```

Deleting (destructive — confirm with the user first if there is any doubt):

```sh
booknotes --json note delete 29f05dd6 --yes
booknotes --json book delete fee6c14a --yes    # cascades to all its notes
```

Reading state for a summary or report:

```sh
booknotes --json book list                 # every book with note/word counts
booknotes --json book show moby            # one book incl. full notes array
```

## Verifying an operation

Every mutation echoes the resulting object as JSON — check it instead of
issuing a follow-up read. After `note add`, confirm `position` (appends at
the end) and `word_count`. If the user has `booknotes serve` running, the
browser UI reflects committed writes on its next refresh; there is nothing
to restart.
