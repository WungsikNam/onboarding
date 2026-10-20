"""Vector Pikachu art: single source for the in-app drawing and the HTML preview.

    python3 scripts/pikachu_art.py preview out.html   # every expression side by side
    python3 scripts/pikachu_art.py swift              # regenerates Shared/PikachuArtData.swift

Shapes live in a 100×100 box. Paths use absolute M/L/Q/C/Z only (the Swift side parses these).
"""
import sys, os

# ---------- geometry helpers ----------
def lerp(a, b, t): return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

def split_quad(p0, c, p1, t):
    """Splits a quadratic Bézier at t into (left, right) control triples."""
    a, b = lerp(p0, c, t), lerp(c, p1, t)
    m = lerp(a, b, t)
    return (p0, a, m), (m, b, p1)

def f(v): return f"{v:.2f}".rstrip("0").rstrip(".")
def pt(p): return f"{f(p[0])} {f(p[1])}"
def mirror_path(d):
    out, toks, i = [], d.split(), 0
    while i < len(toks):
        tk = toks[i]
        if tk.isalpha(): out.append(tk); i += 1; continue
        out += [f(100 - float(tk)), toks[i + 1]]; i += 2
    return " ".join(out)

# Layers: (name, shape, fill, stroke, width). shape = ("path", d) | ("ellipse", cx, cy, rx, ry)
def P(d, fill=None, stroke=None, w=0): return [("path", d), fill, stroke, w]
def E(cx, cy, rx, ry, fill=None, stroke=None, w=0): return [("ellipse", cx, cy, rx, ry), fill, stroke, w]
def mirrored(layer):
    shape, *rest = layer
    if shape[0] == "path": return [("path", mirror_path(shape[1]))] + rest
    return [("ellipse", 100 - shape[1], *shape[2:])] + rest

OUT = 2.2  # outline width

def ear(tip, ctrl_out, base_out, ctrl_in, base_in, black_t):
    """An ear: outer edge base_out→tip, inner edge tip→base_in, black above black_t."""
    full = f"M {pt(base_out)} Q {pt(ctrl_out)} {pt(tip)} Q {pt(ctrl_in)} {pt(base_in)} Z"
    (o0, oc, om), _ = split_quad(base_out, ctrl_out, tip, black_t)
    _, (im, ic, i1) = split_quad(tip, ctrl_in, base_in, 1 - black_t)
    dip = lerp(om, im, 0.5); dip = (dip[0] + 1.2, dip[1] + 2.2)  # slightly curved boundary
    yellow = f"M {pt(o0)} Q {pt(oc)} {pt(om)} Q {pt(dip)} {pt(im)} Q {pt(ic)} {pt(i1)} Z"
    return [P(full, "ink"), P(yellow, "yellow"), P(full, None, "ink", OUT)]

def both(layers): return layers + [mirrored(l) for l in layers]

C = {}
C["earsPikachu"] = both(ear((9, 3), (12, 22), (24, 40), (27, 12), (42, 29), 0.62))
C["earsPichu"] = both(ear((4, 8), (6, 30), (24, 42), (26, 4), (40, 28), 0.42))
C["tail"] = [
    P("M 61 86 L 72.5 76 L 66.5 71 L 82 59.5 L 76 54.5 L 88.5 35 L 98.5 44 L 89.5 57 L 95.5 61.5 L 80.5 75 L 85.5 79 L 67 93 Z", "yellow", "ink", OUT),
    P("M 61 86 L 69.5 78.6 L 75.3 84.2 L 67 93 Z", "brown", "ink", OUT),
]
C["feet"] = both([E(38.5, 95.5, 8, 3.8, "yellow", "ink", OUT)])
C["body"] = [E(50, 83, 22.5, 14.5, "yellow", "ink", OUT), E(50, 91, 11, 3.5, "shade")]
C["paws"] = both([E(39.5, 85.5, 4.4, 3.3, "yellow", "ink", 1.8)])
C["collar"] = [P("M 36 78.5 Q 50 84 64 78.5", None, "ink", 3)]
C["head"] = [E(50, 52, 31.5, 26.5, "yellow", "ink", OUT), E(38.5, 35.5, 8.5, 3.6, "shine")]
C["cheeksRed"] = both([E(24, 60.5, 6.6, 5.6, "cheek")])
C["cheeksPink"] = both([E(24, 60.5, 6.6, 5.6, "pinkCheek")])
C["nose"] = [E(50, 55.2, 1.5, 0.95, "ink")]
C["sickLines"] = [P("M 39 31 L 39 37 M 44 30 L 44 37.5 M 49 30 L 49 37.5", None, "gloom", 1.4)]
C["crown"] = [
    P("M 40 29 L 39.5 18.5 L 45 23.5 L 50 15.5 L 55 23.5 L 60.5 18.5 L 60 29 Z", "gold", "ink", 1.6),
    E(50, 25, 1.7, 1.7, "cheek"),
]

