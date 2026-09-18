# LifeOS — implementation brief

You are implementing **LifeOS**, a personal-life operating system (finance, habits, health incl. medication scheduling, gym, Learn/notes, to-dos, calendar).

Target stack: **Flutter** (iOS + Android) with **Supabase** (Postgres + Auth + Realtime + Edge Functions). If the repo already has an established stack, use that instead and map the specs onto its patterns.

## Read in this order

1. **`BRAND_AND_UI_KIT.md`** — the design system: app icon spec, complete token set (per-theme semantic colour pairs), icon family, every reusable component with exact measurements and Flutter mappings, motion/haptics tables, accessibility floor.
2. **`README.md`** — screen-by-screen specs, Supabase schema summary, state management, suggested Flutter file structure, package list.
3. **`supabase_schema.sql`** — the actual DDL, RLS policies, balance trigger, recurring-posting function.

## The HTML files are references, not source

`LifeOS UI Kit.dc.html` and `LifeOS.dc.html` are **interactive design prototypes**. Open them in a browser to see intended look, motion and behaviour, and read them for exact values. **Do not port their markup or their runtime (`support.js`) into the app.** Recreate the designs with idiomatic Flutter widgets.

The UI kit page has a light/dark toggle in its header and every control is live — use it as the visual source of truth while building shared widgets.

## Build order (do not skip)

1. `theme.dart` — transcribe every token from `BRAND_AND_UI_KIT.md` §2 into a `LifeOSColors` class with light/dark variants, plus a `ThemeExtension` for the semantic (`danger`/`warn`/`warm`/`cool`/`deep`) and category pairs. **Finish this before anything else** so that writing a raw hex becomes impossible.
2. `motion.dart` and `haptics.dart` — the duration/easing and haptic tables from §5 as named constants. Gate all haptics behind `settings.haptics_enabled`.
3. `shared/widgets/` — the component inventory in §4, in order: `Tappable` (press scale + haptic), buttons, fields, selection controls, then rows/cards/progress. Build each one against the kit page open side by side.
4. Screens — `README.md` "Screens / Views" then becomes assembly.
5. Launcher icons — `flutter_launcher_icons` from `brand/app-icon-1024.png`. For Android adaptive icons use the brand ground as `adaptive_icon_background` with a ring-only foreground at 66% scale; do not hand the full-bleed square to the foreground slot.

## Hard rules

- **No raw hex outside `theme.dart`.** Every colour is a token.
- **Semantic colours are per-theme pairs.** A status ink that works on cream is invisible on near-black. Never reuse a light-theme semantic hex in dark mode. The pairs are in §2.
- **`text-2` carries informational text; `text-3` is decorative only.** `text-3` does not meet 4.5:1 in either theme.
- **44 px minimum touch target**, regardless of visual size.
- **Success is `accent`.** There is no second green.
- **Category hues identify things, never state.** Raw hue for wells/swatches/dots only; use its `cool`/`deep`/`warm` ink when it carries text.
- **Tabular figures** on every number. Indian digit grouping (`₹2,48,600`, 2-2-3 lakh grouping) — not `₹248,600`.
- **Flat by default.** Cards and rows use a 1 px border, not a shadow. Shadows are for things that genuinely float.
- **Reduce-motion collapses every transition to a 160 ms cross-fade.** Check `MediaQuery.of(context).disableAnimations`.
- **Icons:** one family only — 24 px grid, 1.9 px stroke, round caps, no fills, `currentColor`. `lucide_icons` matches; do not mix in Material or Cupertino glyphs.
- **State is never colour alone** — an icon, label or position must carry it too.

## Copy voice

Say what is true, then what to do. Destructive dialogs name the consequence ("Its 18 logged doses stay in your history"), never just "This cannot be undone". Empty states are specific ("You're clear until Thursday"), never "No items found". No exclamation marks, no emoji.

## Not yet designed

Planner detail (exercise + diet), Calendar & Notes, Investments detail, and the To-dos/Reminders screen. Build navigation destinations and route stubs for them; the designs follow. Do not invent these screens — ask first.
