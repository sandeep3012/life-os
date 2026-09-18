# LifeOS — Brand, Icon & UI Kit

Companion to `README.md`. That file covers the **screens**; this one covers the **system** they're built from — the app icon, the full token set, and every reusable component with its Flutter mapping.

Reference file: **`LifeOS UI Kit.dc.html`** (open it in a browser; the header has a light/dark toggle and every control is live). Brand assets: **`brand/`**.

---

## 1. App icon

### Concept
An **open ring with a single dot resting in the gap** — the loop of a day, and the one thing that comes next. Nothing else. No monogram, no glyph, no metaphor pile-up.

### Geometry (share of icon size `s`)

| Property | Value | Notes |
|---|---|---|
| Corner radius | `0.2237 × s` | iOS squircle approximation (quadratic corners) |
| Ring centre | `0.5s, 0.5s` | |
| Ring radius | `0.295 × s` | `0.285 × s` at ≤48 px |
| Ring stroke | `0.118 × s` | `0.145 × s` at ≤48 px |
| Gap | 70° centred on **−60°** (upper right) | 84° at ≤48 px |
| Dot centre | on the ring path at −60° | |
| Dot radius | `0.082 × s` | `0.105 × s` at ≤48 px |
| Cap | round | both ring ends |

Angles are canvas convention: 0° = right, positive clockwise, y-down.

**Why the small-size branch:** below ~48 px the stroke thins past a pixel and the dot merges into the ring. Thicken the stroke, widen the gap, enlarge the dot — the mark still reads as the same shape.

### Colour variants

| Variant | Ground | Ring | Dot | Use |
|---|---|---|---|---|
| **Primary** | 135° gradient `#0A6E4D → #0C8058` + a top-left white radial at 16%→0% | `#F5F1E9` | `#34D399` | default everywhere |
| **Paper** | `#F5F1E9` | `#0B7C56` | `#0E9F6E` | print, invoices, light watermarks |
| **Ink** | `#0C0B09` | `#F4F0E7` | `#34D399` | dark UI, splash, merch |

### Files in `brand/`

| File | Size | Mask | Target |
|---|---|---|---|
| `app-icon-1024.png` | 1024 | squircle | master / App Store listing |
| `app-icon-512.png` | 512 | squircle | general |
| `app-icon-192.png` | 192 | squircle | PWA, web manifest |
| `apple-touch-icon-180.png` | 180 | **full bleed** | iOS — the OS applies its own mask |
| `app-icon-playstore-512.png` | 512 | **full bleed** | Play Store — ditto |
| `app-icon-light-1024.png` | 1024 | squircle | Paper variant |
| `app-icon-mono-1024.png` | 1024 | squircle | Ink variant |
| `favicon-64.png` / `-32.png` / `-16.png` | 64 / 32 / 16 | full bleed | web |
| `favicon.ico` | 32 (PNG-embedded) | full bleed | legacy web |
| `icon-gen.js` | — | — | the generator; re-render any size from it |

**Flutter:** feed `app-icon-1024.png` to `flutter_launcher_icons`. For Android adaptive icons, supply the **Ink or Primary ground as `adaptive_icon_background`** and a ring-only foreground at 66% scale so the OS's mask and parallax don't clip the dot — do **not** hand the full-bleed square to the foreground slot.

**Clear space:** equal to the icon's corner radius on all four sides. Never re-colour the dot, rotate the ring, outline the mark, or set the wordmark below weight 600.

### Lockups
- **Horizontal:** 38 px icon + 13 px gap + "LifeOS" at 24 px / 800 / −0.7 tracking.
- **Stacked:** 46 px icon, 10 px gap, "LifeOS" 19 px / 800 / −0.5, then the tagline "EVERYTHING, IN ONE LOOP" at 10 px / 800 / 1.7 tracking / uppercase in `text-3`.

---

## 2. Tokens

Two themes. Everything is a token — **no raw hex in component code.**

### Neutrals & accent