eye_open = [E(37, 50, 5, 5.7, "ink"), E(35.4, 47.7, 2.1, 2.2, "white"), E(38.6, 52.7, 0.9, 0.9, "white")]
C["eyesOpen"] = eye_open + [mirrored(l) for l in eye_open]
C["eyesHappy"] = both([P("M 32 52.5 Q 37 44.5 42 52.5", None, "ink", 2.6)])
C["eyesClosed"] = both([P("M 32 50 Q 37 55.5 42 50", None, "ink", 2.6)])
C["eyesTired"] = both([P("M 32 49.5 Q 37 58 42 49.5 Z", "ink"), P("M 31.5 49.5 L 42.5 49.5", None, "ink", 2.2),
                       E(36, 52.3, 1.2, 1.1, "white")])
sad_eye = [E(37, 50.5, 4.6, 5.2, "ink"), E(35.6, 48.6, 1.9, 2, "white"), P("M 31 43 L 41.5 40", None, "ink", 2)]
C["eyesSad"] = sad_eye + [mirrored(l) for l in sad_eye]
C["eyesDizzy"] = both([P("M 33 46 L 41 54 M 41 46 L 33 54", None, "ink", 2.4)])

C["mouthSmile"] = [P("M 44.3 58.3 Q 47.2 62 50 59 Q 52.8 62 55.7 58.3", None, "ink", 1.7)]
C["mouthOpen"] = [P("M 44.5 58.4 Q 50 60 55.5 58.4 Q 55 67 50 67 Q 45 67 44.5 58.4 Z", "mouth", "ink", 1.6),
                  E(50, 64.6, 3.2, 1.9, "tongue")]
C["mouthFrown"] = [P("M 45.5 62.5 Q 50 57.5 54.5 62.5", None, "ink", 1.7)]
C["mouthSmall"] = [P("M 47.8 60 Q 50 61.6 52.2 60", None, "ink", 1.6)]

COLORS = {  # name: (normal, sick/pale)
    "ink": ("#2B2B2B", "#3A3A3A"), "yellow": ("#FFD733", "#FBEAA3"), "shade": ("#F4C21F", "#EBDB98"),
    "shine": ("#FFFFFF66", "#FFFFFF66"), "cheek": ("#EC4A3F", "#F1A49C"), "pinkCheek": ("#F7A1A0", "#F7C3C2"),
    "brown": ("#8B5A2B", "#A88B6E"), "white": ("#FFFFFF", "#FFFFFF"), "mouth": ("#7A2430", "#8A4A52"),
    "tongue": ("#F26B7A", "#F2A0A8"), "gold": ("#FFC21A", "#FFC21A"), "gloom": ("#6E8FE6", "#6E8FE6"),
}

EYES = {"open": "eyesOpen", "happy": "eyesHappy", "closed": "eyesClosed", "tired": "eyesTired", "sad": "eyesSad", "dizzy": "eyesDizzy"}
MOUTHS = {"smile": "mouthSmile", "open": "mouthOpen", "frown": "mouthFrown", "small": "mouthSmall"}

