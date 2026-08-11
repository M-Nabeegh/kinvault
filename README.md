# KinVault

KinVault is a local-first, privacy-oriented family-records demo. It makes document facts easier to inspect without pretending that an answer is trustworthy unless it can point back to its source field. The included family and files are entirely synthetic.

## Visual direction

The interface is deliberately calm and Apple-like: paper-white workspace, charcoal type, a compact Finder-style rail, restrained rounded cards, and one visible **Local only** boundary. The design favors source context and clear destructive-action warnings over flashy dashboard chrome.

## Quick start

Requirements: Node.js 20+ and npm.

```bash
npm install
cp .env.example .env # optional; choose a local vault root
npm run dev
```

Open the localhost URL printed by Next.js. The server binds to `127.0.0.1` when using the provided `npm run dev` command. Do not put a real-user storage path in a committed `.env` file.

## Seeded demo walkthrough

1. Open the dashboard to see four fictional documents and the next expiry.
2. Ask Q&A: “When does Dad’s passport expire?” The answer includes a confidence label and a source citation.
3. Open the source preview to inspect the cited page and extracted field instead of accepting an unsupported guess.
4. Visit People for a relationship-oriented view of the same synthetic records.
5. Visit Needs review to accept, correct, or dismiss a low-confidence field.
6. Visit Documents to upload a synthetic `.txt`, `.md`, or `.csv` fixture (10 MB maximum); payment-card-like content is blocked.
7. Visit Privacy to download a local ZIP or use the phrase-gated removal controls.

## Synthetic data notice

Every seeded person, document, date, and source field is fictional. The repository is safe to clone and demonstrate as-is; do not replace its fixtures with real identity, financial, or family records without first addressing the security boundaries below.

## Architecture

```text
Browser UI (Next.js App Router)
       | local route handlers only
       v
SQLite metadata + provenance  <-->  local vault-root files
       |                                  |
       +--> deterministic extractor -------+
```

- `app/` contains pages and local-only API routes.
- `components/` contains the Finder-inspired dashboard, Q&A, source preview, people, review, upload, and privacy controls.
- `src/data/` is the SQLite schema, seed data, and repository boundary.
- `src/services/` owns storage-root checks, deterministic extraction, exports, and deletion coordination.

## Data and provenance contract

Metadata lives in SQLite; original files stay below the configured vault root and are never stored as database blobs. Every answer can cite a document, page, extracted field, value, and confidence. Missing facts are reported as **Not found in the vault** rather than guessed. API responses and export metadata omit the server-only `storagePath`; archives use relative `files/<document-id>/<file-name>` entries.

## Privacy and security boundaries

KinVault makes no external OCR, analytics, AI, or remote storage request by default. The included seed data and demo documents are fictional and must not be mistaken for real identity records. Uploads are deliberately restricted to small synthetic text fixtures in v1; card-like data is rejected.

“Local” is a design boundary, not a security certification. KinVault does not encrypt storage, authenticate users, provide key management, create backups, or certify regulatory compliance. Protect the host account, choose an access-controlled vault directory, and maintain encrypted backups before considering real records.

## Privacy controls

`GET /api/export` downloads an uncompressed local ZIP containing `metadata.json` and vault-relative file entries. The metadata retains safe document details and source fields, but never absolute paths. The response is assembled on-device as a Web stream: each local file is read and emitted one at a time, so the archive is never buffered as one large payload and no remote service or upload is involved. Removing one document requires typing `DELETE DOCUMENT` and removes its metadata, extracted fields, and matching vault file. Deleting the vault requires exactly `DELETE MY VAULT`; it removes only the configured vault root and its metadata. Both actions are irreversible in this demo.

## After each feature: where to look

| Feature | What it does after you use it |
| --- | --- |
| Dashboard | Summarizes local records, categories, upcoming expiry, and review count. |
| Q&A | Gives a supported answer or an explicit not-found state, with citations. |
| Source preview | Shows the extracted source field and page behind an answer. |
| People | Groups the same records by the fictional person or household. |
| Review | Lets you accept, correct, or dismiss uncertain extraction results. |
| Upload | Adds an allowed synthetic text fixture to the local vault after checks. |
| Privacy | Exports the current local vault or confirms exactly what will be permanently removed. |

## Tests and quality checks

```bash
npm test
npm run typecheck
npm run lint
npm run build
```

Focused privacy-contract checks:

```bash
npm test -- tests/privacy-controls.test.ts tests/README-contract.test.ts
```

## Limitations

V1 is a local synthetic-data demo. It uses an in-memory metadata database, permits only text fixtures, has deterministic rather than OCR extraction, lacks encryption/authentication/backup/undo, and does not handle concurrent writers. Deletion is intentionally permanent once confirmed.

## Future adapters

Future work can add a persistent SQLite file, an offline OCR adapter, encrypted storage, user authentication, backup/restore, multi-device synchronization, and production document parsers. Each adapter should preserve the provenance contract, stay opt-in, and make every network/data boundary visible before it is enabled.
