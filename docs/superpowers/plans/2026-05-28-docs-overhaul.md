# GTML — Documentation overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **This is a DOCS plan, not a code plan.** There is no TDD loop — docs are prose. Each task gives the file path, the **source files to verify against**, a **section outline**, the **must-include verified facts**, and cross-links. The writer produces the prose following the outline + conventions; "verification" is a source-reality check + a link check, not an assert test. Do NOT pre-write full doc prose anywhere but the doc file itself.

**Goal:** Regenerate all GTML docs from scratch into a sectioned tree (`docs/{guide,reference,advanced}/` + `docs/index.md`), add a Reactivity guide + a GtmlView API reference, and switch all class references to the target `Gtml*` prefix with a rename banner.

**Architecture:** Markdown only. Three sections — `guide/` (narrative), `reference/` (lookup), `advanced/`. A `docs/index.md` hub links everything. Every documented class/signal/property/attribute is verified against source before writing. The `Gml*`→`Gtml*` source rename is a SEPARATE later PR; docs use `Gtml*` ahead of code, disclosed by a banner.

**Tech Stack:** Markdown, GitHub-flavored. Source of truth = `addons/gtml/src/`.

**Reference spec:** `docs/superpowers/specs/2026-05-28-docs-overhaul-design.md`

---

## Pre-flight

