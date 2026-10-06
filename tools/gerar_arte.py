"""Gera toda a arte do Craque de Botao desenhada por codigo.

    python3 tools/gerar_arte.py

Estadio visto de cima (gramado, linhas, gols, placas, arquibancadas),
torcida (camada animada pelo shader torcida.shader), redes, bandeiras das 10
selecoes, botoes (2 uniformes por selecao), goleiros "caixinha", bola,
logo, trofeu, cartoes, icone e splash.

As medidas do campo sao as mesmas de scripts/campo.gd (em 1280x720).
A arte sai em 1920x1080 (e 1280x720 para telas menores).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(RAIZ, "imagens")
FONTES = os.path.join(RAIZ, "fontes")
os.makedirs(IMG, exist_ok=True)
RNG = np.random.default_rng(11)

E = 1.5                      # 1280x720 -> 1920x1080
W, H = 1920, 1080

# --------------------------------------------------- medidas (1280x720)
MURO = (96, 88, 1184, 702)            # parede fisica (placas)
CAMPO = (140, 110, 1140, 680)         # linhas do campo
CX, CY = 640, 395
GOL_MEIA = 78                          # meia boca do gol
GOL_FUNDO = 38                         # profundidade da rede
AREA_P, AREA_MEIA = 172, 192           # grande area
AREA_G, AREA_G_MEIA = 64, 104          # pequena area
MARCA_PEN = 114
RAIO_CIRCULO = 87


def s(v):
    return v * E


def fonte(nome, tam):
    return ImageFont.truetype(os.path.join(FONTES, nome + ".ttf"), int(tam))


def salvar(im, nome):
    im.save(os.path.join(IMG, nome), optimize=True)
    print(nome, im.size)


def dither(a):
    return np.clip(np.round(a * 255 + RNG.uniform(-0.5, 0.5, a.shape)), 0, 255).astype(np.uint8)


def cor(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def desfocar(im, raio):
    """Desfoque com alfa pre-multiplicado (sem escurecer as bordas)."""
    from scipy.ndimage import gaussian_filter
    arr = np.asarray(im, np.float32) / 255.0
    a = arr[..., 3]
    out = np.zeros_like(arr)
    a_b = gaussian_filter(a, raio)
    for k in range(3):
        pre = gaussian_filter(arr[..., k] * a, raio)
        out[..., k] = np.where(a_b > 1e-5, pre / np.maximum(a_b, 1e-5), 0)
    out[..., 3] = a_b
    return np.clip(out, 0, 1)


def blur_camada(desenhar, raio, tam=(W, H)):
    im = Image.new("RGBA", tam, (0, 0, 0, 0))
    desenhar(ImageDraw.Draw(im))
    if raio > 0:
        return desfocar(im, raio)
    return np.asarray(im, np.float32) / 255.0


# (a imagem do estadio e 0..255; as camadas vem em 0..1)
def somar(base, camada, forca=1.0):
    return base + camada[..., :3] * 255.0 * camada[..., 3:4] * forca


def por_cima(base, camada):
    a = camada[..., 3:4]
    return base * (1 - a) + camada[..., :3] * 255.0 * a


# ======================================================= TIMES
# Um arquivo so para o jogo e para a arte: dados/times.json
import json
TIMES = json.load(open(os.path.join(RAIZ, "dados", "times.json"), encoding="utf-8"))["times"]
NACOES = [t for t in TIMES if t["emblema"] == "bandeira"]


def brasao_esp(d, cx, cy, alt):
    """Brasao da Espanha simplificado: coroa, escudo em quartos (castelo,
    leao, barras, correntes) e as duas colunas com a faixa vermelha."""
    ouro, verm, bran, roxo, azul = cor("#E8B830"), cor("#C60B1E"), (250, 250, 250), cor("#7B2D8B"), cor("#1F4FA3")
    esc_l, esc_h = alt * 0.52, alt * 0.62
    x0, y0 = cx - esc_l / 2, cy - esc_h / 2 + alt * 0.08
    lw = max(1, int(alt * 0.025))
    # colunas (Hercules) dos dois lados
    for lado in (-1, 1):
        px = cx + lado * esc_l * 0.92
        cl = alt * 0.11
        d.rectangle([px - cl / 2, y0 + esc_h * 0.05, px + cl / 2, y0 + esc_h * 1.02], fill=bran, outline=(90, 90, 90), width=lw)
        d.rectangle([px - cl * 0.8, y0 - alt * 0.04, px + cl * 0.8, y0 + esc_h * 0.06], fill=ouro)
        d.rectangle([px - cl * 0.8, y0 + esc_h * 0.98, px + cl * 0.8, y0 + esc_h * 1.1], fill=ouro)
        d.ellipse([px - cl * 0.55, y0 - alt * 0.14, px + cl * 0.55, y0 - alt * 0.03], fill=ouro)
        d.rectangle([px - cl * 0.95, y0 + esc_h * 0.42, px + cl * 0.95, y0 + esc_h * 0.56], fill=verm)
    # coroa
    cy0 = y0 - alt * 0.03
    d.rectangle([cx - esc_l * 0.42, cy0 - alt * 0.06, cx + esc_l * 0.42, cy0], fill=ouro)
    d.ellipse([cx - esc_l * 0.36, cy0 - alt * 0.24, cx + esc_l * 0.36, cy0 - alt * 0.02], fill=ouro)
    d.rectangle([cx - esc_l * 0.38, cy0 - alt * 0.05, cx + esc_l * 0.38, cy0 - alt * 0.025], fill=verm)
    d.line([(cx, cy0 - alt * 0.32), (cx, cy0 - alt * 0.2)], fill=ouro, width=lw * 2)
    d.line([(cx - alt * 0.04, cy0 - alt * 0.28), (cx + alt * 0.04, cy0 - alt * 0.28)], fill=ouro, width=lw * 2)
    # escudo (quartos) com a ponta redonda embaixo
    mx, my = cx, y0 + esc_h * 0.45
    d.rectangle([x0, y0, mx, my], fill=verm)
    d.rectangle([mx, y0, x0 + esc_l, my], fill=bran)
    d.pieslice([x0, y0 + esc_h * 0.1, x0 + esc_l, y0 + esc_h], 0, 180, fill=verm)
    d.rectangle([x0, my, x0 + esc_l, y0 + esc_h * 0.55], fill=verm)
    for k in range(4):
        bx = mx - esc_l / 2 + esc_l * 0.06 + k * esc_l * 0.11
        d.rectangle([bx, my, bx + esc_l * 0.055, y0 + esc_h * 0.92], fill=ouro)
    # castelo
    q = esc_l * 0.5
    d.rectangle([x0 + q * 0.22, y0 + esc_h * 0.16, x0 + q * 0.78, y0 + esc_h * 0.38], fill=ouro)
    for k in range(3):
        tx = x0 + q * (0.22 + k * 0.22)
        d.rectangle([tx, y0 + esc_h * 0.09, tx + q * 0.12, y0 + esc_h * 0.17], fill=ouro)
    # leao
    lx, ly = mx + q * 0.5, y0 + esc_h * 0.24
    d.ellipse([lx - q * 0.22, ly - q * 0.18, lx + q * 0.22, ly + q * 0.22], fill=roxo)
    d.ellipse([lx - q * 0.1, ly - q * 0.32, lx + q * 0.14, ly - q * 0.08], fill=roxo)
    # romã e escudinho azul no meio
    d.ellipse([cx - esc_l * 0.07, y0 + esc_h * 0.88, cx + esc_l * 0.07, y0 + esc_h * 0.99], fill=(70, 170, 70))
    d.ellipse([cx - esc_l * 0.12, my - esc_h * 0.1, cx + esc_l * 0.12, my + esc_h * 0.1], fill=azul, outline=verm, width=lw)
    # contorno
    d.line([(x0, y0), (x0 + esc_l, y0)], fill=(90, 60, 10), width=lw)
    d.line([(x0, y0), (x0, y0 + esc_h * 0.55)], fill=(90, 60, 10), width=lw)
    d.line([(x0 + esc_l, y0), (x0 + esc_l, y0 + esc_h * 0.55)], fill=(90, 60, 10), width=lw)
    d.arc([x0, y0 + esc_h * 0.1, x0 + esc_l, y0 + esc_h], 0, 180, fill=(90, 60, 10), width=lw)


# ======================================================= BANDEIRAS
def bandeira(sigla, w=300, h=200, escudo_x=0.36):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    if sigla == "BRA":
        d.rectangle([0, 0, w, h], fill=cor("#009C3B"))
        m = w * 0.085
        d.polygon([(m, h / 2), (w / 2, m * 0.8), (w - m, h / 2), (w / 2, h - m * 0.8)], fill=cor("#FFDF00"))
        r = h * 0.26
        d.ellipse([w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r], fill=cor("#002776"))
        # faixa branca curva
        d.arc([w / 2 - r * 2.1, h / 2 - r * 0.55, w / 2 + r * 2.1, h / 2 + r * 3.6], 225, 315, fill=(255, 255, 255), width=int(r * 0.2))
        mas = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mas).ellipse([w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r], fill=255)
        fundo = Image.new("RGB", (w, h))
        dd = ImageDraw.Draw(fundo)
        dd.rectangle([0, 0, w, h], fill=cor("#009C3B"))
        dd.polygon([(m, h / 2), (w / 2, m * 0.8), (w - m, h / 2), (w / 2, h - m * 0.8)], fill=cor("#FFDF00"))
        im = Image.composite(im, fundo, mas)
        d = ImageDraw.Draw(im)
        for ex, ey in [(-0.3, 0.35), (0.1, 0.5), (0.35, 0.3), (-0.05, 0.62), (0.25, 0.6)]:
            x, y = w / 2 + ex * r, h / 2 + ey * r
            d.ellipse([x - 2.5, y - 2.5, x + 2.5, y + 2.5], fill=(255, 255, 255))
    elif sigla == "ARG":
        d.rectangle([0, 0, w, h], fill=cor("#74ACDF"))
        d.rectangle([0, h / 3, w, 2 * h / 3], fill=(255, 255, 255))
        r = h * 0.1
        cx, cy = w / 2, h / 2
        for k in range(16):
            a = k * math.pi / 8
            d.line([(cx, cy), (cx + math.cos(a) * r * 1.7, cy + math.sin(a) * r * 1.7)], fill=cor("#F6B40E"), width=3)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=cor("#F6B40E"), outline=cor("#85340A"))
    elif sigla == "ITA":
        for i, c in enumerate(["#009246", "#FFFFFF", "#CE2B37"]):
            d.rectangle([i * w / 3, 0, (i + 1) * w / 3, h], fill=cor(c))
    elif sigla == "FRA":
        for i, c in enumerate(["#0055A4", "#FFFFFF", "#EF4135"]):
            d.rectangle([i * w / 3, 0, (i + 1) * w / 3, h], fill=cor(c))
    elif sigla == "ESP":
        d.rectangle([0, 0, w, h], fill=cor("#AA151B"))
        d.rectangle([0, h / 4, w, 3 * h / 4], fill=cor("#F1BF00"))
        # brasao (simplificado): na bandeira fica do lado do mastro; no escudo
        # do tazo vem para o meio (escudo_x) para aparecer inteiro
        brasao_esp(d, w * escudo_x, h * 0.5, h * 0.42)
    elif sigla == "ALE":
        for i, c in enumerate(["#000000", "#DD0000", "#FFCE00"]):
            d.rectangle([0, i * h / 3, w, (i + 1) * h / 3], fill=cor(c))
    elif sigla in ("NOR", "SUE"):
        fundo, cruz, dentro = ("#BA0C2F", "#FFFFFF", "#00205B") if sigla == "NOR" else ("#006AA7", "#FECC00", None)
        d.rectangle([0, 0, w, h], fill=cor(fundo))
        cx = w * (8 / 22 if sigla == "NOR" else 6 / 16)
        lg = h * (4 / 16 if sigla == "NOR" else 4 / 10) / 2
        d.rectangle([cx - lg, 0, cx + lg, h], fill=cor(cruz))
        d.rectangle([0, h / 2 - lg, w, h / 2 + lg], fill=cor(cruz))
        if dentro:
            li = lg / 2
            d.rectangle([cx - li, 0, cx + li, h], fill=cor(dentro))
            d.rectangle([0, h / 2 - li, w, h / 2 + li], fill=cor(dentro))
    elif sigla == "ING":
        d.rectangle([0, 0, w, h], fill=(255, 255, 255))
        lg = h * 0.2 / 2
        d.rectangle([w / 2 - lg, 0, w / 2 + lg, h], fill=cor("#CE1124"))
        d.rectangle([0, h / 2 - lg, w, h / 2 + lg], fill=cor("#CE1124"))
    elif sigla == "AUS":
        azul = cor("#012169")
        d.rectangle([0, 0, w, h], fill=azul)
        cw, ch = w / 2, h / 2
        # Union Jack simplificada no canto
        d.line([(0, 0), (cw, ch)], fill=(255, 255, 255), width=int(ch * 0.2))
        d.line([(cw, 0), (0, ch)], fill=(255, 255, 255), width=int(ch * 0.2))
        d.line([(0, 0), (cw, ch)], fill=cor("#C8102E"), width=int(ch * 0.07))
        d.line([(cw, 0), (0, ch)], fill=cor("#C8102E"), width=int(ch * 0.07))
        d.rectangle([cw / 2 - ch * 0.17, 0, cw / 2 + ch * 0.17, ch], fill=(255, 255, 255))
        d.rectangle([0, ch / 2 - ch * 0.17, cw, ch / 2 + ch * 0.17], fill=(255, 255, 255))
        d.rectangle([cw / 2 - ch * 0.1, 0, cw / 2 + ch * 0.1, ch], fill=cor("#C8102E"))
        d.rectangle([0, ch / 2 - ch * 0.1, cw, ch / 2 + ch * 0.1], fill=cor("#C8102E"))

        def estrela(x, y, r, pontas=7):
            pts = []
            for k in range(pontas * 2):
                a = -math.pi / 2 + k * math.pi / pontas
                rr = r if k % 2 == 0 else r * 0.45
                pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
            d.polygon(pts, fill=(255, 255, 255))
        estrela(cw / 2, h * 0.75, h * 0.13)
        for (ex, ey, er) in [(0.75, 0.2, 0.06), (0.62, 0.45, 0.06), (0.88, 0.4, 0.06), (0.75, 0.82, 0.07), (0.81, 0.56, 0.035)]:
            estrela(w * ex, h * ey, h * er)
    return im


def bandeira_final(sigla):
    """Bandeira com cantos arredondados, brilho e sombra leve (RGBA)."""
    w, h = 300, 200
    b = bandeira(sigla, w * 2, h * 2).resize((w, h), Image.LANCZOS).convert("RGBA")
    # ondulacao de tecido (luz)
    xx = np.arange(w)[None, :]
    luz = 1.0 + 0.10 * np.sin(xx / w * math.pi * 2.2 + 0.6)
    arr = np.asarray(b, np.float32)
    arr[..., :3] = np.clip(arr[..., :3] * luz[..., None], 0, 255)
    b = Image.fromarray(arr.astype(np.uint8), "RGBA")
    mas = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mas).rounded_rectangle([0, 0, w - 1, h - 1], radius=18, fill=255)
    b.putalpha(mas)
    borda = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(borda).rounded_rectangle([1, 1, w - 2, h - 2], radius=18, outline=(255, 255, 255, 150), width=3)
    return Image.alpha_composite(b, borda)


for t_ in NACOES:
    salvar(bandeira_final(t_["sigla"]), "bandeira_%s.png" % t_["sigla"].lower())


def logo_do_time(t, tam):
    """Logo (arquivo em imagens/) cabendo num quadrado tam x tam."""
    lg = Image.open(os.path.join(IMG, t["emblema"])).convert("RGBA")
    lg.thumbnail((tam, tam), Image.LANCZOS)
    q = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    q.alpha_composite(lg, ((tam - lg.width) // 2, (tam - lg.height) // 2))
    return q


# ======================================================= EMBLEMAS
# Escudo de cada time. Selecoes: escudo com a bandeira (os brasoes oficiais
# das federacoes sao marcas registradas; o simbolo aqui e a bandeira).
# Clubes (Lazer & Sport): o proprio logo.
def forma_escudo(g):
    """Escudo classico: topo reto com um bico, lados retos e a base em ponta
    (curvas convexas feitas com Bezier)."""
    m = Image.new("L", (g, g), 0)
    d = ImageDraw.Draw(m)
    w_ = g * 0.84
    xe, xd = (g - w_) / 2, (g + w_) / 2
    topo, meio, base = g * 0.08, g * 0.5, g * 0.96
    pts = [(xe, topo + g * 0.04), (g / 2, topo - g * 0.03), (xd, topo + g * 0.04), (xd, meio)]
    ctrl_y = meio + (base - meio) * 0.72
    for k in range(1, 21):
        u = k / 20
        x = (1 - u) ** 2 * xd + 2 * (1 - u) * u * xd + u * u * (g / 2)
        y = (1 - u) ** 2 * meio + 2 * (1 - u) * u * ctrl_y + u * u * base
        pts.append((x, y))
    for k in range(19, -1, -1):
        u = k / 20
        x = (1 - u) ** 2 * xe + 2 * (1 - u) * u * xe + u * u * (g / 2)
        y = (1 - u) ** 2 * meio + 2 * (1 - u) * u * ctrl_y + u * u * base
        pts.append((x, y))
    d.polygon(pts, fill=255)
    return m


def emblema(t, tam=256):
    g = tam * 4
    im = Image.new("RGBA", (g, g), (0, 0, 0, 0))
    if t["emblema"] == "bandeira":
        esc = forma_escudo(g)
        ouro = Image.new("RGBA", (g, g), (232, 184, 48, 255))
        im.paste(ouro, (0, 0), esc)
        # borda dourada: o "dentro" é o escudo encolhido (distância à borda,
        # rápido em qualquer tamanho)
        from scipy.ndimage import distance_transform_edt
        dist_borda = distance_transform_edt(np.asarray(esc) > 127)
        dentro = Image.fromarray((np.clip(dist_borda - g * 0.035, 0, 1) * 255).astype(np.uint8))
        # bandeira maior que o escudo (3:2), recortada no meio
        # (o simbolo de cada bandeira tem que aparecer inteiro no escudo: o
        # brasao da Espanha vem para o meio; a Australia mostra a Union Jack)
        b = bandeira(t["sigla"], int(g * 1.5), int(g * 1.0), escudo_x=0.5).convert("RGBA")
        x_corte = 0 if t["sigla"] == "AUS" else (b.width - g) // 2
        b = b.crop((x_corte, 0, x_corte + g, g))
        im.paste(b, (0, 0), dentro)
        # brilho e sombra do escudo
        br = Image.new("RGBA", (g, g), (0, 0, 0, 0))
        ImageDraw.Draw(br).ellipse([-g * 0.3, -g * 0.55, g * 0.75, g * 0.42], fill=(255, 255, 255, 70))
        br.putalpha(Image.fromarray(np.minimum(np.asarray(br.getchannel("A")), np.asarray(dentro))))
        im = Image.alpha_composite(im, br)
    else:
        d = ImageDraw.Draw(im)
        d.ellipse([g * 0.03, g * 0.03, g * 0.97, g * 0.97], fill=cor(t["u1"][1]) + (255,))
        d.ellipse([g * 0.1, g * 0.1, g * 0.9, g * 0.9], fill=(255, 255, 255, 255))
        lg = logo_do_time(t, int(g * 0.74))
        im.alpha_composite(lg, (int(g * 0.13), int(g * 0.13)))
    return im.resize((tam, tam), Image.LANCZOS)


EMBLEMAS = {}
for t_ in TIMES:
    EMBLEMAS[t_["sigla"]] = emblema(t_)
    salvar(EMBLEMAS[t_["sigla"]], "emblema_%s.png" % t_["sigla"].lower())


def bandeira_clube(t):
    """Bandeira de clube: pano nas cores do time com o logo no meio."""
    w, h = 300, 200
    im = Image.new("RGBA", (w, h), cor(t["u1"][0]) + (255,))
    d = ImageDraw.Draw(im)
    d.polygon([(0, h * 0.72), (w, h * 0.28), (w, h * 0.42), (0, h * 0.86)], fill=cor(t["u1"][1]) + (255,))
    lg = logo_do_time(t, 150)
    im.alpha_composite(lg, ((w - 150) // 2, (h - 150) // 2))
    mas = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mas).rounded_rectangle([0, 0, w - 1, h - 1], radius=18, fill=255)
    im.putalpha(mas)
    borda = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(borda).rounded_rectangle([1, 1, w - 2, h - 2], radius=18, outline=(0, 0, 0, 90), width=3)
    return Image.alpha_composite(im, borda)


for t_ in TIMES:
    if t_["emblema"] != "bandeira":
        salvar(bandeira_clube(t_), "bandeira_%s.png" % t_["sigla"].lower())


# ======================================================= BOTOES
def botao(camisa, borda, listras=False, tam=512, emb=None, so=None):
    g = tam * 4
    im = Image.new("RGBA", (g, g), (0, 0, 0, 0))
    yy, xx = np.mgrid[0:g, 0:g].astype(np.float32)
    c = (g - 1) / 2
    r = g * 0.47
    dist = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / r
    ang_luz = ((xx - c) * -0.6 + (yy - c) * -0.8) / r
    cam = np.array(cor(camisa), np.float32)
    bor = np.array(cor(borda), np.float32)
    rgb = np.zeros((g, g, 3), np.float32)
    # face (camisa) com leve abaulado
    face = cam[None, None, :] * (0.88 + 0.16 * ang_luz[..., None])
    if listras:
        faixa = (np.floor((xx - c) / (g * 0.14) + 0.5) % 2 == 0)
        face = np.where(faixa[..., None], face, np.array([255, 255, 255], np.float32) * (0.9 + 0.1 * ang_luz[..., None]))
    rgb[:] = face
    # aro de fora (borda) com relevo
    # (build 8: aro mais fino e escudo bem maior; a face na cor do uniforme
    # continua em volta do escudo e dá a proporção do tazo)
    aro = (dist > 0.85) & (dist <= 1.0)
    relevo = 0.75 + 0.45 * ang_luz * np.sign(dist - 0.925 + 1e-6) * -1
    rgb = np.where(aro[..., None], bor[None, None, :] * np.clip(relevo, 0.45, 1.35)[..., None], rgb)
    # sulco fino entre aro e face
    sulco = (dist > 0.82) & (dist <= 0.85)
    rgb = np.where(sulco[..., None], rgb * 0.55, rgb)
    # contorno escuro fino por fora (o tazo bem recortado em qualquer tela,
    # sem desenhar linha por cima: na TV box a linha saía serrilhada)
    contorno = np.clip((dist - 0.95) / 0.03, 0, 1)
    rgb = rgb * (1.0 - 0.55 * contorno[..., None])
    alfa = np.clip((1.0 - dist) * r / 2.0, 0, 1)
    # camadas separadas (time do pendrive: a cor vem do jogo)
    if so == "face":
        alfa = alfa * np.clip((0.85 - dist) * r / 2.0, 0, 1)
    elif so == "aro":
        alfa = alfa * np.clip((dist - 0.82) * r / 2.0, 0, 1)
    arr = np.zeros((g, g, 4), np.float32)
    arr[..., :3] = np.clip(rgb, 0, 255)
    arr[..., 3] = alfa * 255
    im = Image.fromarray(arr.astype(np.uint8), "RGBA")
    if emb is not None:
        e_ = emb.resize((int(r * 1.4), int(r * 1.4)), Image.LANCZOS)
        sombra_e = Image.new("RGBA", im.size, (0, 0, 0, 0))
        sombra_e.paste((0, 0, 0, 110), (int(c - e_.width / 2 + g * 0.012), int(c - e_.height / 2 + g * 0.02)), e_.getchannel("A"))
        im = Image.alpha_composite(im, sombra_e.filter(ImageFilter.GaussianBlur(g * 0.01)))
        im.alpha_composite(e_, (int(c - e_.width / 2), int(c - e_.height / 2)))
    if so in ("face", "aro"):
        return im.resize((tam, tam), Image.LANCZOS)
    # brilho de verniz
    br = Image.new("RGBA", (g, g), (0, 0, 0, 0))
    ImageDraw.Draw(br).ellipse([c - r * 0.78, c - r * 0.86, c + r * 0.2, c - r * 0.1], fill=(255, 255, 255, 70))
    br = br.filter(ImageFilter.GaussianBlur(g * 0.03))
    mas = Image.new("L", (g, g), 0)
    ImageDraw.Draw(mas).ellipse([c - r, c - r, c + r, c + r], fill=255)
    br.putalpha(Image.fromarray((np.asarray(br.getchannel("A"), np.float32) * np.asarray(mas, np.float32) / 255).astype(np.uint8)))
    if so == "brilho":
        return br.resize((tam, tam), Image.LANCZOS)
    im = Image.alpha_composite(im, br)
    return im.resize((tam, tam), Image.LANCZOS)


def goleiro(camisa, borda, w=128, h=320):
    """Goleiro 'caixinha' visto de cima: capsula em pe."""
    g = 4
    im = Image.new("RGBA", (w * g, h * g), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    raio = w * g * 0.48
    d.rounded_rectangle([w * g * 0.02, w * g * 0.02, w * g * 0.98, h * g - w * g * 0.02], radius=raio, fill=cor(borda) + (255,))
    m = w * g * 0.16
    d.rounded_rectangle([m, m, w * g - m, h * g - m], radius=raio - m, fill=cor(camisa) + (255,))
    # luvas (pontas claras)
    for yy in (m * 1.2, h * g - m * 1.2 - w * g * 0.36):
        d.ellipse([w * g * 0.3, yy, w * g * 0.7, yy + w * g * 0.36], fill=(245, 245, 245, 255))
    # brilho
    br = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(br).rounded_rectangle([m * 1.3, m * 1.6, w * g * 0.45, h * g - m * 1.6], radius=raio * 0.4, fill=(255, 255, 255, 55))
    im = Image.alpha_composite(im, br.filter(ImageFilter.GaussianBlur(6)))
    return im.resize((w, h), Image.LANCZOS)


# escudo em alta para o tazo (no tazo de 512 ele ocupa ~340 px: sem borrão)
EMBLEMAS_HD = {t_["sigla"]: emblema(t_, 768) for t_ in TIMES}
for t_ in TIMES:
    sg = t_["sigla"].lower()
    for i, u in enumerate((t_["u1"], t_["u2"])):
        salvar(botao(u[0], u[1], listras=(t_.get("listras", False) and i == 0), emb=EMBLEMAS_HD[t_["sigla"]]), "botao_%s_%d.png" % (sg, i + 1))
    # goleiros: uniforme de cada time em tools/gerar_goleiros.py
# camadas brancas para o time do pendrive (o jogo pinta com as cores do logo)
salvar(botao("#FFFFFF", "#FFFFFF", so="face"), "botao_face.png")
salvar(botao("#FFFFFF", "#FFFFFF", so="aro"), "botao_aro.png")
salvar(botao("#FFFFFF", "#FFFFFF", so="brilho"), "botao_brilho.png")


# ======================================================= BOLA
def bola(tam=128):
    g = tam * 4
    yy, xx = np.mgrid[0:g, 0:g].astype(np.float32)
    c = (g - 1) / 2
    r = g * 0.46
    dx, dy = (xx - c) / r, (yy - c) / r
    dist = np.sqrt(dx ** 2 + dy ** 2)
    nz = np.sqrt(np.clip(1 - dist ** 2, 0, 1))
    luz = np.clip(dx * -0.45 + dy * -0.55 + nz * 0.8, 0, 1)
    base = np.ones((g, g, 3), np.float32) * 250
    # gomos pretos (pentagonos)
    im = Image.new("L", (g, g), 0)
    d = ImageDraw.Draw(im)

    def penta(x, y, rr, rot):
        d.polygon([(x + math.cos(rot + k * 2 * math.pi / 5) * rr, y + math.sin(rot + k * 2 * math.pi / 5) * rr) for k in range(5)], fill=255)
    penta(c, c, r * 0.3, -math.pi / 2)
    for k in range(5):
        a = -math.pi / 2 + math.pi / 5 + k * 2 * math.pi / 5
        penta(c + math.cos(a) * r * 0.82, c + math.sin(a) * r * 0.82, r * 0.26, a)
    gomo = np.asarray(im.filter(ImageFilter.GaussianBlur(2)), np.float32) / 255
    base = base * (1 - gomo[..., None] * 0.9)
    rgb = base * (0.45 + 0.65 * luz[..., None])
    arr = np.zeros((g, g, 4), np.float32)
    arr[..., :3] = np.clip(rgb, 0, 255)
    arr[..., 3] = np.clip((1 - dist) * r / 2, 0, 1) * 255
    out = Image.fromarray(arr.astype(np.uint8), "RGBA")
    return out.resize((tam, tam), Image.LANCZOS)


salvar(bola(), "bola.png")


def radial(tam, expoente=2.0, cor_=(255, 255, 255)):
    y, x = np.mgrid[0:tam, 0:tam]
    c = (tam - 1) / 2
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    a = np.clip(1 - d, 0, 1) ** expoente * np.clip((1 - d) / 0.08, 0, 1)
    arr = np.zeros((tam, tam, 4), np.uint8)
    arr[..., 0], arr[..., 1], arr[..., 2] = cor_
    arr[..., 3] = dither(a)
    return Image.fromarray(arr, "RGBA")


salvar(radial(256, 2.2), "brilho.png")
salvar(radial(64, 1.3), "faisca.png")
# sombra dos botoes (macia e escura)
som = radial(256, 1.6, (0, 0, 0))
salvar(som, "sombra.png")

# confete (quadradinho branco: a cor vem do jogo)
conf = Image.new("RGBA", (16, 10), (255, 255, 255, 255))
salvar(conf, "confete.png")

# estrela de 4 pontas (fogos)
tam = 128
g4 = tam * 4
est = Image.new("L", (g4, g4), 0)
d = ImageDraw.Draw(est)
c = g4 / 2
for ang in (0, 90):
    rr = math.radians(ang)
    pts = []
    for k, (raio, off) in enumerate(((c, 0), (32, 90), (c, 180), (32, 270))):
        a = rr + math.radians(off)
        pts.append((c + math.cos(a) * raio, c + math.sin(a) * raio))
    d.polygon(pts, fill=255)
est = est.filter(ImageFilter.GaussianBlur(8)).resize((tam, tam), Image.LANCZOS)
im = Image.new("RGBA", (tam, tam), (255, 255, 255, 0))
im.putalpha(est)
salvar(Image.alpha_composite(im, radial(tam, 3.0)), "estrela.png")

# anel de selecao (fica embaixo dos botoes da vez)
tam = 256
yy, xx = np.mgrid[0:tam, 0:tam].astype(np.float32)
c = (tam - 1) / 2
dd = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
a = np.exp(-((dd - 0.82) / 0.07) ** 2) + 0.35 * np.exp(-((dd - 0.82) / 0.18) ** 2)
arr = np.zeros((tam, tam, 4), np.uint8)
arr[..., :3] = 255
arr[..., 3] = dither(np.clip(a, 0, 1))
salvar(Image.fromarray(arr, "RGBA"), "anel.png")


# ======================================================= ESTADIOS
# Cada time tem o seu: padrao do corte da grama, arquibancada puxada para as
# cores do time, placas com o nome do estadio e o escudo pintado no circulo
# central. "extra" = estadio neutro do time do pendrive (o jogo poe o nome e
# o escudo por cima).
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
_ruido = RNG.normal(0, 1, (H, W)).astype(np.float32)
RUIDO = np.asarray(Image.fromarray(((_ruido * 20) + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 128 - 1


def padrao_grama(tipo):
    x = xx - s(CAMPO[0])
    y = yy - s(CAMPO[1])
    if tipo == "xadrez":
        return (np.floor(x / s(50)) + np.floor(y / s(57))) % 2 == 0
    if tipo == "xadrez_miudo":
        return (np.floor(x / s(34)) + np.floor(y / s(38))) % 2 == 0
    if tipo == "faixas" or tipo == "faixas_largas":
        return np.floor(x / s(100 if tipo == "faixas" else 125)) % 2 == 0
    if tipo == "listras_finas":
        return np.floor(x / s(31)) % 2 == 0
    if tipo == "listras_horizontais":
        return np.floor(y / s(57)) % 2 == 0
    if tipo == "diagonal":
        return np.floor((x + y) / s(62)) % 2 == 0
    if tipo == "xadrez_diagonal":
        return (np.floor((x + y) / s(60)) + np.floor((x - y) / s(60))) % 2 == 0
    if tipo == "circulos":
        return np.floor(np.sqrt((xx - s(CX)) ** 2 + (yy - s(CY)) ** 2) / s(52)) % 2 == 0
    if tipo == "ondas":
        return np.floor((x + np.sin(y / s(60)) * s(22)) / s(55)) % 2 == 0
    return np.floor(x / s(50)) % 2 == 0


def linhas(d, larg=s(2.6), cor_=(255, 255, 255, 235)):
    x0, y0, x1, y1 = [s(v) for v in CAMPO]
    d.rectangle([x0, y0, x1, y1], outline=cor_, width=int(larg))
    d.line([(s(CX), y0), (s(CX), y1)], fill=cor_, width=int(larg))
    rc = s(RAIO_CIRCULO)
    d.ellipse([s(CX) - rc, s(CY) - rc, s(CX) + rc, s(CY) + rc], outline=cor_, width=int(larg))
    d.ellipse([s(CX) - 5, s(CY) - 5, s(CX) + 5, s(CY) + 5], fill=cor_)
    for lado_ in (-1, 1):
        xl = s(CAMPO[0]) if lado_ < 0 else s(CAMPO[2])
        dirx = 1 if lado_ < 0 else -1
        xa = xl + dirx * s(AREA_P)
        d.rectangle([min(xl, xa), s(CY - AREA_MEIA), max(xl, xa), s(CY + AREA_MEIA)], outline=cor_, width=int(larg))
        xg = xl + dirx * s(AREA_G)
        d.rectangle([min(xl, xg), s(CY - AREA_G_MEIA), max(xl, xg), s(CY + AREA_G_MEIA)], outline=cor_, width=int(larg))
        xp = xl + dirx * s(MARCA_PEN)
        d.ellipse([xp - 5, s(CY) - 5, xp + 5, s(CY) + 5], fill=cor_)
        rr = s(RAIO_CIRCULO)
        ang = math.degrees(math.acos((s(AREA_P) - s(MARCA_PEN)) / rr))
        if lado_ < 0:
            d.arc([xp - rr, s(CY) - rr, xp + rr, s(CY) + rr], -ang, ang, fill=cor_, width=int(larg))
        else:
            d.arc([xp - rr, s(CY) - rr, xp + rr, s(CY) + rr], 180 - ang, 180 + ang, fill=cor_, width=int(larg))
    rr = s(14)
    for (x, y, a0) in [(CAMPO[0], CAMPO[1], 0), (CAMPO[2], CAMPO[1], 90), (CAMPO[2], CAMPO[3], 180), (CAMPO[0], CAMPO[3], 270)]:
        d.arc([s(x) - rr, s(y) - rr, s(x) + rr, s(y) + rr], a0, a0 + 90, fill=cor_, width=int(larg))


def chao_gol(d):
    for lado_ in (-1, 1):
        xl = s(CAMPO[0]) if lado_ < 0 else s(CAMPO[2])
        xf = xl - s(GOL_FUNDO) if lado_ < 0 else xl + s(GOL_FUNDO)
        d.rectangle([min(xl, xf), s(CY - GOL_MEIA), max(xl, xf), s(CY + GOL_MEIA)], fill=(10, 30, 14, 140))


REFLETORES = [(40, 30), (1240, 30), (40, 690), (1240, 690)]


def estadio(nome_arq, textos, cores_placas, grama_tipo, tinta, emb=None, verde=("#2f8f3a", "#277f33")):
    img = np.zeros((H, W, 3), np.float32)
    concreto = np.array(cor("#1a1e2b"), np.float32)
    if tinta is not None:
        concreto = concreto * 0.6 + np.array(cor(tinta), np.float32) * 0.18
    img[:] = concreto
    degrau = (np.sin(yy / s(12) * math.pi) * 0.5 + 0.5)
    lado = (np.sin(xx / s(12) * math.pi) * 0.5 + 0.5)
    em_cima = yy < s(MURO[1] - 12)
    em_baixo = yy > s(MURO[3] + 12)
    nos_lados = (xx < s(MURO[0] - 12)) | (xx > s(MURO[2] + 12))
    arq = em_cima | em_baixo | nos_lados
    tom = np.where(nos_lados & ~em_cima & ~em_baixo, lado, degrau)
    img = np.where(arq[..., None], img * (0.75 + 0.35 * tom[..., None]), img)
    # gramado
    gx0, gy0, gx1, gy1 = [s(v) for v in MURO]
    dentro = (xx >= gx0) & (xx < gx1) & (yy >= gy0) & (yy < gy1)
    listra = padrao_grama(grama_tipo)
    grama = np.where(listra[..., None], np.array(cor(verde[0]), np.float32), np.array(cor(verde[1]), np.float32))
    grama = grama * (1 + 0.07 * RUIDO[..., None])
    luz = 1.0 - 0.22 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - s(CY)) / (H / 2)) ** 2)
    grama = grama * luz[..., None]
    img = np.where(dentro[..., None], grama, img)
    # escudo pintado no circulo central (tinta branca translucida no gramado)
    if emb is not None:
        tam_e = int(s(118))
        e_ = emb.resize((tam_e, tam_e), Image.LANCZOS)
        camada = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        camada.alpha_composite(e_, (int(s(CX) - tam_e / 2), int(s(CY) - tam_e / 2)))
        arr = np.asarray(camada, np.float32) / 255.0
        arr[..., 3] *= 0.42
        img = por_cima(img, arr)
    img = por_cima(img, blur_camada(linhas, 0.7))
    img = por_cima(img, blur_camada(chao_gol, 4))
    # placas de publicidade
    placas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dp = ImageDraw.Draw(placas)
    f_placa = fonte("bungee", s(10))

    def placa(x0, y0, x1, y1, vertical=False, idx=0):
        fundo_, letra = cores_placas[idx % len(cores_placas)]
        dp.rectangle([x0, y0, x1, y1], fill=cor(fundo_) + (255,))
        txt = textos[idx % len(textos)]
        if vertical:
            t = Image.new("RGBA", (int(y1 - y0), int(x1 - x0)), (0, 0, 0, 0))
            ImageDraw.Draw(t).text(((y1 - y0) / 2, (x1 - x0) / 2), txt, font=f_placa, fill=cor(letra) + (255,), anchor="mm")
            t = t.rotate(90 if x0 < W / 2 else -90, expand=True)
            placas.alpha_composite(t, (int(x0), int(y0)))
        else:
            dp.text(((x0 + x1) / 2, (y0 + y1) / 2 + 1), txt, font=f_placa, fill=cor(letra) + (255,), anchor="mm")

    n = 6
    larg_p = (s(MURO[2]) - s(MURO[0])) / n
    for i in range(n):
        placa(s(MURO[0]) + i * larg_p + 3, s(MURO[1] - 13), s(MURO[0]) + (i + 1) * larg_p - 3, s(MURO[1]) - 2, idx=i)
        placa(s(MURO[0]) + i * larg_p + 3, s(MURO[3]) + 2, s(MURO[0]) + (i + 1) * larg_p - 3, s(MURO[3] + 13), idx=i + 1)
    for i in range(3):
        alt_p = (s(MURO[3]) - s(MURO[1])) / 3
        for xa, xb in ((s(MURO[0] - 13), s(MURO[0]) - 2), (s(MURO[2]) + 2, s(MURO[2] + 13))):
            placa(xa, s(MURO[1]) + i * alt_p + 3, xb, s(MURO[1]) + (i + 1) * alt_p - 3, vertical=True, idx=i + 2)
    img = por_cima(img, np.asarray(placas, np.float32) / 255)
    img = somar(img, desfocar(placas, 10), 0.25)

    def refletores(d):
        for (x, y) in REFLETORES:
            d.ellipse([s(x) - s(26), s(y) - s(26), s(x) + s(26), s(y) + s(26)], fill=(255, 250, 220, 255))

    img = somar(img, blur_camada(refletores, s(40)), 0.9)
    img = somar(img, blur_camada(refletores, s(8)), 0.8)

    def lampadas(d):
        for (x, y) in REFLETORES:
            for i in range(3):
                for j in range(2):
                    px, py = s(x) + (i - 1) * s(9), s(y) + (j - 0.5) * s(9)
                    d.ellipse([px - s(3.5), py - s(3.5), px + s(3.5), py + s(3.5)], fill=(255, 255, 240, 255))

    img = por_cima(img, blur_camada(lampadas, 0.8))
    est = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    # JPG: o gramado nao tem transparencia e fica ~5x menor que PNG
    est.save(os.path.join(IMG, nome_arq + ".jpg"), quality=90, subsampling=0)
    est.resize((1280, 720), Image.LANCZOS).save(os.path.join(IMG, nome_arq + "_720.jpg"), quality=90, subsampling=0)
    print(nome_arq, "jpg")
    return est


VERDES = [("#2f8f3a", "#277f33"), ("#2d8a36", "#23772c"), ("#338f3d", "#2a8034"), ("#2b8638", "#24762f")]
# cada gramado com o seu tom de verde e o corte bem marcado (gramado único)
VERDE_TIME = {"BRA": ("#3aa046", "#2a8436"), "ARG": ("#3d9142", "#2b7230"), "ITA": ("#4c9a3d", "#397d2e"),
    "ESP": ("#58a03b", "#41832e"), "FRA": ("#309049", "#22743a"), "ALE": ("#2e8c40", "#1f6c2f"),
    "NOR": ("#2b8148", "#1d6436"), "SUE": ("#36924b", "#26763a"), "AUS": ("#4f9c3b", "#3a7f2c"),
    "ING": ("#2c7f36", "#1c6227"), "LAZ": ("#35a24c", "#22803b")}
for i_, t_ in enumerate(TIMES):
    u1, u2 = t_["u1"], t_["u2"]
    cores_p = [(u1[0], u1[1]), ("#0b1e5b", "#ffd21f"), (u2[0], u2[1]), ("#d4171e", "#ffffff")]
    # placas escuras demais com letra escura: garante contraste
    cores_p = [(f, l) if sum(cor(f)) > 200 or sum(cor(l)) > 300 else (f, "#FFFFFF") for f, l in cores_p]
    textos = [t_["estadio"], "LAZER & SPORT", t_["nome"], "CRAQUE DE BOTÃO"]
    ultimo = estadio("estadio_%s" % t_["sigla"].lower(), textos, cores_p, t_["grama"], t_["torcida"][0], EMBLEMAS[t_["sigla"]], VERDE_TIME.get(t_["sigla"], VERDES[i_ % len(VERDES)]))
# estadio do time do pendrive (neutro; nome e escudo vem do jogo)
estadio("estadio_extra", ["CRAQUE DE BOTÃO", "LAZER & SPORT", "CRAQUE DE BOTÃO", "LAZER & SPORT"],
        [("#111111", "#ffffff"), ("#0b1e5b", "#ffd21f"), ("#1b1b1b", "#ff8a00"), ("#d4171e", "#ffffff")], "listras", None, None)
estadio_splash = ultimo


# ================================================= REDES (por cima da bola)
def rede(lado_):
    """Rede vista de cima + trave de cima, em 1280 (x2 de resolucao)."""
    k = 2
    w_, h_ = (GOL_FUNDO + 8) * k, (GOL_MEIA * 2 + 16) * k
    im = Image.new("RGBA", (w_, h_), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x_linha = w_ - 4 * k if lado_ < 0 else 4 * k
    x_fundo = 4 * k if lado_ < 0 else w_ - 4 * k
    y0, y1 = 8 * k, h_ - 8 * k
    # malha
    for i in range(0, int(abs(x_linha - x_fundo)) + 1, 6 * k):
        x = min(x_linha, x_fundo) + i
        d.line([(x, y0), (x, y1)], fill=(255, 255, 255, 95), width=k)
    for j in range(0, y1 - y0 + 1, 6 * k):
        d.line([(min(x_linha, x_fundo), y0 + j), (max(x_linha, x_fundo), y0 + j)], fill=(255, 255, 255, 95), width=k)
    # armacao do fundo e laterais
    d.line([(x_fundo, y0), (x_fundo, y1)], fill=(235, 235, 235, 230), width=2 * k)
    d.line([(x_linha, y0), (x_fundo, y0)], fill=(235, 235, 235, 230), width=2 * k)
    d.line([(x_linha, y1), (x_fundo, y1)], fill=(235, 235, 235, 230), width=2 * k)
    # travessao (trave de cima) na linha do gol
    sombra = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sombra).line([(x_linha + (3 if lado_ < 0 else -3) * k, y0), (x_linha + (3 if lado_ < 0 else -3) * k, y1)], fill=(0, 0, 0, 120), width=4 * k)
    im = Image.alpha_composite(sombra.filter(ImageFilter.GaussianBlur(3)), im)
    d = ImageDraw.Draw(im)
    d.line([(x_linha, y0), (x_linha, y1)], fill=(255, 255, 255, 255), width=4 * k)
    for yv in (y0, y1):
        d.ellipse([x_linha - 5 * k, yv - 5 * k, x_linha + 5 * k, yv + 5 * k], fill=(255, 255, 255, 255))
    return im


salvar(rede(-1), "rede_esq.png")
salvar(rede(1), "rede_dir.png")


# ================================================= TORCIDA (camada animada)
# Cada torcedor fica numa celula de CEL px (1920). Canais:
#   R = luz/sombra, G = 1.0 camisa / 0.5 pele / 0.0 cabelo, A = cobertura
# torcida_ids.png: 1 pixel por celula (R = fase do pulo, G = cor da camisa,
# B = tom de pele). O shader torcida.shader pinta com as cores das selecoes
# (metade esquerda do estadio = time da casa) e faz a galera pular.
CEL = 18
cols, rows = int(math.ceil(W / CEL)), int(math.ceil(H / CEL))
tor = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dt = ImageDraw.Draw(tor)
ids = np.zeros((rows, cols, 3), np.uint8)
for j in range(rows):
    for i in range(cols):
        x0, y0 = i * CEL, j * CEL
        cxp, cyp = x0 + CEL / 2, y0 + CEL / 2
        arquibancada = (cyp < s(MURO[1] - 16)) or (cxp < s(MURO[0] - 16)) or (cxp > s(MURO[2] + 16)) or (cyp > s(MURO[3] + 16))
        perto_ref = any(abs(cxp - s(x)) < s(34) and abs(cyp - s(y)) < s(34) for (x, y) in [(40, 30), (1240, 30), (40, 690), (1240, 690)])
        if not arquibancada or perto_ref or RNG.random() < 0.06:
            continue
        ids[j, i] = (int(RNG.integers(0, 256)), int(RNG.integers(0, 256)), int(RNG.integers(0, 256)))
        jx, jy = RNG.uniform(-1.5, 1.5), RNG.uniform(-1.0, 1.5)
        # ombros/camisa (G=255) e cabeca (G=128), cabelo (G=0) - luz no R
        dt.ellipse([cxp - 7 + jx, cyp - 1 + jy, cxp + 7 + jx, cyp + 7 + jy], fill=(200, 255, 0, 255))
        dt.ellipse([cxp - 4.2 + jx, cyp - 6 + jy, cxp + 4.2 + jx, cyp + 2 + jy], fill=(235, 128, 0, 255))
        if RNG.random() < 0.7:
            dt.chord([cxp - 4.2 + jx, cyp - 6.2 + jy, cxp + 4.2 + jx, cyp + 1 + jy], 180, 360, fill=(90, 0, 0, 255))
t_arr = np.asarray(tor.filter(ImageFilter.GaussianBlur(0.5)), np.float32)
# sombreamento: parte de baixo de cada pessoa mais escura
yy_c = (np.arange(H) % CEL)[:, None] / CEL
t_arr[..., 0] = t_arr[..., 0] * (1.05 - 0.35 * yy_c)
salvar(Image.fromarray(np.clip(t_arr, 0, 255).astype(np.uint8), "RGBA"), "torcida.png")
salvar(Image.fromarray(ids, "RGB"), "torcida_ids.png")
print("torcida: celulas", cols, rows)


# ======================================================= LOGO
def logo():
    w_, h_ = 1400, 520
    im = Image.new("RGBA", (w_, h_), (0, 0, 0, 0))
    f1 = fonte("titan", 190)
    f2 = fonte("titan", 150)
    f3 = fonte("bungee", 58)

    def texto_estilo(txt, f, y, c1, c2, contorno=16):
        mas = Image.new("L", (w_, h_), 0)
        ImageDraw.Draw(mas).text((w_ / 2, y), txt, font=f, fill=255, anchor="mm")
        grossa = mas.filter(ImageFilter.MaxFilter(contorno * 2 + 1))
        sombra = grossa.filter(ImageFilter.GaussianBlur(10))
        camada = Image.new("RGBA", (w_, h_), (0, 0, 0, 0))
        camada.paste((0, 0, 0, 150), (0, 0), sombra.point(lambda v: v * 0.8))
        base = Image.new("RGBA", (w_, h_), (10, 30, 70, 255))
        camada = Image.composite(base, camada, grossa)
        # degrade vertical nas letras
        gy = np.linspace(0, 1, h_)[:, None]
        a1, a2 = np.array(c1, np.float32), np.array(c2, np.float32)
        grad = (a1 * (1 - gy[..., None]) + a2 * gy[..., None])
        grad = np.broadcast_to(grad, (h_, w_, 3))
        g_im = Image.fromarray(grad.astype(np.uint8), "RGB").convert("RGBA")
        camada = Image.composite(g_im, camada, mas)
        # brilho em cima das letras
        br = Image.new("L", (w_, h_), 0)
        ImageDraw.Draw(br).text((w_ / 2, y - 6), txt, font=f, fill=90, anchor="mm")
        corte = Image.new("L", (w_, h_), 0)
        ImageDraw.Draw(corte).rectangle([0, 0, w_, y - 10], fill=255)
        br = Image.fromarray(np.minimum(np.asarray(br), np.asarray(corte)))
        camada = Image.composite(Image.new("RGBA", (w_, h_), (255, 255, 255, 255)), camada, br.point(lambda v: v))
        return camada

    im = Image.alpha_composite(im, texto_estilo("CRAQUE", f1, 118, (255, 236, 80), (255, 150, 0)))
    im = Image.alpha_composite(im, texto_estilo("DE BOTÃO", f2, 292, (255, 255, 255), (170, 230, 255)))
    d = ImageDraw.Draw(im)
    # faixa "FUTEBOL DE MESA"
    fx0, fx1, fy0, fy1 = 300, 1100, 390, 470
    d.polygon([(fx0 - 30, fy0), (fx1 + 30, fy0), (fx1, (fy0 + fy1) / 2), (fx1 + 30, fy1), (fx0 - 30, fy1), (fx0, (fy0 + fy1) / 2)], fill=(0, 140, 60, 255))
    d.rectangle([fx0, fy0 + 8, fx1, fy1 - 8], fill=(0, 170, 75, 255))
    d.text((w_ / 2, (fy0 + fy1) / 2 + 2), "FUTEBOL DE MESA", font=f3, fill=(255, 255, 255, 255), anchor="mm")
    return im


salvar(logo(), "logo.png")


# ======================================================= TROFEU
def trofeu(w_=400, h_=560):
    k = 2
    im = Image.new("RGBA", (w_ * k, h_ * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    W2, H2 = w_ * k, h_ * k
    ouro1, ouro2 = (255, 214, 64, 255), (196, 132, 18, 255)
    # base
    d.rounded_rectangle([W2 * 0.22, H2 * 0.82, W2 * 0.78, H2 * 0.97], radius=20, fill=(40, 90, 45, 255))
    d.rounded_rectangle([W2 * 0.26, H2 * 0.84, W2 * 0.74, H2 * 0.95], radius=16, fill=(30, 70, 35, 255))
    d.rectangle([W2 * 0.3, H2 * 0.87, W2 * 0.7, H2 * 0.9], fill=ouro1)
    # haste
    d.polygon([(W2 * 0.42, H2 * 0.82), (W2 * 0.58, H2 * 0.82), (W2 * 0.54, H2 * 0.6), (W2 * 0.46, H2 * 0.6)], fill=ouro2)
    # taca
    d.pieslice([W2 * 0.18, H2 * 0.02, W2 * 0.82, H2 * 0.66], 0, 180, fill=ouro1)
    d.rectangle([W2 * 0.18, H2 * 0.08, W2 * 0.82, H2 * 0.34], fill=ouro1)
    d.ellipse([W2 * 0.18, H2 * 0.02, W2 * 0.82, H2 * 0.14], fill=ouro2)
    d.ellipse([W2 * 0.21, H2 * 0.035, W2 * 0.79, H2 * 0.125], fill=(150, 95, 10, 255))
    # alcas
    for sx in (-1, 1):
        cx_ = W2 * 0.5 + sx * W2 * 0.36
        d.arc([cx_ - W2 * 0.14, H2 * 0.1, cx_ + W2 * 0.14, H2 * 0.38], 270 if sx > 0 else 90, 90 if sx > 0 else 270, fill=ouro2, width=int(W2 * 0.05))
    # estrela
    cx_, cy_, r_ = W2 * 0.5, H2 * 0.3, W2 * 0.1
    d.polygon([(cx_ + math.cos(-math.pi / 2 + i * math.pi / 5) * (r_ if i % 2 == 0 else r_ * 0.45),
                cy_ + math.sin(-math.pi / 2 + i * math.pi / 5) * (r_ if i % 2 == 0 else r_ * 0.45)) for i in range(10)], fill=(255, 250, 220, 255))
    arr = np.asarray(im, np.float32)
    xs = np.linspace(0, 1, W2)[None, :]
    brilho_ = 1.0 + 0.35 * np.exp(-((xs - 0.38) / 0.08) ** 2) - 0.25 * np.clip((xs - 0.6) / 0.3, 0, 1)
    arr[..., :3] = np.clip(arr[..., :3] * brilho_[..., None], 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA").resize((w_, h_), Image.LANCZOS)


salvar(trofeu(), "trofeu.png")


# ======================================================= CARTOES
def cartao(c):
    w_, h_ = 120, 168
    im = Image.new("RGBA", (w_, h_), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([4, 4, w_ - 4, h_ - 4], radius=12, fill=cor(c) + (255,))
    br = Image.new("RGBA", (w_, h_), (0, 0, 0, 0))
    ImageDraw.Draw(br).polygon([(4, 4), (w_ * 0.7, 4), (4, h_ * 0.55)], fill=(255, 255, 255, 70))
    im = Image.alpha_composite(im, br)
    return im


salvar(cartao("#FFD400"), "cartao_amarelo.png")
salvar(cartao("#E3001B"), "cartao_vermelho.png")


# ======================================================= ICONE / SPLASH
def icone():
    t = 432
    ic = Image.new("RGBA", (t, t), cor("#0b6b2a") + (255,))
    d = ImageDraw.Draw(ic)
    for i in range(0, t, 54):
        d.rectangle([i, 0, i + 27, t], fill=cor("#0e7a31") + (255,))
    d.ellipse([t * 0.18, t * 0.18, t * 0.82, t * 0.82], outline=(255, 255, 255, 200), width=8)
    b = botao("#FFD200", "#009C3B", tam=260, emb=EMBLEMAS["BRA"])
    ic.alpha_composite(b, (int(t * 0.2), int(t * 0.2)))
    bl = bola(96)
    ic.alpha_composite(bl, (int(t * 0.62), int(t * 0.6)))
    return ic


salvar(icone(), "icone.png")
fundo_ic = Image.new("RGBA", (432, 432), cor("#0b6b2a") + (255,))
salvar(fundo_ic, "fundo_icone.png")

sp = estadio_splash.resize((1280, 720), Image.LANCZOS).filter(ImageFilter.GaussianBlur(6)).convert("RGBA")
escuro = Image.new("RGBA", sp.size, (0, 0, 0, 120))
sp = Image.alpha_composite(sp, escuro)
lg = logo()
lg = lg.resize((int(lg.width * 0.62), int(lg.height * 0.62)), Image.LANCZOS)
sp.alpha_composite(lg, ((1280 - lg.width) // 2, (720 - lg.height) // 2))
salvar(sp.convert("RGB"), "splash.png")


# ======================================================= CLIMA
# chuva: risco da gota caindo, gotinha (respingo), onda na poca; sol/noite:
# a graminha que voa; noite: mapa de luz (multiplica a cena: refletores).
def risco(w=6, h=72):
    g = 4
    im = Image.new("L", (w * g, h * g), 0)
    ys = np.linspace(0, 1, h * g)[:, None]
    xs = np.abs(np.linspace(-1, 1, w * g))[None, :]
    a = np.clip(1 - xs, 0, 1) ** 1.5 * np.clip(ys, 0, 1) ** 1.2
    arr = np.zeros((h * g, w * g, 4), np.uint8)
    arr[..., :3] = 255
    arr[..., 3] = dither(a * 0.9)
    return Image.fromarray(arr, "RGBA").resize((w, h), Image.LANCZOS)


salvar(risco(), "chuva_risco.png")
salvar(radial(32, 1.2), "gota.png")

tam = 128
yy, xx = np.mgrid[0:tam, 0:tam].astype(np.float32)
c = (tam - 1) / 2
dd = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
arr = np.zeros((tam, tam, 4), np.uint8)
arr[..., :3] = 255
arr[..., 3] = dither(np.clip(np.exp(-((dd - 0.85) / 0.06) ** 2), 0, 1))
salvar(Image.fromarray(arr, "RGBA"), "onda.png")


def graminha(w=10, h=26):
    g = 6
    im = Image.new("RGBA", (w * g, h * g), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(w * g * 0.5, 0), (w * g * 0.85, h * g * 0.75), (w * g * 0.5, h * g), (w * g * 0.18, h * g * 0.7)], fill=(120, 200, 70, 255))
    d.line([(w * g * 0.5, h * g * 0.05), (w * g * 0.5, h * g * 0.95)], fill=(170, 235, 110, 255), width=g)
    return im.resize((w, h), Image.LANCZOS)


salvar(graminha(), "graminha.png")


def mapa_noite():
    # noite com os 4 refletores acesos: o GRAMADO fica bem claro (quase como
    # de dia, levemente azulado) e o escuro fica nas arquibancadas em volta;
    # as poças de luz dos refletores clareiam os cantos do campo.
    w, h = 640, 360
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) * 2
    dx = np.maximum(np.maximum(140 - xx, xx - 1140), 0)
    dy = np.maximum(np.maximum(110 - yy, yy - 680), 0)
    fora = np.sqrt(dx ** 2 + dy ** 2)
    campo = np.exp(-(fora / 70.0) ** 2)
    luz = np.zeros((h, w), np.float32)
    for (x, y) in REFLETORES:
        d = np.sqrt((xx - x) ** 2 + (yy - y) ** 2)
        luz += np.exp(-(d / 620.0) ** 2) * 0.35
    base = np.clip(0.3 + 0.6 * campo + luz * 0.35, 0, 0.97)
    img = Image.fromarray((base * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(10))
    b = np.asarray(img, np.float32) / 255
    rgb = np.stack([b * 0.93 + 0.02, b * 0.95 + 0.03, np.clip(b * 1.0 + 0.04, 0, 1)], -1)
    return Image.fromarray(dither(rgb), "RGB")


salvar(mapa_noite(), "noite.png")
