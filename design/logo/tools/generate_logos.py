import os
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

FONT = str(Path(__file__).resolve().parent / 'SpaceGrotesk.ttf')
WORD = 'Impetus'
BASE = str(Path(__file__).resolve().parent.parent)
WEIGHT = 600

font = instantiateVariableFont(TTFont(FONT), {'wght': WEIGHT})
gs = font.getGlyphSet()
cmap = font.getBestCmap()

def measure(word, scale=1.0):
    bp = BoundsPen(gs)
    x = 0.0
    for ch in word:
        g = gs[cmap[ord(ch)]]
        tp = TransformPen(bp, (scale, 0, 0, scale, x*scale, 0))
        g.draw(tp)
        x += g.width
    return bp.bounds, x * scale

bounds, adv = measure(WORD)
print('bounds (font units):', bounds, 'advance:', adv)

def word_path(word, scale, dx, dy):
    paths = []
    x = 0.0
    for ch in word:
        g = gs[cmap[ord(ch)]]
        pen = SVGPathPen(gs)
        tp = TransformPen(pen, (scale, 0, 0, -scale, dx + x*scale, dy))
        g.draw(tp)
        paths.append(pen.getCommands())
        x += g.width
    return ' '.join(paths)

# ---- Paletas de isotipo ----
ISO = {
 'dark':            dict(bg='#1e1e2e', halo_b='#2d2d3f', halo_t='#3a3a4e', sol='#f59e0b', term='#d97706', sbanda='#b45309', banda='#e5e5e5', cabeza='#e5e5e5', scabeza='#9a9aae'),
 'light':           dict(bg='#dbe8f5', halo_b='#c8dcef', halo_t='#e3eef9', sol='#f59e0b', term='#d97706', sbanda='#b45309', banda='#1e1e2e', cabeza='#1e1e2e', scabeza='#9a9aae'),
 'monochrome-dark': dict(bg='#1e1e2e', halo_b='#2d2d3f', halo_t='#3a3a4e', sol='#e5e5e5', term='#b0b0bc', sbanda='#6b6b7c', banda='#9a9aae', cabeza='#9a9aae', scabeza='#6b6b7c'),
 'monochrome-light':dict(bg='#f5f5f5', halo_b='#e8e8e8', halo_t='#f2f2f4', sol='#1e1e2e', term='#15151f', sbanda='#6b6b7c', banda='#9a9aae', cabeza='#9a9aae', scabeza='#6b6b7c'),
}

DEFS = '<defs><clipPath id="sun-clip"><circle cx="256" cy="256" r="120"/></clipPath><clipPath id="halo-clip"><circle cx="256" cy="256" r="138"/></clipPath></defs>'

def iso_body(p, with_bg=True):
    """SVG interior del isotipo (sin rect de fondo opcional)."""
    parts = []
    if with_bg:
        parts.append(f'<rect width="512" height="512" fill="{p["bg"]}"/>')
    parts.append(f'<circle cx="256" cy="256" r="138" fill="{p["halo_b"]}"/>')
    parts.append(f'<g clip-path="url(#halo-clip)"><rect x="0" y="118" width="512" height="138" fill="{p["halo_t"]}"/></g>')
    parts.append(f'<g clip-path="url(#sun-clip)">')
    parts.append(f'<circle cx="256" cy="256" r="120" fill="{p["sol"]}"/>')
    parts.append(f'<path d="M136 312 Q 176 304 216 312 T 296 312 T 376 312 L 376 376 L 136 376 Z" fill="{p["term"]}"/>')
    parts.append(f'<path d="M116 244 Q256 312 388 244" fill="none" stroke="{p["sbanda"]}" stroke-width="32"/>')
    parts.append(f'</g>')
    parts.append(f'<path d="M116 238 Q256 302 388 238" fill="none" stroke="{p["banda"]}" stroke-width="32"/>')
    parts.append(f'<path d="M369 216 L396 228 L387 256 Z" fill="{p["scabeza"]}" stroke="{p["scabeza"]}" stroke-width="8" stroke-linejoin="round" transform="translate(2,3)"/>')
    parts.append(f'<path d="M369 216 L396 228 L387 256 Z" fill="{p["cabeza"]}" stroke="{p["cabeza"]}" stroke-width="8" stroke-linejoin="round"/>')
    return '\n'.join(parts)

def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)
    print('wrote', path)

