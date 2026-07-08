# Manual Recipe Entry — Design

Date: 2026-07-07
Status: Approved for planning

## Goal

Let the user create recipes by hand (not just import from chefkoch.de) and edit
existing recipes through the same form. Manual and imported recipes behave
identically afterwards: same list, search, tags, serving scaler, and backup.

## Data model

No schema change. Manual recipes reuse the existing `recipes` table and
`Recipe` model with a **synthetic sourceUrl**: `manual:<microsecondsSinceEpoch>`,
generated once at creation and kept stable across edits.

- `Recipe.isManual` getter: `sourceUrl.startsWith('manual:')`.
- `RecipeRepository.saveRecipe` upserts by sourceUrl, so create and edit both
  go through the existing method unchanged. Edits save with the default
  `TagMode.seedIfNew`, which preserves the recipe's existing tags.
- Fields never set by the form: `imageUrl` (manual recipes show the fallback
  icon), `rating` (chefkoch-specific).
- `totalMinutes` is computed as prep + cook (sum of whichever are present;
  null if both are empty). Not a separate input.
- Backup export/import needs no changes: manual recipes are ordinary rows and
  round-trip through the existing JSON format.

## UI

### Entry point (recipe list screen)

The FAB no longer navigates straight to the import screen. It opens a small
menu (modal bottom sheet) with two options:

1. **Import from URL** → existing `ImportScreen`
2. **Add manually** → new `RecipeFormScreen()`

The empty-state hint text ("Tap + to import your first recipe from
chefkoch.de.") is updated to mention both options.

### New screen: `RecipeFormScreen`

`lib/src/ui/recipe_form_screen.dart`, constructor `RecipeFormScreen({Recipe?
existing})`. `existing == null` → create mode ("Add recipe" title);
non-null → edit mode ("Edit recipe" title), all fields pre-filled.

Fields:

| Field | Input | Validation |
|---|---|---|
| Title | text | required (non-empty after trim) |
| Author | text | optional; empty saves as `''` (detail screen already renders that as "Unknown author") |
| Servings | number | optional; positive int |
| Prep time (min) | number | optional; non-negative int |
| Cook time (min) | number | optional; non-negative int |
| Ingredients | multiline text, one per line | at least one non-empty line |
| Steps | multiline text, one per line | at least one non-empty line |

Tags are deliberately **not** in the form — they remain edited via the
existing tag editor sheet on the detail screen, for all recipes.

On save:

- Each non-empty ingredient line runs through the existing `parseIngredient()`
  (`lib/src/parser/ingredient_parser.dart`), so amounts/units are structured
  exactly like imported recipes and the serving scaler works.
- Steps are the non-empty lines, in order.
- Create: build a `Recipe` with a fresh `manual:` sourceUrl and
  `importedAt = now`. Edit: preserve `id`, `sourceUrl`, `imageUrl`, `rating`,
  `tags`, and `importedAt` from the existing recipe; replace everything else.
- Call `repository.saveRecipe(...)` (default TagMode), then navigate: create
  replaces the form with `RecipeDetailScreen`; edit pops back to the detail
  screen (which live-updates via its stream provider).

Pre-filling in edit mode reconstructs the textboxes from `Ingredient.raw`
lines and the steps list, so an imported recipe round-trips losslessly if the
user changes nothing.

### Detail screen adjustments

- New app-bar edit (pencil) button on every recipe, pushing
  `RecipeFormScreen(existing: recipe)`.
- For manual recipes the "By {author} · chefkoch.de" link is replaced with
  plain, non-tappable "By {author}" text (there is no real URL to open).

## Edit semantics and caveats

- Editing is available for **all** recipes, imported ones included.
- Known, accepted caveat: re-importing a chefkoch URL still overwrites the
  local row (existing upsert-by-URL behavior), so edits to an imported recipe
  are lost on re-import. Tags survive, as today.
- This supersedes the earlier "tags are the only editable field (§2)"
  constraint; the stale comment in `tag_editor_sheet.dart` is updated.

## Error handling

- Form validation errors render inline under the offending field
  (`Form`/`TextFormField` pattern); Save is a no-op until the form validates.
- `saveRecipe` failures (unexpected DB errors) surface as a SnackBar; the form
  stays open so input is not lost.

## Testing

- Unit: manual-recipe construction helper (line splitting, ingredient parsing
  passthrough, totalMinutes computation, synthetic-URL stability on edit).
- Widget: form validation (empty title/ingredients/steps blocked), create
  flow saves and navigates, edit flow pre-fills and preserves
  id/sourceUrl/tags/importedAt.
- Widget: detail screen hides the source link for manual recipes and shows
  the edit button.

## Out of scope

- Photos for manual recipes (camera/gallery/local storage).
- Structured per-row ingredient inputs.
- Editing tags inside the form.