- Branch: `docs/readme-reactive-rewrite` (folding into PR #19 per user's call — already has the README rewrite + spec commit)
- Working directory: `/data/personal/projects/godot/godot-plugins-gtml`
- Test suite (to confirm nothing breaks at the end): `cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` → expect **403/403** (docs aren't loaded by code; this just confirms no fixture pointed at a removed doc).
- NO Co-Authored-By line in commits.
- Subagent shell commands prefix with `cd /data/personal/projects/godot/godot-plugins-gtml &&`.

## Global conventions (apply to EVERY doc — repeat to each writer)

1. **Class names use the `Gtml*` prefix** — `GtmlView`, `GtmlState`, `GtmlRenderer`, `GtmlBindingExpr`, `GtmlBindingApplier`, `GtmlBindingParser`, `GtmlBindingRegistry`, `GtmlVForReconciler`, `GtmlFocusManager`, `GtmlClassRestyler`, `GtmlStyleResolver`, `GtmlCssParser`, `GtmlHtmlParser`, `GtmlNode`. The editor node is documented as **`GtmlView`**. (Source still defines `Gml*` — that's fine, rename is a later PR.)
2. **Voice:** second person, imperative, terse. Open with a 1-2 line "what + why", then a minimal runnable example, then detail. No marketing.
3. **Verify before you write:** read the cited source file(s); only document what actually exists. Drop anything the source doesn't support.
4. **Examples:** self-contained, valid GDScript/HTML/CSS, realistic game-UI snippets.
5. **Cross-links:** relative paths from the file's own location (a guide → `../reference/css-properties.md`; index → `guide/bindings.md`). End each guide with a "See also".
6. **Header:** `# Title` then a one-line italic summary.

---

## Task 1: Scaffold the tree + index + remove old flat docs

**Files:**
- Create dirs: `docs/guide/`, `docs/reference/`, `docs/advanced/`
- Create: `docs/index.md`
- Remove: the 17 flat `docs/*.md` (NOT `docs/superpowers/`)

- [ ] **Step 1.1: Create the section directories**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && mkdir -p docs/guide docs/reference docs/advanced
```

- [ ] **Step 1.2: Remove the old flat docs**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git rm docs/bindings.md docs/css-properties.md docs/css-selectors.md docs/css-tokens.md docs/editor.md docs/extending-gtml.md docs/focus.md docs/fonts-and-typography.md docs/forms-and-inputs.md docs/getting-started.md docs/html-elements.md docs/layout-and-flexbox.md docs/limitations.md docs/perf.md docs/svg-support.md docs/transforms.md docs/transitions.md
```

- [ ] **Step 1.3: Write `docs/index.md`**

Content outline:
- `# GTML Documentation` + one-line summary.
- The rename banner (verbatim):
  > ⚠ **API rename in progress.** The addon is **GTML**; its classes are migrating from `Gml*` to `Gtml*`. These docs use the target `Gtml*` names. If your installed build still registers `GmlView`, use that name until the rename ships.
- 2-3 sentence pitch (reactive UI in Godot via HTML/CSS).
- Grouped link list:
  - **Guide:** getting-started, reactivity, bindings, forms-and-inputs, focus, selectors, layout, transforms, transitions, tokens, fonts, svg (relative: `guide/<name>.md`)
  - **Reference:** gtmlview-api, html-elements, css-properties (`reference/<name>.md`)
  - **Advanced:** editor, extending, performance, limitations (`advanced/<name>.md`)
- Each link gets a 4-8 word descriptor.

- [ ] **Step 1.4: Verify the tree + commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && ls docs docs/guide docs/reference docs/advanced && git add docs/index.md && git commit -m "docs: scaffold sectioned tree + index hub; remove flat docs

Creates docs/{guide,reference,advanced}/ + docs/index.md (hub with the
Gml*→Gtml* rename banner + grouped nav). Removes the 17 legacy flat
docs/*.md (regenerated under the new tree in following commits).
docs/superpowers/ untouched."
```

---

## Task 2: Guide — core (getting-started, reactivity, bindings, forms, focus)

**Files (create):**
- `docs/guide/getting-started.md`
- `docs/guide/reactivity.md`
- `docs/guide/bindings.md`
- `docs/guide/forms-and-inputs.md`
- `docs/guide/focus.md`

**Verify against:** `addons/gtml/src/GmlView.gd` (signals + exports + public API), `addons/gtml/src/binding/` (GmlBindingExpr grammar, GmlBindingApplier directives), `docs/superpowers/specs/2026-05-27-*-design.md` + `2026-05-28-*-design.md` (bindings/focus substance is authoritative there), `addons/gtml/src/html_renderer/elements/GmlInputBuilder.gd` (input types / v-model targets).

- [ ] **Step 2.1: Write `getting-started.md`**

Outline: what GTML is (2 lines) → install (copy `addons/gtml/`, enable in Project Settings → Plugins) → add a **GtmlView** node, set **Html Path** + **Css Path** → a static menu example (HTML + CSS + a `button_clicked` connect) → "next: Reactivity". Include the rename banner. See also: reactivity, bindings.

- [ ] **Step 2.2: Write `reactivity.md`** (NEW)

Outline: the model — `view.state` is the source of truth; bindings in markup read it; `state.set(key, value)` re-renders only what changed (no manual node edits). The reconcile loop (state.set → fires bindings → reconciler patches the tree). The immutable-update pattern: replace arrays/dicts with new instances so changes propagate (`state.set("items", items + [new]`), not in-place mutation). When to use `state` vs bare `@click`/`button_clicked`. Verified API: `state.set`, `state.get`, `state.set_state`, `state.has`, `state.keys`, `state_changed` signal (all on `GtmlState` / exposed via `view.state`). Minimal runnable HUD example. See also: bindings, gtmlview-api.

- [ ] **Step 2.3: Write `bindings.md`**

Outline: the directive catalog, one focused example each:
`{{ expr }}`, `:attr` (`:disabled`/`:value`/`:src`/`:href`), `:class` (object/array/bare + the live re-resolution note), `v-if`/`v-show`, `v-for="item in items"` + `:key` + indexed form, `v-model`, `@event` / `@event(args)` → `item_clicked`. Then the **expression grammar** (paths, `!`, `+ - * / %`, `> < >= <= == !=`, `&& ||`, ternary, `[]` indexing, string literals; NO function calls / method calls). Then **documented limitations** (descendant-from-ancestor `:class` not re-resolved; hover collision; `:class` font-family not re-resolved). Verify each directive against `GmlBindingApplier`/`GmlBindingParser`/`GmlRenderer`. See also: reactivity, gtmlview-api, forms-and-inputs.

- [ ] **Step 2.4: Write `forms-and-inputs.md`**

Outline: input types and the Control each maps to (verify in `GmlInputBuilder.gd`: text→LineEdit, checkbox/radio→CheckBox, range→HSlider, textarea→TextEdit, select→OptionButton). `v-model` two-way per type. `form_submitted` + `get_form_data()`. `:checked` pseudo. `@keydown` → `key_pressed`. `input_changed` / `selection_changed` signals. See also: bindings, gtmlview-api.

- [ ] **Step 2.5: Write `focus.md`**

Outline: reuse the substance of the v0.8.3 focus spec — focusable set (natives + `@event` + anchors + `tabindex>=0`), Tab order + HTML `tabindex` rules, `autofocus`, `focus-trap`, v-for behavior, `view.focus_first()`, limitations (directional uses Godot geometry; no roving tabindex; root no-wrap). Verify against `GmlFocusManager.gd` + `GmlView.focus_first`. See also: bindings, gtmlview-api.

- [ ] **Step 2.6: Verify + commit**

Confirm no `Gml` (un-prefixed-to-Gtml) class refs slipped in:
```bash
cd /data/personal/projects/godot/godot-plugins-gtml && grep -rn "GmlView\|GmlState\|GmlRenderer\|GmlBinding\|GmlFocus\|GmlClass\|GmlStyle\|GmlCss\|GmlHtml\|GmlNode\|GmlVFor" docs/guide/ || echo "clean: no un-renamed Gml* refs"
```
Expected: "clean". Then:
```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add docs/guide/getting-started.md docs/guide/reactivity.md docs/guide/bindings.md docs/guide/forms-and-inputs.md docs/guide/focus.md && git commit -m "docs(guide): core guides — getting-started, reactivity, bindings, forms, focus

Reactive-first core guide set. reactivity.md (new) explains the
state→bindings→DOM model + reconcile loop + immutable-update pattern.
bindings.md is the directive catalog + expression grammar + documented
limitations. getting-started leads new users in; forms-and-inputs and
focus reformat the verified input + focus behavior. All class refs use
the Gtml* prefix; rename banner in getting-started."
```

---

## Task 3: Guide — styling (selectors, layout, transforms, transitions, tokens, fonts, svg)

**Files (create):** `docs/guide/selectors.md`, `layout.md`, `transforms.md`, `transitions.md`, `tokens.md`, `fonts.md`, `svg.md`

**Verify against:** `addons/gtml/src/css/GmlSelector.gd` (selectors/pseudo), `GmlCssParser.gd` (accepted properties — the categorized lists at ~lines 55-91), `GmlStyles.gd`/`GmlDimensions.gd`/`GmlWrap.gd`/`GmlBackgrounds.gd` (what actually applies), `GmlTransitionSetup.gd`/`GmlTransitionManager.gd` (transitions), `SvgDrawControl.gd` + `GmlMediaBuilder.gd` (SVG/img).

- [ ] **Step 3.1: Write `selectors.md`** — element / class / id selectors, combinators (descendant, child, comma), attribute matchers, pseudo-classes (`:hover`, `:active`, `:focus`, `:checked`, `:nth-child` if supported — verify). Specificity ordering. See also: css-properties, styling examples.

- [ ] **Step 3.2: Write `layout.md`** — `display: flex`, `flex-direction`, `justify-content`, `align-items`, `align-self`, `flex-wrap`, `flex-grow`/`shrink`/`basis`, `gap`/`row-gap`/`column-gap`, width/height/min/max, percentage sizing. Example: a flex dashboard row. See also: css-properties, transforms.

- [ ] **Step 3.3: Write `transforms.md`** — `transform: translate/scale/rotate`, transform origin behavior, interaction with transitions. Verify against the transform application path. See also: transitions, layout.

- [ ] **Step 3.4: Write `transitions.md`** — `transition` shorthand + longhands (`transition-property/duration/timing-function/delay`), which properties animate (color, bg, border, transform), pseudo-state-driven transitions (`:hover` etc.), the transition manager's behavior. See also: transforms, selectors.

- [ ] **Step 3.5: Write `tokens.md`** — custom properties (`--name`), `var(--name)`, `calc()` (supported ops — verify in `GmlCssEval.gd`), scoping. See also: css-properties.

- [ ] **Step 3.6: Write `fonts.md`** — `font-size`, `font-weight`/`font-style` (verify), the `fonts` export Dictionary mapping family→Font, `font-family` usage, default font color. See also: css-properties, gtmlview-api.

- [ ] **Step 3.7: Write `svg.md`** — `<img>` with SVG, how `SvgDrawControl` renders, supported subset + limitations. Verify against `SvgDrawControl.gd`. See also: html-elements.

- [ ] **Step 3.8: Verify + commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && grep -rn "GmlView\|GmlState\|GmlRenderer\|GmlBinding\|GmlFocus\|GmlClass\|GmlStyle\|GmlCss\|GmlHtml\|GmlNode\|GmlVFor" docs/guide/selectors.md docs/guide/layout.md docs/guide/transforms.md docs/guide/transitions.md docs/guide/tokens.md docs/guide/fonts.md docs/guide/svg.md || echo "clean"
cd /data/personal/projects/godot/godot-plugins-gtml && git add docs/guide/selectors.md docs/guide/layout.md docs/guide/transforms.md docs/guide/transitions.md docs/guide/tokens.md docs/guide/fonts.md docs/guide/svg.md && git commit -m "docs(guide): styling guides — selectors, layout, transforms, transitions, tokens, fonts, svg

Narrative topic guides per the hybrid CSS structure (the exhaustive
property table lives in reference/css-properties). Each verified
against the CSS parser/resolver/transition/SVG source so only
real, resolving features are documented."
```

---

## Task 4: Reference (gtmlview-api, html-elements, css-properties)

**Files (create):** `docs/reference/gtmlview-api.md`, `docs/reference/html-elements.md`, `docs/reference/css-properties.md`

- [ ] **Step 4.1: Write `gtmlview-api.md`** (NEW)

**Verify against `addons/gtml/src/GmlView.gd`.** Document (verified members):
- **State** (via `view.state`, a `GtmlState`): `set(key, value)`, `get(key)`, `set_state(dict)`, `has(key)`, `keys()`, `state_changed(key, new, old)` signal.
- **Signals:** `button_clicked(method_name)`, `link_clicked(href)`, `input_changed(input_id, value)`, `selection_changed(select_id, value)`, `form_submitted(form_data)`, `key_pressed(handler, event)`, `item_clicked(handler, args)`.
- **Methods:** `get_element_by_id(id) -> Control`, `get_wrapper_by_id(id) -> Control`, `get_radio_group(name) -> ButtonGroup`, `get_form_data() -> Dictionary`, `get_tag_defaults() -> Dictionary`, `focus_first() -> bool`.
- **Exports:** `html_path`, `css_path`, `auto_reload_in_editor`, `show_nodes_in_editor`, tag-default group (`h1_font_size`…`p_font_size`, `default_font_color`, `default_gap`/`margin`/`padding`), `fonts: Dictionary`.
- **Lifecycle:** rebuild on ready, hot reload in editor, `state` survives rebuild.
Format: tables (signal → params → when fired; method → signature → returns). See also: reactivity, bindings, forms-and-inputs.

- [ ] **Step 4.2: Write `html-elements.md`**

**Verify against the dispatch table in `addons/gtml/src/html_renderer/GmlRenderer.gd`** (`_dispatch`) + the element builders. Table: tag → Control produced → notes. Cover div/section/header/footer/nav/main/article/aside/form, p, span, h1-h6, label, strong/b, em/i, button, input, textarea, select/option, img, br, hr, progress, ul/ol/li, a. Supported attributes (id, class, src, href, type, placeholder, value, name, `@event`, binding directives, `tabindex`/`autofocus`/`focus-trap`, `aria-node`, `title`). See also: css-selectors guide, gtmlview-api.

- [ ] **Step 4.3: Write `css-properties.md`**

**Verify against `addons/gtml/src/css/GmlCssParser.gd` (the accepted-property lists ~lines 55-91) AND the appliers** (`GmlStyles`, `GmlDimensions`, `GmlWrap`, `GmlBackgrounds`). Only list properties that PARSE and APPLY. One exhaustive table: property → accepted values → notes/caveats. Group by category (layout, box/spacing, sizing, color, border, effects, transition, transform, gradient, font, text). Flag the documented limitation that dynamic `:class` re-resolves only the visual subset. See also: selectors, layout, tokens guides.

- [ ] **Step 4.4: Verify + commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && grep -rn "\bGmlView\b\|\bGmlState\b\|\bGmlRenderer\b\|GmlBinding\|GmlFocus\|GmlStyle\|GmlCss\|GmlHtml\|GmlNode" docs/reference/ || echo "clean"
cd /data/personal/projects/godot/godot-plugins-gtml && git add docs/reference/gtmlview-api.md docs/reference/html-elements.md docs/reference/css-properties.md && git commit -m "docs(reference): GtmlView API, HTML elements, CSS properties

gtmlview-api.md (new) documents the node's state API, all seven
signals, public methods, and exports — every member verified against
GmlView.gd. html-elements enumerates the renderer dispatch table;
css-properties is the single exhaustive table cross-checked against
the parser's accepted-property lists + the appliers (only properties
that actually resolve are listed)."
```

---

## Task 5: Advanced (editor, extending, performance, limitations)

**Files (create):** `docs/advanced/editor.md`, `docs/advanced/extending.md`, `docs/advanced/performance.md`, `docs/advanced/limitations.md`

**Verify against:** `addons/gtml/src/editor/` (5 engines), the element/property builder seams, `tests/perf/test_perf_bench.gd`, the v0.8 specs' deferred lists.

- [ ] **Step 5.1: Write `editor.md`** — the editor pane: autocomplete (HTML/CSS), jumps (Ctrl+Click/F12, Alt+Left history), color picker on hex/rgb/rgba, multi-cursor (Ctrl+D/L, Ctrl+Alt+Up/Down), find/replace (Ctrl+H, regex). Verify against the editor engines + panel. See also: getting-started.

- [ ] **Step 5.2: Write `extending.md`** — how to add an element builder (the `_dispatch` seam + builder pattern) and a CSS property (parser allowlist + applier). Verify the seams against current code. See also: html-elements, css-properties.

- [ ] **Step 5.3: Write `performance.md`** — port the current `perf.md` substance: how to run the bench (`-gtest=res://tests/perf/test_perf_bench.gd`), the five groups, sample numbers, caveats (machine-dependent, CPU-only, reconcile churn, no tracking). See also: bindings (v-for), limitations.

- [ ] **Step 5.4: Write `limitations.md`** — current known limitations + deferred list: no computed props/watchers, no global store, descendant-from-ancestor `:class`, directional focus uses geometry, no roving tabindex, expression grammar excludes function/method calls, dynamic `:class` visual-only, font-family not re-resolved on `:class`. Note shipped items (`v-for :key` IS done). Verify each against source/specs. See also: bindings, focus.

- [ ] **Step 5.5: Verify + commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && grep -rn "\bGmlView\b\|\bGmlState\b\|GmlBinding\|GmlFocus\|GmlVFor\|GmlRenderer" docs/advanced/ || echo "clean"
cd /data/personal/projects/godot/godot-plugins-gtml && git add docs/advanced/editor.md docs/advanced/extending.md docs/advanced/performance.md docs/advanced/limitations.md && git commit -m "docs(advanced): editor, extending, performance, limitations

Editor pane reference, the element/property extension seams, the perf
bench how-to (ported from perf.md), and an honest limitations +
deferred list (v-for :key now shipped; computed props / watchers /
global store / function calls still deferred). Verified against the
editor engines, builder seams, and bench file."
```

---

## Task 6: README repoint + Gtml* flip + orphan-link sweep

**Files:**
- Modify: `README.md`
- Sweep: any file linking old `docs/<name>.md`

- [ ] **Step 6.1: Repoint README documentation links + flip class names**

In `README.md`:
- Change the "Documentation" section to link `docs/index.md` first, then key pages: `docs/guide/getting-started.md`, `docs/guide/reactivity.md`, `docs/guide/bindings.md`, `docs/guide/focus.md`, `docs/reference/gtmlview-api.md`.
- Flip all class references `GmlView`→`GtmlView` (and any other `Gml*`) in the README body + code blocks.
- Add the rename banner near the top (same wording as the index).

- [ ] **Step 6.2: Orphan-link sweep**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && grep -rn "docs/bindings\.md\|docs/css-\|docs/editor\.md\|docs/extending-gtml\|docs/focus\.md\|docs/fonts-\|docs/forms-\|docs/getting-started\|docs/html-elements\|docs/layout-and\|docs/limitations\|docs/perf\.md\|docs/svg-support\|docs/transforms\|docs/transitions" --include="*.md" --include="*.gd" . | grep -v "docs/superpowers"
```

For each hit (other than this plan/spec under `docs/superpowers/`), repoint to the new path (e.g. `docs/getting-started.md` → `docs/guide/getting-started.md`, `docs/css-properties.md` → `docs/reference/css-properties.md`). Common culprits: `addons/gtml/README.md` (if present), cross-references the rewrite may have missed, the addon's plugin description.

- [ ] **Step 6.3: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add -A && git commit -m "docs: repoint README to the sectioned tree + Gtml* flip + link sweep

README 'Documentation' now points at docs/index.md + the key guide/
reference pages. README class refs flipped Gml*→Gtml* with the rename
banner near the top. Swept the repo for stale docs/<flat>.md links and
repointed them into guide/reference/advanced/."
```

---

## Task 7: Final verification + PR

- [ ] **Step 7.1: Internal-link integrity check**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && python3 - <<'PY'
import re, pathlib
root = pathlib.Path("docs")
bad = []
for md in root.rglob("*.md"):
    if "superpowers" in md.parts:
        continue
    text = md.read_text()
    for m in re.finditer(r"\]\((?!https?://|#)([^)]+\.md)(#[^)]*)?\)", text):
        target = (md.parent / m.group(1)).resolve()
        if not target.exists():
            bad.append(f"{md}: -> {m.group(1)}")
print("BROKEN LINKS:" if bad else "all internal links resolve")
for b in bad:
    print(" ", b)
PY
```

Expected: "all internal links resolve". Fix any broken link before proceeding.

- [ ] **Step 7.2: Run the test suite (confirm no code referenced a removed doc)**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 403/403.

- [ ] **Step 7.3: Final reviewer pass (dispatched by the controller, not in this task)**

The controller dispatches a reviewer subagent to confirm: every documented class/signal/property/attribute exists in source; the `Gtml*` convention is consistent (no stray `Gml*` outside the banner's explanatory text); the banner is present on index + getting-started; all links resolve; no old flat `docs/*.md` link remains.

- [ ] **Step 7.4: Update PR #19 (fold the overhaul in)**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git push 2>&1 | tail -2
cd /data/personal/projects/godot/godot-plugins-gtml && gh pr edit 19 --title "docs: reactive README + full documentation overhaul" --body "$(cat <<'EOF'
## Summary

Modernizes the entire docs surface for the v0.8 reactive era and reorganizes it into a sectioned tree.

### README (reactive-first)
- Leads with state + bindings; old signal flow demoted to "the simple case".
- Showcase gallery; links to the new docs hub.

### Docs overhaul
- New sectioned tree: `docs/{guide,reference,advanced}/` behind `docs/index.md`.
- **New:** `guide/reactivity.md` (the mental model) + `reference/gtmlview-api.md` (state API, signals, methods, exports).
- Hybrid CSS: one exhaustive `reference/css-properties.md` + narrative topic guides.
- All class references use the target `Gtml*` prefix (the `Gml*`→`Gtml*` source rename is a separate follow-up PR) with a "rename in progress" banner.
- Every documented feature verified against source; SVG + editor confirmed real + retained.

### Cleanup
- Removed the 5 legacy flat example demos + repointed their tests to the showcase corpus (earlier in this PR).
- Removed the 17 flat docs; regenerated under the new tree.

## Stats
- Tests: 403/403 (unchanged)
- Docs: 20 files (3 new), sectioned

## Test plan
- [ ] Suite green (403/403)
- [ ] All internal doc links resolve (link-check script in the plan)
- [ ] Spot-check the docs hub + a guide + a reference render on GitHub
EOF
)" 2>&1 | tail -3
```

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-05-28-docs-overhaul-design.md`):
- File tree → Task 1 (scaffold) + Tasks 2-5 (content) ✓
- Per-doc scope → Tasks 2-5 outlines ✓
- Conventions (Gtml*, banner, verify, voice, links) → global conventions block + per-task verify greps ✓
- Index, links, README → Task 1 (index), Task 6 (README + sweep), Task 7 (link check) ✓
- Verification → Task 6 sweep + Task 7 link-check + suite + reviewer ✓
- Phasing → 7 tasks matching spec §5 ✓

**Placeholder scan:** none — each doc task has an explicit outline + verified facts + source to check. (This is a docs plan: outlines + source pointers are the deliverable, not pre-written prose — declared in the header.)

**Naming consistency:** the `Gtml*` class list in the global conventions matches what each task references. Section paths (`guide/`/`reference/`/`advanced/`) consistent across index, content tasks, README repoint, and the link-check.

**Risk:** the doc/code naming gap (`Gtml*` docs vs `Gml*` code) is intentional + banner-disclosed (spec §6). The verify-before-document greps + the final reviewer guard against documenting nonexistent members.