def assemble(stage="pikachu", eyes="open", mouth="smile", crown=False, pale=False, head_only=False):
    """Mirrors PikachuDrawing.layers(for:) in Swift — keep the order in sync."""
    L = []
    if not head_only:
        if stage == "pikachu": L += C["tail"]
        L += C["feet"] + C["body"] + C["paws"]
        if stage == "pichu": L += C["collar"]
    L += C["earsPikachu" if stage == "pikachu" else "earsPichu"]
    L += C["head"]
    L += C["cheeksRed" if stage == "pikachu" else "cheeksPink"]
    L += C["nose"] + C[EYES[eyes]] + C[MOUTHS[mouth]]
    if pale: L += C["sickLines"]
    if crown: L += C["crown"]
    return L

# ---------- outputs ----------
def svg(look, size=180):
    vb = "4 0 92 80" if look.get("head_only") else "0 0 100 100"
    pale = look.get("pale", False)
    col = lambda n: COLORS[n][1 if pale else 0]
    parts = []
    for shape, fill, stroke, w in assemble(**look):
        a = f'fill="{col(fill)}"' if fill else 'fill="none"'
        if stroke: a += f' stroke="{col(stroke)}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"'
        if shape[0] == "path": parts.append(f'<path d="{shape[1]}" {a}/>')
        else: parts.append(f'<ellipse cx="{f(shape[1])}" cy="{shape[2]}" rx="{shape[3]}" ry="{shape[4]}" {a}/>')
    return f'<svg viewBox="{vb}" width="{size}" height="{size}">{"".join(parts)}</svg>'

def preview(path):
    looks = [("평소", dict()), ("신남", dict(eyes="happy", mouth="open")), ("심심", dict(eyes="sad", mouth="frown")),
             ("졸림", dict(eyes="tired", mouth="small")), ("쿨쿨", dict(eyes="closed", mouth="small")),
             ("아픔", dict(eyes="dizzy", mouth="frown", pale=True)), ("배고픔", dict(eyes="sad", mouth="open")),
             ("피츄", dict(stage="pichu")), ("피츄 신남", dict(stage="pichu", eyes="happy", mouth="open")),
             ("Lv.10 왕관", dict(eyes="happy", mouth="open", crown=True)), ("다이내믹 아일랜드", dict(head_only=True)),
             ("다이내믹 아일랜드 (수면)", dict(head_only=True, eyes="closed", mouth="small"))]
    cells = "".join(f'<div style="text-align:center">{svg(l, 150)}<p style="margin:2px">{name}</p></div>' for name, l in looks)
    open(path, "w").write(f"""<html><body style="margin:0;background:linear-gradient(#9ed9ff,#fff5c7);font:600 14px sans-serif;color:#2b2b2b">
<div style="display:grid;grid-template-columns:repeat(6,160px);gap:8px;padding:12px">{cells}</div></body></html>""")

def swift_layer(layer):
    shape, fill, stroke, w = layer
    s = f'.path("{shape[1]}")' if shape[0] == "path" else f".ellipse({f(shape[1])}, {f(shape[2])}, {f(shape[3])}, {f(shape[4])})"
    args = [s]
    if fill: args.append(f"fill: .{fill}")
    if stroke: args.append(f"stroke: .{stroke}, width: {f(w)}")
    return f"        ArtLayer({', '.join(args)}),"

def swift(path):
    lines = ["// Generated by scripts/pikachu_art.py — edit the script, not this file.", "",
             "import SwiftUI", "", "extension PikachuDrawing {"]
    for name, layers in C.items():
        lines.append(f"    static let {name}: [ArtLayer] = [")
        lines += [swift_layer(l) for l in layers]
        lines.append("    ]")
    lines.append("}")
    lines += ["", "extension ArtColor {", "    func color(pale: Bool) -> Color {", "        switch self {"]
    for name, (n, p) in COLORS.items():
        lines.append(f'        case .{name}: return Color(hex: pale ? "{p}" : "{n}")')
    lines += ["        }", "    }", "}", ""]
    lines.insert(4, "enum ArtColor { case " + ", ".join(COLORS) + " }\n")
    open(path, "w").write("\n".join(lines))

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    if sys.argv[1] == "preview": preview(sys.argv[2])
    else: swift(os.path.join(here, "..", "Shared", "PikachuArtData.swift"))
