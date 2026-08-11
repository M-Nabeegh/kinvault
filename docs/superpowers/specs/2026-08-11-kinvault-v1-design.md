# KinVault v1 design specification

**Date:** 2026-08-11  
**Status:** Design approved by the product owner; implementation follows written-spec review  
**Product:** KinVault, a local-first family document vault

## Product intent

KinVault gives a family one calm, private place to keep basic personal documents and answer practical questions about them. It is deliberately narrower than a general-purpose document-management system: the first version handles identity, insurance, school, vehicle, visa, certificate, and utility records, and makes the source of every answer visible.

The public repository and seeded demo use fictional people and fictional documents only. A local instance can accept a user's own files, but the demo never ships with real family information.

## Design principles

1. **Local by default.** The browser talks to a local Next.js server. Metadata lives in SQLite and the original file stays in a vault directory on the same machine.
2. **Evidence before fluency.** An answer is only returned when a stored extracted field supports it. Every answer includes the document name, page, field label, and confidence.
3. **Uncertainty is visible.** Low-confidence extraction is queued for review and the interface asks the user to verify it instead of silently promoting it to truth.
4. **Apple-like, not AI-like.** The shell borrows Finder's calm orientation and Spotlight's direct search affordance: strong hierarchy, generous spacing, quiet surfaces, and no simulated chat transcript.
5. **Safe public demo.** The seeded family is synthetic, payment-card data is outside the product scope, and a missing field produces a clear not-found result.

## Visual direction

The selected direction combines:

- **Finder vault shell (A):** warm paper-white canvas, charcoal ink, a compact left rail, rounded but restrained cards, subtle dividers, and a clear local-only status indicator.
- **Spotlight index (C):** one prominent global field that supports both keyword search and a small set of deterministic natural-language questions. Results read like indexed records, not a chatbot.

The visual language uses a neutral sans-serif system stack with a small mono treatment for metadata such as expiry dates and citation labels. Green is reserved for verified/healthy states; amber marks review; red is reserved for an imminent expiry or a policy rejection. Motion is limited to short opacity/translate transitions and respects `prefers-reduced-motion`.

## Information architecture

### App shell

The shell has a persistent sidebar on desktop and a bottom navigation bar on narrow screens. It contains:

- **Overview** — expiry radar, category totals, recent documents, and review count.
- **Documents** — filterable records table/grid with category, person, expiry, confidence, and status.
- **People** — family profiles and document timelines.
- **Needs review** — extracted fields that need a human decision.
- **Privacy** — storage location, local-only boundary, export, and delete controls.

The top bar contains the KinVault mark, a local-only badge, and the Spotlight-style search/ask field. There is no sign-in with ChatGPT or external account requirement.

### Overview

The first screen opens on the seeded synthetic family. The lead card states what needs attention in plain language (for example, “2 documents expire within 90 days”). Supporting cards show the next expiry, category distribution, and the most recent indexed records. A compact review rail keeps uncertain OCR visible without dominating the page.

### Search and Q&A

The search field accepts:

- exact/partial document or person terms;
- supported questions about an extracted field, such as “When does Dad's passport expire?”;
- expiry-window questions such as “Which documents expire in the next 90 days?”

The result card always contains:

1. a direct answer or an explicit “Not found in the vault” state;
2. confidence (`high`, `medium`, or `needs verification`);
3. the source document title;
4. source page number;
5. extracted field label and value;
6. an “Open source” action that opens the source preview at the cited page/field.

Questions outside the indexed fields are not guessed. The response says that KinVault could not find the requested field and suggests searching documents instead.

### Upload flow

Upload uses a local file picker with a deliberately small scope: PDF, JPG, JPEG, PNG, and WebP, with a 10 MB per-file limit in v1. The user assigns a person, category, and optional document label. The server validates the file name, stores the bytes below the configured vault root, creates metadata in SQLite, and passes the file to an `ExtractionService` interface.

The first implementation ships an offline deterministic extractor. It can parse KinVault's synthetic fixture format and a small set of text-like metadata hints; it does not call a paid API. An OCR provider can be added later without changing the repository or answer layers.

