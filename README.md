# hyprland-visibility-patch

See-through screen-capture exclusion for Hyprland: a window flagged with the
existing `noscreenshare` window rule stays fully visible on your monitor but is
**omitted from monitor/region captures**, with the desktop behind it composited
in — no black box.

Stock Hyprland blanks such windows to a solid black rectangle. This patch
re-renders the monitor's workspace into the capture buffer with flagged windows
skipped, so the windows behind draw normally.

## Layout

```
patches/
  see-through-context-api.patch  # new upstream: Render::CRenderContext (Hyprland2-era, ~0.57+)
  see-through-legacy-api.patch   # older upstream: m_renderData / IHyprRenderer member API
apply.sh                         # auto-detects the API generation and applies the right patch
```

`apply.sh` detects the generation by checking for `src/render/Context.hpp` plus
`CRenderContext` use in `ScreenshareFrame.cpp`. Re-running is safe (no-op when
already applied). `--reverse` reverts, `--check` dry-runs.

## Usage

```bash
# from a Hyprland source checkout:
~/hyprland-visibility-patch/apply.sh .

# dry run / revert:
~/hyprland-visibility-patch/apply.sh --check .
~/hyprland-visibility-patch/apply.sh --reverse .
```

Then build as usual (`make release`, or your Nix/packaged flow).

## Flagging a window

Reuse the existing rule — no new config syntax:

```ini
windowrule = noscreenshare, class:^(my-secret-app)$
```

(Lua config on new upstream: `hl.window_rule({ match = { class = "^my-secret-app$" }, no_screen_share = true })`.)

## Notes / limitations (as in the reference implementation)

- Triggers on `Desktop::windowState()->windows()` with the rule set; the
  see-through pass re-renders the active workspace via `renderWorkspace`.
  Wallpaper / background layer-shell surfaces may not be drawn in that pass, so
  an area with nothing behind the flagged window can render dark.
- Flagged layer-shell surfaces keep upstream behavior (black box) — the
  early-return skips those loops when a flagged window triggers the pass.
- `SHARE_REGION` re-renders the full active workspace, not clipped to the
  region; the stock path translates by `-m_captureBox.pos()`.
- No patch when zero flagged windows are present: the stock mirror-copy path
  runs unchanged.

## Reference

Ported from the working trees:

- new API: `Hyprland2` checkout (upstream ~0.57, `CRenderContext`)
- legacy API: `Hyprland` checkout (`m_renderData` on `IHyprRenderer`)
