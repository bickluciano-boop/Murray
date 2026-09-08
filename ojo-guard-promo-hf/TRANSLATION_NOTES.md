# Translation notes — Remotion → HyperFrames

Source: `ojo-guard-promo/src/Composition.tsx` + `scenes/*.tsx` (Remotion, 1080x1920 @30fps, 460 frames / 15.333s).
Output: `ojo-guard-promo-hf/index.html` (HyperFrames, single composition `ojo-guard-promo`).

## Lint result

`scripts/lint_source.py` on the Remotion source: 0 blockers, 0 warnings, 2 info
(`r2hf/static-file` on both `staticFile()` calls — routine, handled below).

## Mapping applied

- `<Sequence from durationInFrames>` (3 top-level scenes, no nesting) → 3 sibling
  `<section class="clip" data-start data-duration>` divs, offsets converted `frame/30`.
- `interpolate(frame, [a,b], [x,y])` (all linear, `extrapolate: clamp`) → `gsap.fromTo`/`gsap.to`
  at `a/30` with `duration=(b-a)/30`, `ease:"none"` — direct 1:1, no lossy step.
- `spring({damping:200, mass:0.6}, durationInFrames:30)` (Scene2 device scale-in, very
  overdamped/snappy) → approximated as `back.out(1.2)` over 0.6s per the timing.md
  damping→overshoot table. Closest tier match, not pixel-validated against this exact config.
- The looping heart-rate `strokeDashoffset` sawtooth (`frame % 90`) → bounded
  `repeat: 1` GSAP tween (2 total plays over the visible window) instead of Remotion's
  implicit per-frame modulo loop — HyperFrames disallows infinite/unbounded repeats
  (determinism rule), so the loop count is capped rather than continuing indefinitely.
- The status-tag pulse (`0.65 + 0.35*sin(frame/18)`, continuous) → `yoyo:true, repeat:3`
  sine tween — same visual cadence, finite instead of infinite for the same determinism reason.
- `@remotion/google-fonts/Poppins` + `/IBMPlexMono` → self-hosted `assets/fonts/*.woff2`
  + `assets/fonts.css`, latin subset only (covers all Spanish diacritics used in the copy).
- `staticFile("watch-hero.png")` / `staticFile("lifestyle-scene.jpg")` → `assets/*` relative
  paths, files copied alongside `index.html`.

## Environment-specific deviation (not a translation gap)

GSAP was vendored locally (`assets/gsap.min.js`, via `npm install gsap` rather than the
jsdelivr CDN) and Google Fonts were downloaded and self-hosted, because this sandbox's
network proxy blocks `cdn.jsdelivr.net` outright and the HyperFrames renderer's internal
Chromium doesn't trust the proxy's TLS certificate for `fonts.googleapis.com` /
`fonts.gstatic.com` (both reachable, both fail the browser's own cert check). Outside this
sandbox the CDN/`<link>` originals in `references/fonts.md`'s pattern would work fine —
this is a one-off local-asset substitution, not something the Remotion source required.

## Validation

`npm run check`: 0 lint errors/warnings, 0 runtime errors, 0 layout issues (9 samples),
0 motion errors, 15/15 contrast checks pass WCAG AA.

No formal SSIM diff run against the Remotion baseline (no `remotion-src`/`hf-src` fixture
pair set up for this ad-hoc port) — verified instead via 4-frame snapshot contact sheet
compared visually against the Remotion render's sample stills. Layout, color, and timing
read as matching; not pixel-diffed.
