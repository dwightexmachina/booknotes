# HTTP JSON API

Started with `booknotes serve` (see [cli.md](cli.md#serve)). Binds to
`localhost` only. The API is **read-only** — all writes go through the CLI.
Every `/api/*` response is JSON with `Access-Control-Allow-Origin: *`.

Any path outside `/api/*` serves the built Flutter web app from
`app/build/web` (or a plain-text notice if no build exists).

The GitHub Pages build has no server; it reads a static snapshot of these
same shapes written by `booknotes export` — see [deploy.md](deploy.md). Keep
the two in step: a change to a response shape here means a matching change to
the export.

## GET /api/health

```json
{ "ok": true }
```

## GET /api/books

All books ordered by title (case-insensitive), each with derived counts:

```json
[
  {
    "id": "fee6c14a-bbcf-4b28-a0b3-d401169532d3",
    "title": "Moby-Dick",
    "author": "Herman Melville",
    "publish_year": 1851,
    "edition": "Norton Critical, 3rd ed.",
    "created_at": "2026-09-16T20:33:08.412891Z",
    "updated_at": "2026-09-16T20:33:08.412891Z",
    "note_count": 2,
    "word_count": 24
  }
]
```

`author`, `publish_year`, `edition` may be `null`. `word_count` is the sum of
the book's note word counts (rule in [schema.md](schema.md#word-count-rule)).

## GET /api/books/&lt;ref&gt;

One book plus its notes ordered by `position`. `<ref>` accepts the same
resolution as the CLI: exact UUID, unique UUID prefix, or unique
case-insensitive title substring.

```json
{
  "id": "fee6c14a-...",
  "title": "Moby-Dick",
  "author": "Herman Melville",
  "publish_year": 1851,
  "edition": "Norton Critical, 3rd ed.",
  "created_at": "...",
  "updated_at": "...",
  "note_count": 2,
  "word_count": 24,
  "notes": [
    {
      "id": "0bcc207b-...",
      "book_id": "fee6c14a-...",
      "section": "ch. 1-16",
      "body": "Ishmael before the Pequod: ...",
      "position": 1,
      "word_count": 12,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

Errors: `404` with `{"error": "..."}` when nothing matches; `400` when the
ref is ambiguous.