| Token | Light | Dark |
|---|---|---|
| `stage` | `#E7E2D8` | `#0C0B09` |
| `bg` | `#F5F1E9` | `#161512` |
| `surface` | `#FFFFFF` | `#201E1A` |
| `surface-2` | `#FAF6EE` | `#2A2823` |
| `raised` (bottom nav) | `#FFFFFF` | `#26241F` |
| `text` | `#1C1B18` | `#F4F0E7` |
| `text-2` | `#6E6A61` | `#A9A499` |
| `text-3` | `#9C978C` | `#736F66` |
| `border` | `rgba(28,27,24,.09)` | `rgba(255,255,255,.10)` |
| `border-2` | `rgba(28,27,24,.06)` | `rgba(255,255,255,.05)` |
| `accent` | `#0E9F6E` | `#34D399` |
| `accent-ink` | `#0B7C56` | `#6EE7B7` |
| `accent-soft` | `rgba(14,159,110,.12)` | `rgba(52,211,153,.16)` |
| `btn` | `#0B7C56` | `#34D399` |
| `on-accent` | `#FFFFFF` | `#0C0B09` |
| `hero-a → hero-b` | `#0A6E4D → #0C8058` | `#34D399 → #6EE7B7` |
| `code-bg` | `#F1ECE2` | `#15140F` |

### Semantic states — **token pairs, one value per theme**

This is the part that is easy to get wrong: a semantic ink that works on cream is invisible on near-black. Every status colour therefore has two values.

| Token | Light | Dark | Use |
|---|---|---|---|
| `danger` | `#A62F2F` | `#F87171` | destructive labels, overdue, error text |
| `danger-solid` | `#A62F2F` | `#E05555` | filled destructive button ground |
| `on-danger` | `#FFFFFF` | `#230A0A` | ink on `danger-solid` |
| `danger-soft` | `rgba(190,63,63,.09)` | `rgba(248,113,113,.13)` | tinted error wells |
| `danger-bd` | `rgba(190,63,63,.35)` | `rgba(248,113,113,.34)` | error borders |
| `warn` | `#8A6410` | `#E3B341` | due soon, low stock, offline |
| `warn-soft` | `rgba(217,164,65,.13)` | `rgba(227,179,65,.14)` | |
| `warn-bd` | `rgba(217,164,65,.3)` | `rgba(227,179,65,.32)` | |
| `warm` | `#8C4C22` | `#E09A6B` | streaks, outgoing money |
| `warm-soft` | `rgba(194,112,61,.16)` | `rgba(224,154,107,.15)` | |
| `cool` | `#35618A` | `#8FBBE0` | water, calendar, medicine glyphs |
| `cool-soft` | `rgba(75,123,166,.16)` | `rgba(143,187,224,.15)` | |
| `deep` | `#5E4FA8` | `#B4A7EC` | learn, investments |
| `deep-soft` | `rgba(124,107,196,.16)` | `rgba(180,167,236,.15)` | |

**Success has no separate token** — it is `accent` / `accent-ink` / `accent-soft`. Green is the brand and the success state; there is no second green.

### Category hues — identity only, never state
`Water #4B7BA6` · `Learn #7C6BC4` · `Mind #3FA6A0` · `Spend #C2703D` · `Due #D9A441` · `Body #B0558E`

These identify a thing (which habit, which category). They never communicate status — that's what the semantic tokens are for. When a category hue carries **text** in either theme, use its `cool` / `deep` / `warm` ink instead of the raw hue; the raw hue is for 14–18% alpha wells, swatches and dots only.

### Type

Family: **Manrope** 400–800 for everything. **JetBrains Mono** 400/600 for IDs, file names and code only.

| Role | Size | Weight | Tracking | Line height |
|---|---|---|---|---|
| Display (money) | 34 | 800 | −1.1 | 1.05 |
| Title | 26 | 800 | −0.7 | 1.15 |
| Heading | 19 | 800 | −0.4 | 1.2 |
| Row title | 15 | 700 | 0 | 1.3 |
| Body | 14 | 500 | 0 | 1.55 |
| Meta | 12 | 600 | 0 | 1.4 |
| Label (overline) | 11 | 800 | 1.2 | uppercase |

All figures **tabular** (`fontFeatures: [FontFeature.tabularFigures()]`) so numbers don't jitter as they update. Indian digit grouping throughout: `₹2,48,600`.

### Spacing, radius, elevation

