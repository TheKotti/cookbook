# Cookbook — Recipe Importer (Design Document)

**Status:** Draft v3 (local-only) — parser spec verified against a live Chefkoch page; §13 open questions resolved.
**Date:** 2026-07-07
**Author:** (owner)

A personal Android app that imports recipes from **chefkoch.de** by URL, normalizes
them into structured data, and stores them **locally on the device**. Everything is
readable offline. Cloud storage and cross-device sync are deliberately deferred to a
later version (see §12).

---

## 1. Goals & Non-Goals

### Goals (v1)
- Android phone app, built with **Flutter** so iOS can follow with the same codebase.
- Import a recipe by pasting/sharing its **chefkoch.de URL**.
- Store recipes **on-device** in a local database.
- **Offline-first** — trivially satisfied, since all data is local. Only the import
  step needs a connection (it fetches a live page).
- View and delete recipes.
- **Search** and organize by **tags/categories**.
- **Serving scaling** — recompute ingredient amounts for a chosen serving count.
- **Backup** — manual **JSON export/import** of the whole collection (safety net against
  a lost device; also the migration format for future cloud sync).

### Non-Goals (v1) — deliberately deferred
- **Cloud storage / backup** (Firebase or otherwise).
- **Cross-device sync** — a direct consequence of local-only. Recipes live on one
  device. (You earlier wanted multi-device; that returns with the cloud, §12.)
- **Accounts / login** — no auth needed when there's no backend; the app opens
  straight to the recipe list.
- **Storing recipe images locally** — v1 loads images live from Chefkoch via their URL
  and caches them on-device on first view.
- Importing from sites other than chefkoch.de (architecture leaves room for it).
- Republishing or redistributing imported content in any form.
- Shopping lists, meal planning, cooking timers.

---

## 2. Key Decisions (resolved)

| Question | Decision | Rationale |
|---|---|---|
| Storage | **Local-only** (on-device DB) | Simplest to build now; cloud sync deferred to §12. |
| Platform | **Flutter** (Android now, iOS-ready) | One codebase for both; avoids a future rewrite. |
| Offline | **Offline-first** (automatic) | All data is local; nothing to sync. |
| Auth | **None** | No backend ⇒ nothing to authenticate. |
| Parsing | **On-device** (Dart module) | No server; keep it isolated & well-tested (§6). |
| Local DB | **Drift (SQLite)** | Relational tags, easy search, and a clean migration path to cloud later. Isar is a viable alternative. |
| State mgmt | **Riverpod** | Testable, no `BuildContext` coupling; repository/providers wire cleanly to the `RecipeRepository` seam. |
| Search | **Drift FTS5** over title + tags + ingredients | `LIKE` can't search ingredient text well; FTS5 gives ranked, umlaut-tolerant matching (§8). |
| Import User-Agent | **Browser-like UA** (mobile Chrome string) | Verified: a non-browser UA is served a 184-byte block; a browser UA gets the full page. A personal clipping tool must actually fetch. Supersedes the "descriptive UA" wording. |
| Re-import same URL | **Overwrite** the existing recipe (matched by `source_url`) | Refreshes stale data; safe because imported fields are read-only (no edits to clobber). |
| Manual editing | **Read-only** imported fields; **tags** are the only editable field | Smallest v1; no edit UI, no dirty-state vs. overwrite conflict. |
| v1 features | Import, view, delete, search, tags, serving scaling | Per requirements review. |

> **Trade-off accepted:** with parsing on-device, fixing the importer after a Chefkoch
> markup change requires an **app update**, not a silent server redeploy. Mitigated by
> keeping the parser a small, isolated, well-tested module (JSON-LD is comparatively
> stable).

---

## 3. Legal & Content Constraints (read first)

Local-only actually *reduces* legal exposure (nothing is stored in a shared cloud or
served to anyone), but the constraints still hold:

- Chefkoch.de content is **copyrighted**; their ToS restrict automated access. This app
  is a **personal, single-device clipping/backup tool** — not a redistribution platform.
- **No sharing, no public feed, no republishing.**
- Every stored recipe **retains its source URL and author attribution**.
- The importer is a **polite client**: one request per user action (no crawling/bulk
  import), backoff on errors. It sends a **browser-like User-Agent** — verified
  necessary, as Chefkoch serves non-browser clients a tiny block page (see §11). This is
  a single-device personal fetch, not a crawler.
