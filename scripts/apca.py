#!/usr/bin/env python3
"""
APCA (Accessible Perceptual Contrast Algorithm) calculator.

WCAG 2.x contrast ratios are unreliable on dark backgrounds because the formula
treats luminance symmetrically, while human vision responds asymmetrically to
light-on-dark versus dark-on-light. Terminal themes live exactly where WCAG fails.

APCA returns a polarity-aware Lc value (roughly -108 to +108). Negative means light text on dark ground; positive means
dark text on light ground.

Implementation follows APCA-W3 0.1.9 (the W3C/WCAG3 candidate).
"""

# --- APCA 0.1.9 constants ---
S_TRC = 2.4
N_BG, N_TXT = 0.56, 0.57
R_BG, R_TXT = 0.65, 0.62
SCALE_BOW, SCALE_WOB = 1.14, 1.14
LO_CLIP, LO_CON_THRESH = 0.1, 0.027
DELTA_Y_MIN = 0.0005

CO_MAIN_TRC = [0.2126729, 0.7151522, 0.0721750]


def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def luminance(hexcolor):
    r, g, b = hex_to_rgb(hexcolor)
    lin = [(c / 255.0) ** S_TRC for c in (r, g, b)]
    return sum(c * w for c, w in zip(lin, CO_MAIN_TRC))


def apca(text_hex, bg_hex):
    """Return Lc contrast of text on bg."""
    y_txt = luminance(text_hex)
    y_bg = luminance(bg_hex)

    y_txt = 0.0 if y_txt <= 0.022 else y_txt
    y_bg = 0.0 if y_bg <= 0.022 else y_bg
    if y_txt <= 0.022:
        y_txt = y_txt + (0.022 - y_txt) ** 1.414
    if y_bg <= 0.022:
        y_bg = y_bg + (0.022 - y_bg) ** 1.414

    if abs(y_bg - y_txt) < DELTA_Y_MIN:
        return 0.0

    if y_bg > y_txt:  # light background, dark text (BoW)
        s = (y_bg ** N_BG - y_txt ** N_TXT) * SCALE_BOW
        out = 0.0 if s < LO_CLIP else s - LO_CON_THRESH
    else:             # dark background, light text (WoB)
        s = (y_bg ** R_BG - y_txt ** R_TXT) * SCALE_WOB
        out = 0.0 if s > -LO_CLIP else s + LO_CON_THRESH

    return round(out * 100, 1)


# --- Per-role gates ---
# Sourced from practitioner work on terminal themes plus APCA's own named tiers.
GATES = {
    'body':   90,   # fluent reading — terminal output, editor text
    'subtle': 75,   # secondary text you still read fully
    'accent': 60,   # highlights, active states, prompts
    'muted':  45,   # labels, comments, inactive
    'spot':   30,   # brief glances, single words, status digits
    'nontext': 15,  # borders, separators, icon shapes
}


def verdict(lc, role):
    need = GATES[role]
    ok = abs(lc) >= need
    return f"{'PASS' if ok else 'FAIL'}  Lc {lc:>6}  (need {need:>3} for {role})"


def report(name, bg, entries):
    print(f"\n{'=' * 68}")
    print(f"  {name}   background {bg}  (Y={luminance(bg):.4f})")
    print('=' * 68)
    worst = []
    for label, colour, role in entries:
        lc = apca(colour, bg)
        line = verdict(lc, role)
        print(f"  {label:<22} {colour}  {line}")
        if abs(lc) < GATES[role]:
            worst.append((label, lc, GATES[role]))
    if worst:
        print(f"\n  {len(worst)} slot(s) below gate:")
        for label, lc, need in worst:
            print(f"    - {label}: Lc {lc} (needs {need}, short by {need - abs(lc):.1f})")
    else:
        print("\n  All slots clear their gates.")


if __name__ == '__main__':
    print(__doc__)
    print("Named APCA tiers:")
    for role, gate in GATES.items():
        print(f"  {role:<8} Lc >= {gate}")