**Spacing** — 4-point rhythm: `4` icon↔label · `8` chip gaps · `12` card gaps · `16` screen padding · `24` section gaps · `32` block breaks.

**Radius** — `8` swatches · `12` chips/tiles · `16` inputs & rows · `22` cards · `999` pills. **Nested corners step down by 4:** a 16 px card holds a 12 px tile holds an 8 px swatch.

**Elevation** — three levels only:
- **Flat** — `1px border`, no shadow. Cards, list rows. (The default; most of the app is flat.)
- **Raised** — `0 6px 18px -10px rgba(30,28,22,.3)`. FAB, pressed states.
- **Overlay** — `0 24px 60px -28px rgba(30,28,22,.42), 0 4px 14px -8px rgba(30,28,22,.18)` light / `0 24px 70px -28px rgba(0,0,0,.75), 0 4px 14px -8px rgba(0,0,0,.5)` dark. Sheets, dialogs, toasts.

---

## 3. Iconography

One family, no exceptions: **24 px grid · 1.9 px stroke · round caps and joins · no fills · `currentColor`.**

The 24 icons in the kit: home, wallet, habit, health, learn, calendar, todo, chart, bell, search, plus, chevron, trend-up, filter, star, streak, medicine, gym, time, theme, person, delete, edit, settings.

Sizes in use: **24** (nav, empty states) · **22** (tab bar) · **19** (row leading, icon buttons) · **17** (inline with body) · **15/14** (inside small wells) · **11–13** (badges).

**Flutter:** `lucide_icons` is the closest match to this set — its stroke weight and terminal style line up. Where a shape differs (medicine, streak, learn), copy the path from the kit into a `CustomPainter` or `flutter_svg` asset. Do **not** mix in Material or Cupertino icons; their optical weight is visibly different next to these.

---

## 4. Component inventory

Every component below is live in `LifeOS UI Kit.dc.html` — press it there to see its states.

### Buttons

| Variant | Height | Radius | Ground | Ink | Border |
|---|---|---|---|---|---|
| Primary | 48 | 14 | `btn` | `on-accent` | — |
| Secondary | 48 | 14 | `surface` | `text` | `1px border` → `accent` on hover |
| Ghost | 48 | 14 | transparent → `accent-soft` on hover | `accent-ink` | — |
| Destructive | 48 | 14 | `danger-soft` | `danger` | `1px danger-bd` |
| Destructive solid | 42 | 12 | `danger-solid` | `on-danger` | — |
| Disabled | 48 | 14 | `surface-2` | `text-2` | `1px border`, `cursor: not-allowed` |
| Loading | 48 | 14 | `btn` @ 90% | `on-accent` | 15 px spinner, `spin .7s linear infinite` |

Sizes: **48** default · **40** medium · **32** small · **44×44** icon button · **56** FAB (radius 19, shadow `0 10px 24px -10px rgba(11,124,86,.7)`).

Weights: primary/ghost/destructive **800**, secondary **700**. Press: `scale(.97)` over 120 ms.

### Fields
50 px total / **48 px** control height, radius 14, ground `surface-2`, `1px border`, value 14 px / 600. Label above: 12 px / 800 / `text-2`, 7 px gap.

- **Focus:** border → `accent`, ground → `surface`.
- **Prefix/suffix:** flex row inside the field — `₹` at 15 px / 800 / `text-3` leading, category pill trailing.
- **Error:** border `danger-bd`, ground `danger-soft`, message below at 11.5 px / 700 / `danger` with a 13 px alert icon, 7 px gap.
- **Textarea:** same box, `padding: 12px 14px`, `resize: vertical`, line-height 1.5.
- **Search:** leading 17 px search glyph in `text-2`, 10 px gap.

### Selection controls