- Imports may break if Chefkoch changes their site or blocks access; this is a personal
  tool with no SLA.

---

## 4. High-Level Architecture

Everything runs in the app. The only network calls are (a) fetching the recipe page to
import, and (b) loading recipe images live from Chefkoch's CDN.

```
┌──────────────────────────────────────────────────────────┐
│                 Flutter App (Android / iOS)               │
│                                                           │
│   UI layer                                                │
│   ┌──────────────────────────────────────────────────┐   │
│   │ List · Detail · Import · Scaler · Tag editing      │   │
│   └───────────────┬──────────────────────────────────┘   │
│                   │                                       │
│   RecipeRepository (interface)                            │
│   ┌───────────────▼──────────────────────────────────┐   │
│   │ LocalRecipeRepository  →  Drift (SQLite) DB        │   │
│   └───────────────┬──────────────────────────────────┘   │
│                   │                                       │
│   Import service  │                                       │
│   ┌───────────────▼──────────────────────────────────┐   │
│   │ 1. validate host = chefkoch.de                     │   │
│   │ 2. fetch page HTML        ──────────────► Chefkoch │───┼──► network
│   │ 3. RecipeParser (JSON-LD → normalized Recipe)      │   │
│   │ 4. save to local DB                                │   │
│   └────────────────────────────────────────────────────┘  │
│                                                           │
│   Images: loaded live by imageUrl (cached_network_image) │───┼──► Chefkoch CDN
└──────────────────────────────────────────────────────────┘
```

The `RecipeRepository` interface is the seam where cloud sync gets added later (§12) —
the UI never talks to storage directly.

### Import flow
1. User pastes a URL or shares one from the Chefkoch app/browser (Android share-target).
   Shared text may contain surrounding text — **extract the first `http(s)` URL** from it.
2. App validates the host is `chefkoch.de` **or a subdomain** (`www.`, `m.`); scheme is
   http/https (upgrade to https); strip tracking query params. Reject anything else with
   a clear message.
3. App **fetches the page HTML** with a browser-like User-Agent (needs a connection).
4. **`RecipeParser`** extracts the `schema.org/Recipe` JSON-LD and normalizes it (§6),
   including the source image URL.
5. App writes the recipe to the local DB. Done — visible immediately, forever offline.

---

## 5. Data Model (local, Drift/SQLite)

Two tables; tags are relational so they can be filtered efficiently.

```
recipes
  id                INTEGER  PK
  source_url        TEXT
  title             TEXT
  author            TEXT     -- attribution, from JSON-LD
  image_url         TEXT     -- Chefkoch CDN URL, loaded live (nullable)
  base_servings     INTEGER  -- from recipeYield
  prep_minutes      INTEGER  -- nullable
  cook_minutes      INTEGER  -- nullable
  total_minutes     INTEGER  -- nullable
  rating            REAL     -- nullable, from source
  ingredients_json  TEXT     -- JSON array (see below)
  steps_json        TEXT     -- JSON array of strings
  imported_at       TEXT     -- ISO-8601
  schema_version    INTEGER

recipe_tags
  recipe_id  INTEGER  FK → recipes.id
  tag        TEXT
  PK (recipe_id, tag)
```

`base_servings` is **nullable** — if `recipeYield` can't be parsed to an integer, it's
null and the serving scaler is hidden for that recipe (see §7), rather than dividing by
null/zero.

`ingredients_json` — structured so scaling (and future shopping lists) work:

```jsonc
[
  { "amount": 500,  "amount_max": null, "unit": "g",  "name": "Spaghetti", "raw": "500 g Spaghetti" },
  { "amount": 0.5,  "amount_max": null, "unit": null, "name": "Ei",        "raw": "½ Ei" },
  { "amount": 2,    "amount_max": 3,    "unit": "Zehe","name": "Knoblauch", "raw": "2-3 Zehen Knoblauch" },
  { "amount": null, "amount_max": null, "unit": null, "name": "Salz",      "raw": "Salz, nach Belieben" }
]
```

Amount representation (resolves the "single number can't hold a range/fraction" gap):
- **Fractions** (`½`, `1/2`) are stored as **decimals** in `amount` (`0.5`).
- **Ranges** (`2-3`) store the low bound in `amount` and the high bound in `amount_max`;
  both scale, and the scaler renders `2–3` (see §7). Non-ranges leave `amount_max: null`.
