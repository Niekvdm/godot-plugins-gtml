# Changelog

## 0.2.0

### Breaking changes

- Element builder modules renamed from `Gml*Elements` to `Gml*Builder`
  (`GmlButtonElements` → `GmlButtonBuilder`, etc.). Update any direct call
  sites; the public `GmlView` API is unchanged.
- `GmlRenderer` is now a thin dispatcher. Style/sizing/wrapping logic moved
  to `GmlDimensions`, `GmlPercentSizing`, `GmlBackgrounds`, `GmlWrap`, and
  `GmlTransitionSetup`. Direct callers of the removed private helpers must
  migrate to the new modules.
- `GmlStyles.apply_text_styles` no longer mutates `label.text` for
  `letter-spacing`, `word-spacing`, or `text-indent`. Values are stored as
  metadata; visual application is deferred to v0.3 (RichTextLabel migration).
- `GmlStyles.apply_word_spacing` removed (was the dead helper behind the
  text-mutation path above).
- `_parse_selector` removed from `GmlCssParser`; selector parsing now lives
  in `GmlSelector` and the parser delegates wholesale.

### Features

- **Real CSS selector engine** (`GmlSelector`):
  - Compound selectors: `div.foo#bar`
  - Descendant combinator: `.parent .child`
  - Child combinator: `.parent > .child`
  - Attribute selectors: `[disabled]` and `[type="text"]`
  - Universal selector: `*`
  - Specificity-based cascade `(ids, classes+attrs+pseudos, tags)` with
    source-order tie-breaking, replacing the previous tag<class<id rule.
- **HTML entity decoding**: named (`&amp;`, `&lt;`, `&nbsp;`, …) and numeric
  (`&#65;`, `&#x2603;`) in both text nodes and attribute values.
- **Quote- and paren-aware CSS values**: semicolons inside strings and
  commas inside `url(...)` no longer truncate the value.
- **CSS parser warnings carry line:col**: `parser.get_warnings()` returns
  `[{line, col, msg}]`.
- **Comma-separated CSS rules deep-clone properties** so nested dicts
  (`border`, `transition`, gradient stops) can never bleed between rules.
- **Font weight resolution prefers a real bold variant** from the user's
  fonts dict (`<Family>-Bold`, `<Family>Bold`, `<Family> Bold`,
  `<Family>-700`) before falling back to outline simulation.
- **Renderer split** into focused modules ≤ 250 LOC each (was 915 LOC).
- **GUT vendored** under `addons/gut/` with 54 unit + snapshot + smoke
  tests covering parser, selector engine, resolver, renderer pipeline,
  and style logic fixes.
- `GmlView._clear_children` now snapshots its child list before mutating.
- Plugin display name unified to "GTML".

### Deferred to v0.3

- Sibling combinators (`+`, `~`).
- Substring attribute matchers (`~=`, `^=`, `$=`, `*=`).
- Structural pseudos (`:not()`, `:nth-child()`, `:first-child`).
- Multi-pseudo states (`a:hover:focus` as combined state).
- Visual rendering of `letter-spacing`, `word-spacing`, `text-indent`
  (needs RichTextLabel migration).


## 0.1.1

Last single-file `GmlRenderer` release. See git history.
