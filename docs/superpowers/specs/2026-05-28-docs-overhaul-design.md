# GTML — Documentation overhaul (full rewrite + restructure)

**Date:** 2026-05-28
**Status:** Design approved, awaiting implementation plan

## Summary

The docs are a mix of current v0.8 pages (bindings, focus, perf) and
v0.6-era pages that predate the entire reactive system. They live in a
flat 17-file `docs/` directory with inconsistent voice and stale
class-name references. This overhaul regenerates **all** docs from
scratch into a sectioned tree (`guide/` · `reference/` · `advanced/`)
behind a `docs/index.md` hub, adds two genuinely-missing docs (a
Reactivity concept guide and a GtmlView API reference), and switches all
class-name references to the addon's target `Gtml*` prefix.

Every documented feature is verified against source before it's written
(no vaporware). No topic is dropped — SVG and the editor pane are both
real and retained.

## Goals

- One consistent, current docs set: voice, structure, examples, naming.
- Sectioned IA (`guide`/`reference`/`advanced`) + a `docs/index.md` hub.
- Add the missing **Reactivity** concept guide and **GtmlView API** reference.
- Use the target `Gtml*` class names throughout, with a clear
  "rename in progress" banner so readers aren't misled.
- Verify every class/signal/property/attribute exists before documenting.
- Keep all internal + README links valid against the new tree.

## Non-goals