- **Uncertain / unparseable** amounts stay `amount: null` (never a guessed midpoint).

Notes:
- Ingredients keep the original `raw` string as a fallback when parsing is uncertain —
  an ingredient is **never dropped**, at worst it shows as raw text with no scaling.
- `image_url` is the Chefkoch URL; the image is loaded live and cached on-device on
  first view. No local copy in v1.
- `schema_version` allows on-device migrations as the parser/schema evolve.
- **Search** uses a Drift **FTS5** virtual table indexing `title`, joined `tags`, and
  ingredient `name`s (§8); it is rebuilt on insert/overwrite/delete.

---

## 6. Recipe Parsing & Normalization (on-device `RecipeParser`)

**Primary source: `schema.org/Recipe` JSON-LD**, embedded as
`<script type="application/ld+json">`. Far more stable than CSS-selector scraping.

> The field shapes below were **verified against a live Chefkoch recipe page** (July
> 2026). Where the real data differs from the plain schema.org examples, the real shape
> wins — those are the spots most likely to be built wrong.

Steps:
1. Extract all `ld+json` blocks; JSON-parse each; find the `Recipe` object. It may sit
   inside an array or a top-level `@graph`, and `@type` may be a **string or a list** —
   recurse and match `"Recipe" ∈ @type`.
2. Map fields:
   - `name` → `title`
   - `author.name` → `author`. May be absent or literally `"Gelöschter Benutzer"`
     (deleted user) → store as-is; treat empty/deleted as "Unbekannt" for display.
   - `recipeYield` → `base_servings`. **Real value is a string like `"2 Portionen"`** —
     parse the leading integer; if none, `base_servings = null` (scaler hidden).
   - `prepTime` / `cookTime` / `totalTime` → minutes. **Real format is `P0DT0H15M`**, not
     `PT15M`. Use a full ISO-8601 duration parse (days + hours + minutes → total minutes),
     not a `PT(\d+)M` regex.
   - `recipeIngredient[]` → parse each string into
     `{amount, amount_max, unit, name, raw}` (step 3).
   - `recipeInstructions` → `steps[]` (step 4).
   - `image` → `image_url`. May be a **string, an array, or an `ImageObject`** (`.url`);
     take the first usable URL.
   - `aggregateRating.ratingValue` → `rating`.
   - `keywords` → seed `tags`. **Real value is a comma-separated string**
     (`"Hauptspeise, Nudeln, Europa, Pasta, …"`) — split on `,`, trim, drop empties,
     lowercase-dedupe. **Ignore `recipeCategory`** — observed value was the useless
     top-level `"Kochen"`.
3. **Ingredient parsing (German-aware).** Real strings are messy — e.g.
   `"  Salz"`, `"2  Ei(er) (Größe M)"`, `"100 g Pancetta (oder …, , alternativ Bacon)"`:
   - Trim whitespace; strip trailing `(…)` parentheticals into `raw` only (not `name`).
   - Amount may be integer, comma-decimal (`0,5` → `0.5`), fraction (`½`, `1/2` → decimal),
     or range (`2-3`/`2–3` → `amount:2, amount_max:3`). Otherwise `amount:null`.
   - Recognize German units: `g, kg, ml, l, EL, TL, Prise, Bund, Dose, Stück, Pck., Msp.`.
     A bare count with no unit (`2 Ei(er)`) → `amount:2, unit:null`.
   - Amount-less items (`Salz`, `etwas …`, `n. B.`) → `amount:null, unit:null`.
   - On any failure, keep `raw`, null out `amount/amount_max/unit` — never drop the
     ingredient.
4. **Instruction parsing.** `recipeInstructions` has **three shapes** — handle all:
   - a plain **string** (split on newlines) →
   - a **`HowToStep[]`** (take each `.text`) →
   - a **`HowToSection[]`** whose `itemListElement` is a `HowToStep[]` — **this is the
     real Chefkoch shape** and was missing from v2; flatten sections in order, taking
     each step's `.text`. A parser that only handled the first two forms would yield
     **zero steps** on real recipes.
