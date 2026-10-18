# Do You Need It? — Forever Beta

## Unreleased

- Refines compact Settings: Auto whisper and Delay sit side by side, Appearance fields clear the heading, and the quality column moves right without increasing window height.

## 1.0.1 - 18-Oct-2026 — Fonts, filters and window resizing

- Adds the same quality checkboxes on the right of Settings as Retail, with saved
  settings and reversible filtering of current loot, history and Demo.
- Fits Settings into the same compact window as loot, with whispers and appearance
  on the left. Switching views keeps the same dimensions.
- Adds lower-right corner resizing, adapting comparison widths and visible rows.
  Window size is saved across reloads.
- Disabled qualities do not open the window or start automatic whispers; queued
  sends are cancelled, and showing old rows does not send retroactive requests.
- Restores the full compatible bundled and SharedMedia font list when the
  client applies a font without returning `true`. Font previews and selection
  verify the applied face, size and style, allowing tiny client size-rounding
  differences; unavailable faces remain excluded.
- Loads cold font assets through a separate attached font object, so the whole
  compatible catalogue is available without manually warming individual faces.
- Adds `/dyni fontdiag` to record a small font-loading report for troubleshooting.
- Uses the shared “Do You Need It?” window title without a client suffix.
- Fixes Demo rows remaining labelled `Item #…` when the beta client cannot
  resolve an old example item. Unavailable examples are now omitted.
- Uses complete item hyperlinks returned by the client, preserving localized
  names, quality colors and the correct tooltip target.
- Uses loaded character equipment as additional beta examples. Demo can contain
  fewer than twelve items when the catalogue is incomplete.
- Builds paired comparisons only from resolved items; a missing second ring or
  trinket no longer creates a placeholder link.
- Refreshes the preview when item data arrives, with a bounded loading state and
  localized guidance when no examples are available. Late callbacks cannot reopen
  a dismissed demo.
- Item names and tooltips were confirmed in the Forever client after reload.
  Real group loot, inspection timing, combat and whisper delivery remain beta
  coverage. Automatic whispers remain off by default.

## 1.0.0 - 18-Oct-2026 — First Forever beta

### Loot and equipment

- Adds a separate build for WoW Forever beta 1.60.1 (Interface 16001).
- Tracks group gear drops using the client's localized loot messages, item
  catalogue, instance names and encounter events. No Retail dungeon list is used.
- Compares bows, guns, crossbows, wands, thrown weapons and relics against the
  ranged slot, while preserving separate main-hand and off-hand comparisons.
- Uses the beta client's item usability result for learned proficiencies and
  level requirements, including leveling characters without a specialization.
- Keeps both rings, trinkets and compared weapons on separate tooltip targets.
- Does not apply Retail's personal-loot item-level trade estimate to Forever.
  BoP drops remain “Check with looter” unless a trade timer is detected; unbound,
  BoE and bind-on-use items retain their binding-based estimate.
- Preserves delayed item loading, inspect retries, cached equipment labels,
  group departure cancellation and encounter history.

### Shared interface

- Includes the stable loot window, encounter selector, saved position, Settings,
  optional whispers, configurable delay and message, and all `/dyni` commands.
- Automatic whispers remain off by default. Demo rows never send whispers or
  enter saved history.
- Includes the same 46 bundled fonts, favorites, previews, language selection
  and non-Latin fallback as Retail.
- The title, addon list and diagnostics identify Forever Beta. Demo equipment
  uses Classic-era item IDs with names resolved from the beta client; examples
  do not claim to represent a beta dungeon's actual loot table.

### Distribution and beta limits

- Forever has its own version, changelog, `forever-v` tags and beta ZIP. Retail
  remains on its independent stable channel.
- Install only in the Forever beta client's AddOns directory. Other Classic
  branches and Retail are not targets of this package.
- Client self-check confirms startup after reload, command registration, saved
  settings, window geometry and demo rendering on Interface 16001.
- Offline regressions and archive checks cover both flavors. Native group loot,
  inspection timing, combat, font rendering and whisper delivery remain beta checks.
- Another player's final trade eligibility is not exposed to the addon. Ask the
  looter to confirm; beta client changes may affect API availability and behavior.
