# booknotes

Local book-notes manager: SQLite storage, a Dart CLI for all CRUD, and a
read-only Flutter web viewer showing per-note and per-book word counts.

**All documentation lives in [docs/](docs/README.md)** — quickstart,
architecture, schema, full CLI reference, HTTP API, and an agent playbook.

```sh
cd cli && dart pub get
dart run booknotes book add --title "Moby-Dick" --author "Herman Melville" --year 1851
dart run booknotes note add moby --section "ch. 1-16" --text "Call me Ishmael..."
dart run booknotes serve          # web UI + API at http://localhost:8080
```
