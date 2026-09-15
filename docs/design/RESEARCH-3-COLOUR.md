# Design phase — research record, part 3: colour

**Status:** Phase 5 (colour) complete.

---

## Finding 5.1 — WCAG contrast ratios are wrong for terminals

The 4.5:1 ratio everyone quotes comes from WCAG 2.x, which computes contrast as a
symmetric luminance ratio. Human vision is **not** symmetric: we respond differently to
light-on-dark than dark-on-light.

The consequence is specific and severe: *a pair that passes 4.5:1 on white can be
functionally invisible on near-black.* Terminal themes live exactly where the formula
fails.

Worked example from the literature: `#797979` on `#110402` scores **4.5:1 under WCAG — a
pass** — while APCA returns **Lc 31**, which prohibits body text entirely. Our own
implementation reproduces this at **Lc -31.5**, confirming the calculator is correct.

## Finding 5.2 — APCA is the right instrument

APCA (Accessible Perceptual Contrast Algorithm) is the candidate contrast method for
WCAG 3. It returns a polarity-aware **Lc** value from roughly 0 to ±108. The sign tells
you the direction (negative = light text on dark ground); the magnitude tells you whether
it can actually be read at a given size and weight.

Validation of our implementation against published reference values:

| Pair | Expected | Ours |
|---|---|---|
| Black on white | ~+106 | **+106.0** |
| White on black | ~-107 | **-107.9** |
| `#797979` on `#110402` | Lc 31 | **-31.5** |

## Finding 5.3 — Per-role gates, not one threshold

WCAG gives one number and one threshold. That is the wrong shape for an interface, because
a muted label and a permission prompt do not need the same contrast.

The gate structure adopted:

| Role | Gate | Used for |
|---|---|---|
| `body` | Lc 90 | Terminal output, editor text — fluent reading |
| `subtle` | Lc 75 | Secondary text still read in full |
| `accent` | Lc 60 | Highlights, active states, prompts |
| `muted` | Lc 45 | Labels, comments, inactive items |
| `spot` | Lc 30 | Single words, status digits — brief glances |
| `nontext` | Lc 15 | Borders, separators, icon shapes |

## Finding 5.4 — Both hand-drawn mockup palettes failed completely

The palettes in concepts 1 and 3 were chosen by eye. Measured:

**Cold steel** — 6 of 6 slots below gate. Body text short by 13.5, accent short by 28.6,
hairline scoring **Lc 0.0** (literally imperceptible).

**Amber phosphor** — 6 of 6 slots below gate. Accent short by 25.7.

This is the single strongest argument for doing colour numerically. Both looked fine in a
drawing and neither is readable.

## Finding 5.5 — The split: saturated colour cannot be text on near-black

Solving a saturated red up to Lc 60 turns it into pink (`#f39894`). The colour loses its
identity in the process — it is no longer red.

The technique from the literature is to **split one colour across two slots**:

- **Pure, saturated version** for fills, bars, borders and one-word labels, where Lc 15–30
  is sufficient and the colour reads as a *field* rather than as text
- **Lifted sibling** on the same hue for anything actually read, clearing Lc 60

This preserves the colour's identity while keeping everything legible. Originally
documented for a Klein-blue terminal theme where pure IKB `#002FA7` scored Lc -12 on dark
ground — effectively invisible — and had to be split into a decorative slot and a lifted
text slot.

---

## The verified palette

Background `#08090a`.

| Slot | Hex | Measured Lc | Gate |
|---|---|---|---|
| body text | `#e1e4e6` | -90.1 | 90 |
| subtle text | `#c7ccd0` | -75.2 | 75 |
| muted label | `#8d969e` | -45.0 | 45 |
| spot label | `#6d7780` | -30.0 | 30 |
| hairline rule | `#4c5359` | -15.0 | 15 |

Semantic colours, split:

| Meaning | Fill (Lc) | Text (Lc) |
|---|---|---|
| **alert** | `#e02b28` (-31.4) | `#f09a98` (-60.3) |
| **data** | `#00b4d8` (-54.2) | `#00c0e6` (-60.3) |
| **warn** | `#d9861f` (-47.6) | `#e6a351` (-60.0) |

**Semantic rule, never broken:** cyan always means data or activity. Amber always means a
warning or a threshold approached. Red always means an alert or a failure. Grey carries all
structure. No colour is ever used decoratively.

---

## The tool

`scripts/apca.py` implements APCA-W3 0.1.9 and is validated against published reference
values. Use it before adopting any colour:

```python
from apca import apca
apca('#e1e4e6', '#08090a')   # -> -90.1
```

Running it directly prints the gate table.

---

## Decisions added

| # | Decision | Status |
|---|---|---|
| D10 | Every colour pair verified with APCA before use; no colour chosen by eye | Adopted |
| D11 | Per-role gates, not a single threshold | Adopted |
| D12 | Saturated colours split into pure (fill) and lifted (text) variants | Adopted |
| D13 | Colour is strictly semantic — cyan data, amber warn, red alert, grey structure | Adopted |

## Rejected

| Idea | Why |
|---|---|
| WCAG 4.5:1 as the standard | Demonstrably wrong on dark backgrounds; passes unreadable pairs |
| Both hand-drawn mockup palettes | 6 of 6 slots failed in each |
| Saturated accent colours as text | Cannot reach Lc 60 on near-black without becoming pastel |