- **Segmented** — 4 px-padded `surface-2` track, radius 14, `1px border`; each segment 38 px, radius 10, 13 px / 800. Selected segment gets `surface` ground and `text` ink; unselected are transparent with `text-2`.
- **Filter chips** — 36 px, radius 11, 12.5 px / 800. Selected: `accent` ground + `on-accent` ink + `accent` border. Unselected: transparent + `text-2` + `border`.
- **Toggle** — 50×30 track, radius 15, 3 px padding, 24 px white knob with `0 1px 3px rgba(0,0,0,.3)`. On: `accent`. Off: `#D8D3C7` light / `#3A3833` dark. 180 ms.
- **Checkbox** — 26 px, radius 9, `2px` border. Checked: `accent` ground + `accent` border + `on-accent` tick (3 px stroke). Unchecked: transparent ground + `border`.
- **Radio row** — equal-width buttons, min 44 px, radius 12, 12.5 px / 800. Selected: `accent-soft` ground + `accent` border + `accent-ink` ink.
- **Stepper** — 44 px `−` (secondary) and `+` (primary) flanking a centred value at 22 px / 800 tabular with an 11 px / 700 unit caption. Press `scale(.94)`.

Every one of these has a **44 px minimum hit area** even where the visual is 26–36 px. In Flutter, wrap in `SizedBox(height: 44)` or set `materialTapTargetSize`.

### Data display

- **Linear progress** — 9 px, radius 5, track `surface-2`, fill the category hue. `width` transitions 300 ms `cubic-bezier(.2,.8,.2,1)`.
- **Ring progress** — 76 px conic ring, 56 px `surface` hole, percentage centred at 15 px / 800 tabular. **Rings for rates, bars for counts.**
- **Week strip** — 7 equal columns, 34 px tall, radius 9. Filled = `accent`; empty = `surface-2` + `1px border`; today = `accent-soft` + `1.5px dashed accent` with its letter in `accent-ink` / 800.
- **Badges** — 5/10 px padding, radius 8, 11 px / 800. Soft ground + matching ink from the semantic or category pair. Notification badge: min 19 px, radius 10, `danger-solid` ground, `on-danger` ink, `2px surface` ring, offset −4/−4.
- **Avatars** — 40 px radius 13 (34 px radius 11 small). Gradient `hero-a → hero-b` with white initials at 15 px / 800, or a category-tinted well with the category ink.
- **Skeleton** — 13 px bars, radius 7, `linear-gradient(90deg, surface-2 25%, border 50%, surface-2 75%)` at `200% 100%`, `shimmer 1.4s linear infinite`. Widths vary (62% / 88% / 44%) — never uniform.

### Cards & rows

- **Hero card** — radius 20, `140° hero-a → hero-b`, white ink. Overline 11 px / 800 / 1.1 tracking at 72% opacity; figure 31 px / 800 / −1.1; delta row 12.5 px / 700 with a 14 px trend glyph; progress track `rgba(255,255,255,.28)` with a white fill.
- **List row** — `surface-2` ground, `1px border`, radius 16, `14px 15px` padding, 13 px gap. 40 px radius-12 icon well at the category hue's soft alpha; title 14 px / 700; sub 12 px / 600 / `text-3`; trailing badge or value. Hover: border → `accent`. Done state: `opacity .6` + `line-through` on the title.
- **Stat tile** — radius 16, `surface-2`, `1px border`, 14 px padding. 28 px radius-9 well, then label 11 px / 700 / `text-2`, then value 16 px / 800 tabular.

### Navigation

- **App bar** — 40 px radius-12 `surface-2` icon buttons flanking a 16 px / 800 / −0.3 title, 12 px gap, `border-2` bottom hairline.
- **Underline tabs** — 13.5 px, active **800** + `text` + `2.5px accent` underline; inactive **700** + `text-3`.
- **Bottom tab bar** — floating, radius 20, `raised` ground, `1px border`, overlay shadow. 22 px icon over a 10 px / 800 label, 5 px gap. Active `accent-ink`, inactive `text-3`.

### Overlays

- **Bottom sheet** — top radius 20, `surface-2`, overlay shadow. 38×4 grabber centred with 16 px below; title 17 px / 800 / −0.3 with a 32 px radius-10 close button; primary action pinned at the bottom, 50 px, radius 15.
- **Toast** — `#0F0F0D` ground (dark in **both** themes), radius 14, `12px 15px`. 16 px `#34D399` glyph + 13 px / 700 `#F4F0E7` label + an `#34D399` / 800 action. Dwell **3.2 s**.
- **Destructive dialog** — radius 16, `danger-soft` ground, `1px danger-bd`. Title 14 px / 800 `text`, body 12.5 px / 600 `text-2`, then two 42 px buttons: "Keep" secondary, "Delete" `danger-solid`. **Always name the consequence** ("Its 18 logged doses stay in your history"), never just "This cannot be undone".

