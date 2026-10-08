# Deploying to GitHub Pages

The site is <https://dwightexmachina.github.io/booknotes/>, published by
`.github/workflows/deploy.yml` on every push to `main`.

## Why a snapshot

Locally the web UI reads the JSON API that `booknotes serve` puts in front of
`~/.booknotes/books.db` ([api.md](api.md)). GitHub Pages serves static files
only — there is no server to answer `/api/*`, and the Actions runner has no
copy of the database. So the deployed build reads a committed snapshot
instead.

`booknotes export` ([cli.md](cli.md#export)) writes that snapshot to
`app/assets/data/` in exactly the API's response shapes, and
`app/lib/api.dart` picks the backend at compile time:

| Build | Data source |
|---|---|
| default | `GET /api/books`, `GET /api/books/<id>` over HTTP |
| `--dart-define=STATIC_DATA=true` | `assets/data/books.json`, `assets/data/books/<id>.json` |

Nothing about the local workflow changes: `booknotes serve` and
`flutter run -d chrome --dart-define=API_BASE=http://localhost:8080` still go
through the live API.

Because the snapshot is committed, **the published site shows your notes
exactly as of the last `booknotes export`** — adding a note does not update
the site until you export and push.

## Publishing changes

```sh
# from the repository root
cd cli && dart run booknotes export   # refresh app/assets/data
cd .. && git add -A && git commit -m "Update notes" && git push
```

The workflow then runs `flutter build web --release` with
`--base-href "/<repo>/"` (required for a project page to find its assets) and
`--dart-define=STATIC_DATA=true`, and deploys `app/build/web`.

`actions/configure-pages` runs with `enablement: true`, so the first push
turns Pages on by itself — no manual setting needed. Watch a run with
`gh run watch`.

## Checking a Pages build locally

The base href makes the app expect to live under `/booknotes/`, so serving
`app/build/web` at the server root will 404 on assets. Serve it one level up:

```sh
cd app && flutter build web --release --base-href "/booknotes/" \
  --dart-define=STATIC_DATA=true
mkdir -p /tmp/site && ln -sfn "$PWD/build/web" /tmp/site/booknotes
cd /tmp/site && python3 -m http.server 8099
# open http://localhost:8099/booknotes/
```
