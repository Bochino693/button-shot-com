"""Uniformes dos GOLEIROS ("caixinha" vista de cima, cápsula em pé).

Cada seleção tem o seu: a camisa na cor de goleiro do time (dados/times.json,
campo "goleiro"), o acabamento (contorno) e a faixa do peito nas cores do
uniforme titular, o escudo do time no meio e as luvas nas pontas. Assim o
goleiro "veste" o time, mas continua diferente dos jogadores de linha.

Saída: imagens/goleiro_<sigla>.png (128x320) e goleiro_base.png (branco,
o jogo pinta com as cores do time do pendrive).
Uso: python3 tools/gerar_goleiros.py
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(RAIZ, "imagens")
TIMES = json.load(open(os.path.join(RAIZ, "dados", "times.json"), encoding="utf-8"))["times"]


def cor(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def goleiro(camisa, aro, faixa1, faixa2, luva, emblema=None, w=128, h=320):
    g = 4
    W, H = w * g, h * g
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    raio = W * 0.48
    # contorno (acabamento) na cor do time
    d.rounded_rectangle([W * 0.02, W * 0.02, W * 0.98, H - W * 0.02], radius=raio, fill=aro + (255,))
    m = W * 0.13
    corpo = Image.new("L", (W, H), 0)
    ImageDraw.Draw(corpo).rounded_rectangle([m, m, W - m, H - m], radius=raio - m, fill=255)
    camada = Image.new("RGBA", (W, H), camisa + (255,))
    dc = ImageDraw.Draw(camada)
    # faixa do peito: duas listras nas cores do time, atravessando o meio
    cy = H / 2
    alt = H * 0.085
    dc.rectangle([0, cy - alt * 1.55, W, cy - alt * 0.55], fill=faixa1 + (255,))
    dc.rectangle([0, cy + alt * 0.55, W, cy + alt * 1.55], fill=faixa2 + (255,))
    # luvas nas pontas (os "braços" da caixinha)
    for yy in (m * 1.15, H - m * 1.15 - W * 0.34):
        dc.ellipse([W * 0.29, yy, W * 0.71, yy + W * 0.34], fill=luva + (255,))
        dc.ellipse([W * 0.36, yy + W * 0.06, W * 0.64, yy + W * 0.2], fill=tuple(min(255, c + 40) for c in luva) + (255,))
    im.paste(camada, (0, 0), corpo)
    # escudo no meio, num disco claro (lê bem mesmo pequeno)
    if emblema is not None:
        r = W * 0.36
        d2 = ImageDraw.Draw(im)
        d2.ellipse([W / 2 - r, cy - r, W / 2 + r, cy + r], fill=(250, 250, 250, 255), outline=aro + (255,), width=int(W * 0.035))
        e = emblema.convert("RGBA")
        lado = int(r * 1.5)
        e.thumbnail((lado, lado), Image.LANCZOS)
        im.alpha_composite(e, (int(W / 2 - e.width / 2), int(cy - e.height / 2)))
    # brilho de plástico
    br = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(br).rounded_rectangle([m * 1.3, m * 1.6, W * 0.42, H - m * 1.6], radius=raio * 0.4, fill=(255, 255, 255, 50))
    im = Image.alpha_composite(im, br.filter(ImageFilter.GaussianBlur(6)))
    return im.resize((w, h), Image.LANCZOS)


for t in TIMES:
    sg = t["sigla"].lower()
    gk = cor(t["goleiro"])
    u = [cor(c) for c in t["u1"]]
    # acabamento: a cor do time que mais contrasta com a camisa do goleiro
    aro = max(u[:2], key=lambda c: dist(c, gk))
    outra = u[1] if aro == u[0] else u[0]
    faixa1, faixa2 = aro, outra
    luva = (245, 245, 245) if dist(gk, (245, 245, 245)) > 120 else outra
    arq_emb = os.path.join(IMG, "emblema_%s.png" % sg)
    emb = Image.open(arq_emb) if os.path.exists(arq_emb) else None
    goleiro(gk, aro, faixa1, faixa2, luva, emb).save(os.path.join(IMG, "goleiro_%s.png" % sg), optimize=True)
    print("goleiro_%s.png" % sg)
goleiro((255, 255, 255), (221, 221, 221), (235, 235, 235), (210, 210, 210), (245, 245, 245)).save(os.path.join(IMG, "goleiro_base.png"), optimize=True)
print("goleiro_base.png")