### Empty & edge states

Centred, 30/18 px padding, radius 18, `surface-2`, `1px dashed border`. 54 px radius-17 `accent-soft` well with a 25 px `accent-ink` glyph, then title 15 px / 800, body 12.5 px / 600 / `text-2` capped at **30ch**, then a 42 px primary action.

Copy rule: **say what is true, then what to do.** "You're clear until Thursday. Add a note and it'll come back when it should." — not "No items found."

**Offline banner** — `warn-soft` ground, `1px warn-bd`, 17 px `warn` alert glyph, title 13 px / 800, sub 11.5 px / 600. Name the queue depth: "Offline — 3 changes queued".

---

## 5. Motion & feedback

| Element | Duration |
|---|---|
| Press feedback | 120 ms |
| Value change | 300 ms |
| Sheet in | 340 ms |
| Screen push | 260 ms |
| Toast dwell | 3.2 s |

Easing `cubic-bezier(.2,.8,.2,1)` throughout. Press = `scale(.97)` (`.94` on small square buttons).

**Reduce-motion:** every transition above collapses to a 160 ms cross-fade. No exceptions — check `MediaQuery.of(context).disableAnimations`.

### Haptics

| Event | Intensity | Flutter |
|---|---|---|
| Selection (chip, tab, keypad) | light | `HapticFeedback.selectionClick()` |
| Logged / saved | success | `HapticFeedback.lightImpact()` + success pattern |
| Streak milestone | heavy | `HapticFeedback.heavyImpact()` |
| Destructive / error | warning | `HapticFeedback.mediumImpact()` |

Gate every call behind `settings.haptics_enabled`.

---

## 6. Accessibility floor

Non-negotiable, and the kit is measured against it:

1. **44 px minimum touch target**, always — regardless of the visual size.
2. **4.5:1 contrast** for body text; 3:1 for 19 px+ headline scale. This is why every semantic colour is a per-theme pair and why `text-2`, not `text-3`, carries informational captions — `text-3` is for decorative text only.
3. **State is never colour alone** — an icon, label or position carries it too.
4. **Type scales to 200%** without clipping. No fixed-height text boxes; cap `textScaler` at ~1.3 only where a figure would break the layout.
5. **Focus ring:** 2 px `accent`, 2 px offset, on every interactive element.

---

## 7. Building from this

Recommended order:

1. **`theme.dart`** — transcribe §2 verbatim into a `LifeOSColors` class with light/dark constructors plus a `ThemeExtension` for the semantic and category pairs. Nothing else starts until raw hex is impossible to write.
2. **`motion.dart` + `haptics.dart`** — the tables in §5 as named constants.
3. **`shared/widgets/`** — the §4 inventory, in order: `Tappable` (press scale + haptic), buttons, fields, selection controls, then rows/cards. Build them against the kit page side by side.
4. **Screens** — then `README.md` §"Screens / Views" becomes assembly rather than design.
5. **Launcher icons** — `flutter_launcher_icons` from `brand/app-icon-1024.png`, per the adaptive-icon note in §1.

A screen built before step 3 will hard-code values that step 1 exists to prevent. Resist it.

---

## Files in this bundle

| File | What it is |
|---|---|
| `README.md` | screen-by-screen spec, Supabase schema notes, Flutter structure |
| `BRAND_AND_UI_KIT.md` | this file — icon, tokens, components |
| `LifeOS UI Kit.dc.html` | **the living kit** — open first, toggle the theme, press everything |
| `LifeOS.dc.html` | the full interactive prototype (all screens, both themes, both platforms) |
| `supabase_schema.sql` | Postgres DDL, RLS policies, balance trigger, recurring-posting function |
| `brand/` | app icons, favicons, variants, and `icon-gen.js` to re-render any size |
| `support.js` | runtime the two `.dc.html` files load — keep it beside them |

Open the `.dc.html` files directly in a browser; no build step, no server.