- **The source code rename `Gml*` → `Gtml*`.** That is a separate later
  PR (user's explicit sequencing). Docs use `Gtml*` ahead of the code;
  the banner discloses the gap.
- **New engine features.** Documentation only.
- **A docs site / static-site generator.** Plain markdown in `docs/`.
- **A single running example theme.** Examples are self-contained per
  page (the running-theme option was considered and not chosen).

## Architecture — file tree

```
docs/
  index.md                    NEW — hub: pitch, rename banner, grouped nav
  guide/
    getting-started.md        install · enable · add GtmlView · first static view
    reactivity.md             NEW — state→bindings→DOM model, reconcile loop, immutable updates
    bindings.md               directive catalog + expression grammar + limitations
    forms-and-inputs.md       inputs, v-model, form_submitted, :checked, @keydown
    focus.md                  keyboard/gamepad, tabindex, autofocus, focus-trap
    selectors.md              selectors + pseudo-classes
    layout.md                 flexbox + sizing
    transforms.md             translate / scale / rotate
    transitions.md            animated state changes
    tokens.md                 var() / calc() / custom properties
    fonts.md                  typography
    svg.md                    vector graphics
  reference/
    gtmlview-api.md           NEW — state API, signals, focus_first, get_element_by_id, exports
    html-elements.md          tag→Control + attributes table
    css-properties.md         the exhaustive property table
  advanced/
    editor.md                 the editor pane
    extending.md              adding elements / properties
    performance.md            the benchmark harness
    limitations.md            known limitations + deferred
```

20 files: **+3 new** (index, reactivity, gtmlview-api), **0 topics
dropped**, the remaining 17 rewritten + relocated. The 17 current flat
`docs/*.md` are removed (`git rm`); `docs/superpowers/` is untouched.

## §1 — Per-doc scope

### Guide
- **getting-started** — 2-line "what is GTML"; install + enable plugin;
  add the view node + set Html/Css paths; a static menu; pointer to
  Reactivity. Not an exhaustive feature dump.
- **reactivity** (NEW) — `state` as source of truth; bindings read it;
  `state.set` re-renders only what changed; the reconcile loop; the
  immutable-update pattern (fresh array/dict instances); `state` vs bare
  signals. Conceptual; sends readers to bindings for the catalog.
- **bindings** — directive catalog (`{{ }}`, `:attr`, `:class`,
  `v-if`/`v-show`, `v-for :key`, `v-model`, `@event(args)`), the
  expression grammar, and documented limitations (descendant-from-
  ancestor `:class`, hover collision).
- **forms-and-inputs** — every input type, `v-model` targets,
  `form_submitted`, `:checked`, `@keydown`. Cross-links bindings +
  gtmlview-api.
- **focus** — current focus.md substance, reformatted.
- **selectors / layout / transforms / transitions / tokens / fonts /
  svg** — one narrative guide each: what it does, syntax, 2-3 examples,
  gotchas, and a "see css-properties for the full table" link.

### Reference
- **gtmlview-api** (NEW) — `state.set/get/set_state/has/keys`; signals
  (`button_clicked`, `item_clicked`, `input_changed`,
  `selection_changed`, `form_submitted`, `key_pressed`, `state_changed`);
  `focus_first()`, `get_element_by_id()`, `get_form_data()`; exports
  (`html_path`, `css_path`, `fonts`, tag-default exports); lifecycle +
  hot reload. Tables + signatures. **Every member verified against
  `GmlView.gd` before writing.**
- **html-elements** — tag → Control mapping + supported attributes.
- **css-properties** — the exhaustive property table (value, notes,
  caveats). **Cross-checked against the CSS parser/resolver — only
  properties that actually resolve are listed.**

### Advanced
- **editor** — autocomplete, jumps, color picker, multi-cursor,
  find/replace.
- **extending** — how to add an element builder / CSS property (the
  engine seams).
- **performance** — the bench harness (current perf.md): how to run,
  what each group measures, caveats.
- **limitations** — known limitations + the deferred list (computed
  props, watchers, global store, etc.; note `:key` is now shipped).

## §2 — Conventions (every doc)

- **Class naming:** `Gtml*` prefix everywhere (`GtmlView`, `GtmlState`,
  `GtmlRenderer`, `GtmlBindingExpr`, `GtmlVForReconciler`,
  `GtmlFocusManager`, `GtmlClassRestyler`, `GtmlStyleResolver`, …). The
  editor node is documented as `GtmlView`.
- **Rename banner** (in `docs/index.md` + `guide/getting-started.md`):
  > ⚠ **API rename in progress.** The addon is **GTML**; its classes are
  > migrating from `Gml*` to `Gtml*`. These docs use the target `Gtml*`
  > names. If your installed build still registers `GmlView`, use that
  > name until the rename ships.
- **Verify-before-document:** quick source check per feature; drop
  anything not real. Reviewers re-verify.
- **Voice:** second person, imperative, terse. Each doc opens with a
  1-2 line "what + why", then a minimal runnable example, then detail.
  No marketing.
- **Examples:** self-contained per doc; realistic game-UI snippets;
  every code block valid GDScript/HTML/CSS.
- **Cross-linking:** relative paths within the new tree
  (`../reference/css-properties.md`); each guide ends with "See also".
- **Headers:** `# Title` + one-line summary; `##` sections, scannable.

## §3 — Index, links, README

- **`docs/index.md`** — the hub: GTML pitch, rename banner, grouped link
  list (Guide / Reference / Advanced) into the subdirs. The README's
  "Documentation" section links here first.
- **Internal links** — relative + valid from each file's location. No
  surviving `docs/<name>.md` flat links.
- **README repoint** — point "Documentation" at `docs/index.md` plus key
  pages (`guide/getting-started`, `guide/reactivity`, `guide/bindings`,
  `guide/focus`, `reference/gtmlview-api`). Flip README class refs
  `Gml*`→`Gtml*`; add the rename banner near the top.
- **Old flat files** — `git rm` the 17 current `docs/*.md`. Leave
  `docs/superpowers/` alone.
- **Orphan-link sweep** — grep the repo for any link to an old
  `docs/<name>.md` path (other docs, code comments, the addon README)
  and repoint.

## §4 — Verification

- Run the GTML test suite once at the end to confirm nothing in
  `addons/`/`tests/` referenced a removed doc path in a load-bearing way
  (docs aren't loaded by code; this just confirms no fixture/snapshot
  pointed at a doc). Expected: still 403/403.
- A final reviewer subagent checks: every documented
  class/signal/property/attribute exists in source; all internal links
  resolve; the `Gtml*` convention + banner are consistent; no old
  `docs/*.md` link remains.

## §5 — Phasing (single PR, batched)

1. Scaffold the tree + `docs/index.md` (hub + banner) + `git rm` old flat docs.
2. Guide core: getting-started, reactivity, bindings, forms-and-inputs, focus.
3. Guide styling: selectors, layout, transforms, transitions, tokens, fonts, svg.
4. Reference: gtmlview-api, html-elements, css-properties (each verified vs source).
5. Advanced: editor, extending, performance, limitations.
6. README repoint + `Gtml*` flip + banner; orphan-link sweep.
7. Final verification (suite + reviewer) + PR.

## §6 — Known risks (documented)

- **Doc/code naming gap:** docs say `Gtml*`, code still says `Gml*` until
  the separate rename PR. Mitigated by the banner. Accepted by the user.
- **Property/attribute drift:** the verify-before-document step is the
  guard; anything the source doesn't support is omitted.
- **Link rot during the move:** the orphan sweep + reviewer link-check
  cover it.

## §7 — Out of scope (deferred)

- The `Gml*`→`Gtml*` source rename (separate PR).
- A generated docs site.
- Localization / i18n of docs.
- API-doc autogeneration from GDScript comments.
