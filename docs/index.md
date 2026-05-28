# GTML Documentation

*Build reactive Godot 4 UI with HTML, CSS, and a Vue-style binding layer.*

> ⚠ **API rename in progress.** The addon is **GTML**; its classes are migrating from `Gml*` to `Gtml*`. These docs use the target `Gtml*` names. If your installed build still registers `GmlView`, use that name until the rename ships.

GTML builds Godot Control trees from HTML and CSS, so you write UI as markup instead of wiring nodes by hand. A reactive `state` layer drives the view — set a value, and only the affected nodes re-render. Use it for menus, HUDs, inventories, dialog trees, and anything else that needs keyboard or gamepad focus traversal.

## Guide

- [Getting started](guide/getting-started.md) — install, enable, your first view
- [Reactivity](guide/reactivity.md) — state, bindings, the reconcile loop
- [Bindings](guide/bindings.md) — `{{ }}`, `:class`, `v-for`, `v-model`, `@event`, expressions
- [Forms & inputs](guide/forms-and-inputs.md) — inputs, `v-model`, form submission
- [Focus & navigation](guide/focus.md) — keyboard / gamepad, `tabindex`, `focus-trap`
- [Selectors](guide/selectors.md) — selectors + pseudo-classes
- [Layout](guide/layout.md) — flexbox + sizing
- [Transforms](guide/transforms.md) — translate / scale / rotate
- [Transitions](guide/transitions.md) — animated state changes
- [Tokens](guide/tokens.md) — `var()`, `calc()`, custom properties
- [Fonts](guide/fonts.md) — typography
- [SVG](guide/svg.md) — vector graphics

## Reference

- [GtmlView API](reference/gtmlview-api.md) — state, signals, methods, exports
- [HTML elements](reference/html-elements.md) — supported tags + attributes
- [CSS properties](reference/css-properties.md) — the full property table

## Advanced

- [Editor pane](advanced/editor.md) — autocomplete, jumps, color picker
- [Extending GTML](advanced/extending.md) — add elements + properties
- [Performance](advanced/performance.md) — the benchmark harness
- [Limitations](advanced/limitations.md) — known limits + deferred