5. **Fallback:** if no `Recipe` JSON-LD is found, surface a clear
   `NO_RECIPE_FOUND` error rather than guessing.

**Failure modes to handle explicitly:** URL not on `chefkoch.de`; page fetch failed
(no connection); **non-browser UA served a block page** (detect tiny/again non-`Recipe`
body → surface as a fetch error); no JSON-LD; malformed JSON-LD; missing image (show a
placeholder).

Keep `RecipeParser` a **pure, dependency-free Dart module** with unit tests against a
handful of saved real Chefkoch pages — it's the piece most likely to need fixes.

---

## 7. App (Flutter) — Screens

1. **Recipe List** — grid/list of cards (image, title). Search bar filters by title;
   tag chips filter the collection. All local SQL queries — instant.
2. **Recipe Detail** — image, title, source-link + attribution, times, ingredients,
   steps, and the **serving scaler**.
3. **Import** — a URL field plus an **Android share-target** (share a link straight
   from Chefkoch into Cookbook). Shows progress and clear errors.
4. **Tag editing** — add/remove tags on a recipe.

### Serving scaler
- Display-only; **does not mutate stored data.**
- **Hidden entirely when `base_servings` is null** (yield couldn't be parsed).
- `factor = target / base_servings`; each ingredient with a numeric `amount` is shown as
  `amount * factor`. Ranges scale both bounds and render `low–high`. Amount-less
  ingredients show unchanged.
- **Rounding rules** (concrete):
  - Scaled value ≥ 10 → round to nearest integer (`245 g`).
  - Between 1 and 10 → round to 1 decimal (`2,5 EL`), German comma separator in display.
  - Below 1 → round to 2 decimals (`0,25 TL`).
  - **Countable units** (`Stück`, `Ei`, bare counts) → round to nearest ½ and render
    fractions where natural (`2,66 → 2 ½`); never show `2,66 Ei(er)`.
  - Display uses `,` as the decimal separator (German locale).

---

## 8. Storage & Persistence

- **Drift (SQLite)** on-device. Relational `recipe_tags` for fast tag filtering.
- **Search: Drift FTS5 virtual table** indexing `title`, joined `tag`s, and ingredient
  `name`s. `unicode61` tokenizer with `remove_diacritics=2` so `ä≈a`, case-insensitive.
  Query prefixes the term with `*` for prefix matching; results ranked by FTS `rank`.
  The FTS row is (re)written whenever a recipe is inserted, overwritten, or deleted.
- **Tag filtering:** selecting multiple tag chips is **AND** (narrows the collection);
  combined with a search term, both must match.
- Access goes through a **`RecipeRepository` interface**; v1 ships
  `LocalRecipeRepository` only. This is the single seam where a future
  `SyncedRecipeRepository` plugs in (§12) — the UI never imports Drift directly.
- **Migrations:** Drift `schemaVersion` + `MigrationStrategy`; `recipes.schema_version`
  (per-row) lets the parser re-normalize old rows independently of the DB schema.
- **Backup (in v1):** because data lives only on the device, a lost/wiped phone loses
  the collection. v1 ships a manual **JSON export/import** of the full collection as a
  safety net — and it doubles as the migration format for future cloud sync. Android
  auto-backup is a secondary layer. Format below.

### JSON export/import format

Export writes a single UTF-8 `.json` via the OS share sheet / save dialog
(`file_picker` / `share_plus`); import reads one back via the file picker.

```jsonc
{
  "app": "cookbook",
  "format_version": 1,          // bumped independently of recipe schema_version
  "exported_at": "2026-07-07T10:00:00Z",
  "recipes": [
    {
      "source_url": "https://www.chefkoch.de/rezepte/…/….html",
      "title": "…", "author": "…", "image_url": "…",
      "base_servings": 2, "prep_minutes": 15, "cook_minutes": 10,
      "total_minutes": 25, "rating": 4.7, "schema_version": 1,
      "imported_at": "2026-07-07T09:00:00Z",
      "ingredients": [ /* the {amount, amount_max, unit, name, raw} objects */ ],
      "steps": ["…"],
      "tags": ["hauptspeise", "pasta"]
    }
  ]
}
```

- **Import is merge-by-`source_url`, overwrite on conflict** — consistent with the
  re-import rule (§2). Rows in the file replace matching local rows; new URLs are added;
  local-only rows are left untouched (import never deletes).
- Reject files with an unknown `format_version` with a clear message rather than
  partially importing.
- `id` is intentionally **not** exported (it's a local autoincrement); identity is the
  `source_url`.

---

## 9. Offline Behavior

- The recipe list, details, search, tags, and scaling are **fully offline** — it's all
  local.
- **Import needs a connection** (fetches a live page); surfaced clearly in the UI.
- **Images load live** from Chefkoch's CDN and need a connection the first time a recipe
  is viewed; they're cached on-device afterward. A never-seen-online image shows a
  placeholder until connected.

---

## 10. Non-Functional

- **Cost:** none — no backend, no cloud bill.
- **Reliability:** import breaks only if Chefkoch changes markup/blocks access; on-device
  parser means a fix ships as an app update. Everything else is local and dependency-free.
- **Privacy:** all data stays on the device.
- **Performance:** personal-scale collections (hundreds of recipes) are trivial for SQLite.

---

## 11. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Chefkoch changes/removes JSON-LD | Imports break | Isolated, tested parser module; JSON-LD is comparatively stable; ship a fix as an app update. |
| Chefkoch blocks the device's requests | Import fails | **Browser-like User-Agent is required** — verified: a non-browser UA gets a 184-byte block, a browser UA gets the full page. On-device fetch also uses a residential IP (a second, weaker signal); one request per action + backoff. |
| Device lost/wiped | Whole collection gone (no cloud backup) | JSON export/import (v1); Android auto-backup as a secondary layer. |
| On-device parser needs frequent fixes | App-update churn | Keep parser small & tested; this is the main cost of dropping the server. |
| Copyright / ToS | Legal exposure | Personal, single-device use; no sharing; retain attribution & source URL. |
| Ingredient parsing errors | Wrong scaled amounts | Always keep `raw`; null-out uncertain amounts instead of guessing. |

---

## 12. Future: Cloud Sync (parked, not v1)

When cloud returns, the plan is **Firebase**, added behind the existing
`RecipeRepository` seam so the UI is untouched:

- **Firebase Auth** with Google Sign-In (one owner) → one-tap login, auto-provisioned
  account, same `uid` on every device ⇒ restores **cross-device sync**.
- **Cloud Firestore** with offline persistence mirrors the local schema; a
  `SyncedRecipeRepository` reconciles local Drift data with Firestore.
- **Cloud Storage** (optional) to copy hero images for full offline image access —
  weighed against storing a copyrighted asset.
- Optionally move the parser into a **Cloud Function** so future markup fixes are a
  server redeploy instead of an app update.

Designing v1 with structured data + a repository interface + `schema_version` keeps this
migration low-friction.

---

## 13. Resolved Decisions

1. **Duplicate re-imports:** **Overwrite** the existing recipe, matched by `source_url`
   (§2). Safe because imported fields are read-only.
2. **Manual editing:** **Read-only** imported fields; **tags** are the only editable
   field (§2).
3. **Search scope:** **title + tags + ingredients**, via FTS5 (§8).
4. **User-Agent:** **browser-like** — required for imports to succeed (§2, §11).
5. **State management:** **Riverpod** (§2).
6. **Local DB:** **Drift (SQLite)** — cleaner path to cloud than Isar.
7. **Amounts:** fractions → decimals; ranges → `amount`/`amount_max`; uncertain → null (§5).
8. Cross-device sync stays deferred to cloud (§12); JSON export/import is in v1 scope (§8).

---

## 14. Suggested Build Order

1. Flutter app skeleton + Riverpod + Drift DB (incl. FTS5 table) +
   `RecipeRepository` / `LocalRecipeRepository`.
2. `RecipeParser` (JSON-LD → normalized Recipe) with unit tests over saved real pages —
   **cover all three `recipeInstructions` shapes, `P0DT0H15M` durations, `"2 Portionen"`
   yields, comma-separated `keywords`, and messy ingredient strings** from §6.
3. Import flow: URL extraction + host validation + browser-UA fetch → parse → save
   (overwrite by `source_url`); Android share-target.
4. List + Detail screens (read from local DB), image loading via `cached_network_image`.
5. Search (FTS5), tags (AND filter), serving scaler (rounding rules from §7).
6. JSON export/import (format §8) + polish: error states, empty states, placeholders.