### People and timelines

Each profile shows the person's avatar initials, basic synthetic/demo-safe identity label, document categories, upcoming expiry, and a chronological timeline of linked records. The timeline links back to source fields rather than duplicating values without provenance.

### Needs review

Every extracted field below the configured confidence threshold appears here with the original value, confidence, document, page, and reason. Review actions are explicit: accept, edit, or dismiss. An accepted edit is stored as a user-corrected field with an audit timestamp and remains linked to the original page.

### Privacy controls

The Privacy page states:

- files and metadata are local to the configured vault;
- no external OCR, analytics, or AI request is made by default;
- the seeded demo contains synthetic data only;
- document export produces a local archive;
- deleting a document removes its metadata and local file after a confirmation;
- deleting the vault is an explicit, separate destructive action.

The app binds to localhost by default. It is a privacy-oriented demo, not a claim of regulatory certification or a substitute for encrypted backups and operating-system access controls.

## Data model

SQLite is the source of truth for metadata and provenance. Original files are not stored as blobs in the database.

### `people`

- `id` — stable text identifier
- `display_name` — synthetic/demo-safe label
- `relationship` — e.g. parent, sibling, self
- `initials` — UI avatar fallback
- `created_at`

### `documents`

- `id` — stable text identifier
- `person_id` — foreign key to `people`
- `title`
- `category` — passport, identity, insurance, school, vehicle, visa, certificate, utility
- `file_name`
- `storage_path` — vault-relative path only
- `mime_type`
- `page_count`
- `status` — indexed, review, rejected
- `issued_on` (nullable)
- `expires_on` (nullable)
- `created_at`

### `extracted_fields`

- `id`
- `document_id`
- `page_number`
- `field_key` — normalized key such as `date_of_birth` or `expires_on`
- `label`
- `value`
- `confidence` — decimal between 0 and 1
- `source_text` — short provenance snippet, never an unbounded OCR dump
- `review_status` — accepted, pending, corrected, dismissed
- `created_at`
- `updated_at`

### `review_items`

- `id`
- `field_id`
- `reason`
- `created_at`
- `resolved_at` (nullable)

The repository exposes joins as typed domain objects so UI code never constructs SQL or file paths directly.

## Service boundaries

- `DocumentRepository` — CRUD/query operations for people, documents, fields, and review items.
- `DocumentStorage` — writes/reads/deletes files below the vault root and rejects traversal or absolute paths.
- `ExtractionService` — accepts a stored file and returns typed extracted fields plus confidence and page provenance.
- `AnswerService` — parses supported question patterns, retrieves matching fields, calculates expiry windows, and refuses unsupported or missing answers.
- `SensitiveDataPolicy` — detects payment-card intent/number patterns and rejects those uploads without blocking ordinary ID or insurance records.

The UI talks to route handlers/use cases, not directly to SQLite or the filesystem. This keeps the app testable and makes a future native OCR adapter possible.

## Security and privacy model

This v1 protects against the mistakes most likely in a local demo:

- path traversal and writing outside the vault root;
- arbitrary remote URL ingestion;
- unsupported payment-card content;
- accidental answer fabrication;
- public demo data being mistaken for real family data.

It does not yet provide multi-user authentication, encrypted-at-rest storage, remote sync, malware scanning, or formal compliance certification. Those are explicit non-goals for v1 and are documented in the README.

## Verification strategy

Tests are written before production code for each core behavior:

- expiry windows handle timezone-safe dates and boundary days;
- answer objects cannot be created without a complete source citation;
- unsupported payment-card content is rejected while ordinary identity/insurance categories remain allowed;
- missing fields return not-found instead of an invented value;
- path validation cannot escape the vault root;
- seeded demo data is deterministic and contains no real personal data.

The repository's README will include the local setup commands, architecture map, privacy model, screenshot path, limitations, and a feature-by-feature explanation.

## v1 success criteria

Someone cloning the public repository can run one local command, open the dashboard, inspect the synthetic family, ask a supported question, follow its citation to a source preview, upload a local test file, see uncertain extraction in the review queue, and export/delete the vault without any paid API key or external account.