# ---- 1) Variantes de isotipo (solo simbolo) ----
# dark = nuevo original (con fondo); carpetas color/ y monochrome/, prefijos eliminados
for theme in ('color', 'monochrome'):
    for variant, with_bg in (('dark', True), ('dark-transparent', False),
                             ('light', True), ('light-transparent', False)):
        iso_key = ('dark' if theme == 'color' else 'monochrome-dark') if variant.startswith('dark') else ('light' if theme == 'color' else 'monochrome-light')
        write(f'{BASE}/isotipo/{theme}/{variant}.svg',
              f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">\n{DEFS}\n{iso_body(ISO[iso_key], with_bg)}\n</svg>\n')

# banner 1500x500 con dark (color) escalado
scale_b = 0.88
bw, bh = 512*scale_b, 512*scale_b
bx, by = (1500-bw)/2, (500-bh)/2
banner = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1500 500">\n{DEFS}\n<rect width="1500" height="500" fill="#1e1e2e"/>\n<g transform="translate({bx:.1f},{by:.1f}) scale({scale_b})">\n{iso_body(ISO["dark"], False)}\n</g>\n</svg>\n'
write(f'{BASE}/isotipo/banner.svg', banner)

# ---- 2) Wordmark ----
# cap height objetivo: ~74px (vertical) y ~150px (horizontal)
cap = bounds[3]  # ymax en font units (~cap height)
def word_svg(scale, center_x, center_y):
    # centrar verticalmente usando el centro visual (mitad del cap) con descendente
    mid = (bounds[1]+bounds[3])/2
    # centrar horizontalmente por el bbox VISUAL del path (no por el advance,
    # que incluye side-bearing y descentra el texto real)
    dx = center_x - (bounds[0]+bounds[2])*scale/2
    dy = center_y + mid*scale
    return word_path(WORD, scale, dx, dy), dx, dy, adv*scale

# ---- 2b) Banner con wordmark 1500x500 (isotipo color-dark + 'Impetus') ----
bw, bh = 1500, 500
M = 87                 # margen lateral
s_iso = 240.0 / 276.0  # isotipo recortado 276 -> alto 240
iso_top = (bh - 276*s_iso) / 2
tx = M - 116*s_iso
ty = iso_top - 118*s_iso
gap = 100              # gap isotipo->texto
sh = 180.0
s = sh / cap
w = (bounds[2]-bounds[0]) * s
path_left = M + 280*s_iso + gap
cx = path_left + w/2
cy = bh / 2
path_d, dx, dy, _ = word_svg(s, cx, cy)
bclip = '<clipPath id="banner-clip"><rect x="116" y="118" width="280" height="276"/></clipPath>'
head = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {bw} {bh}">']
head.append(DEFS.replace('</defs>', bclip + '</defs>'))
head.append(f'<rect width="{bw}" height="{bh}" fill="#1e1e2e"/>')
head.append(f'<g transform="translate({tx:.4f},{ty:.4f}) scale({s_iso:.6f})"><g clip-path="url(#banner-clip)">')
head.append(iso_body(ISO['dark'], False))
head.append('</g></g>')
head.append(f'<path d="{path_d}" fill="#e5e5e5"/>')
head.append('</svg>')
write(f'{BASE}/logotipo/banner.svg', '\n'.join(head))

# ---- 3) Logotipos ----
# Isotipo incrustado con clipPath "iso-clip" para recortar su aire
# (contenido real del isotipo: X 116..396, Y 118..394 sobre cuadrado 512).
# Bloque recortado: vertical 512x276 (clip Y 118..394), horizontal 280x276 (clip X 116..396, Y 118..394).
LOGO_COLORS = {'dark':'#e5e5e5', 'light':'#1e1e2e'}
ISO_KEY = {'dark':'dark', 'light':'light'}

def logotipo(kind, mode, with_bg):
    txt = LOGO_COLORS[mode]
    iso = ISO[ISO_KEY[mode]]
    bg = iso['bg']
    if kind == 'vertical':
        # contenido visible del isotipo: Y 118..394 -> alto 276
        M = 52            # margen sup/inf del contenido en el canvas
        gap = 34          # gap halo->texto
        sh = 74.0
        s = sh / cap
        w = (bounds[2]-bounds[0]) * s
        canvas_w = 512
        cx = canvas_w / 2
        path_top = M + 276 + gap
        cy = path_top + 450*s
        path_d, dx, dy, _ = word_svg(s, cx, cy)
        canvas_h = int(path_top + 900*s + M)
        clip = '<clipPath id="iso-clip"><rect x="0" y="118" width="512" height="276"/></clipPath>'
        head = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {canvas_w} {canvas_h}">']
        head.append(DEFS.replace('</defs>', clip + '</defs>'))
        if with_bg:
            head.append(f'<rect width="{canvas_w}" height="{canvas_h}" fill="{bg}"/>')
        head.append(f'<g transform="translate(0,{M-118})"><g clip-path="url(#iso-clip)">')
        head.append(iso_body(iso, False))
        head.append('</g></g>')
        head.append(f'<path d="{path_d}" fill="{txt}"/>')
        head.append('</svg>')
    else:  # horizontal
        # contenido visible del isotipo: X 116..396, Y 118..394 -> bloque 280x276
        M = 56            # margen izq/der del contenido en el canvas
        gap = 80          # gap cola->texto
        sh = 150.0
        s = sh / cap
        w = (bounds[2]-bounds[0]) * s
        canvas_h = 512
        iso_top = (canvas_h - 276) / 2
        path_left = M + 280 + gap
        cx = path_left + w/2
        cy = canvas_h / 2
        path_d, dx, dy, _ = word_svg(s, cx, cy)
        canvas_w = int(path_left + w + M)
        clip = '<clipPath id="iso-clip"><rect x="116" y="118" width="280" height="276"/></clipPath>'
        head = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {canvas_w} {canvas_h}">']
        head.append(DEFS.replace('</defs>', clip + '</defs>'))
        if with_bg:
            head.append(f'<rect width="{canvas_w}" height="{canvas_h}" fill="{bg}"/>')
        head.append(f'<g transform="translate({M-116},{iso_top-118})"><g clip-path="url(#iso-clip)">')
        head.append(iso_body(iso, False))
        head.append('</g></g>')
        head.append(f'<path d="{path_d}" fill="{txt}"/>')
        head.append('</svg>')
    return '\n'.join(head)

for mode in ('dark','light'):
    for kind in ('vertical','horizontal'):
        for bg_flag, suffix in ((True,''),(False,'-transparent')):
            fn = f'{BASE}/logotipo/{kind}/{mode}{suffix}.svg'
            write(fn, logotipo(kind, mode, bg_flag))

print('DONE')
