# Do You Need It? — Forever Beta

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
- Offline regressions and archive checks cover both flavors. Native group loot,
  inspection, combat, font rendering and reload acceptance remain beta checks.
- Another player's final trade eligibility is not exposed to the addon. Ask the
  looter to confirm; beta client changes may affect API availability and behavior.
