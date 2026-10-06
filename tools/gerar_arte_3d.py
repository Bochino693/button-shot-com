"""Arte do estádio 3D da apresentação da Copa (Craque de Botão).

    python3 tools/gerar_arte_3d.py

torcedores.png: 16 torcedores vistos de frente, lado a lado (128x192 cada).
  Canais: R = luz/sombra, G = máscara da camisa, B = máscara da pele,
  A = forma. O shader (shaders/arquibancada.shader) pinta a camisa com as
  cores dos times, escolhe a pele e faz cada um pular na hora certa.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(RAIZ, "imagens")
W, H, N, K = 128, 192, 16, 4         # célula, variantes, superamostragem
RNG = np.random.default_rng(3)


def torcedor(v):
    """Torcedor visto de frente, com volume (sombra redonda), cabelo/boné,
    pescoço, ombros e braços em poses diferentes; bordas suaves."""
    w, h = W * K, H * K
    k = K * W / 64.0
    camisa = Image.new("L", (w, h), 0)
    pele = Image.new("L", (w, h), 0)
    cabelo = Image.new("L", (w, h), 0)
    forma = Image.new("L", (w, h), 0)
    dc, dp, dh, df = ImageDraw.Draw(camisa), ImageDraw.Draw(pele), ImageDraw.Draw(cabelo), ImageDraw.Draw(forma)
    cx = w / 2 + RNG.uniform(-3, 3) * k
    larg = RNG.uniform(16, 21) * k
    ombro = RNG.uniform(50, 55) * k
    # tronco com ombros arredondados (trapézio) e pescoço
    tronco = [(cx - larg, ombro + 8 * k), (cx - larg * 0.82, ombro), (cx + larg * 0.82, ombro), (cx + larg, ombro + 8 * k),
        (cx + larg * 0.92, h + 10), (cx - larg * 0.92, h + 10)]
    for d in (dc, df):
        d.polygon(tronco, fill=255)
        d.ellipse([cx - larg, ombro - 2 * k, cx - larg + 16 * k, ombro + 14 * k], fill=255)
        d.ellipse([cx + larg - 16 * k, ombro - 2 * k, cx + larg, ombro + 14 * k], fill=255)
    for d in (dp, df):
        d.rectangle([cx - 5 * k, ombro - 10 * k, cx + 5 * k, ombro + 4 * k], fill=255)
    # gola em V (pele)
    dp.polygon([(cx - 6 * k, ombro), (cx + 6 * k, ombro), (cx, ombro + 9 * k)], fill=255)
    braco = 6.5 * k
    pose = v % 6

    def braco_para(x0, y0, x1, y1):
        for d in (dc, df):
            d.line([(x0, y0), (x1, y1)], fill=255, width=int(braco * 2))
            d.ellipse([x0 - braco, y0 - braco, x0 + braco, y0 + braco], fill=255)
        for d in (dp, df):
            d.ellipse([x1 - 6 * k, y1 - 6 * k, x1 + 6 * k, y1 + 6 * k], fill=255)

    if pose == 0:        # os dois braços para cima
        for lado in (-1, 1):
            braco_para(cx + lado * (larg - 4 * k), ombro + 6 * k, cx + lado * (larg + 4 * k), 12 * k)
    elif pose == 1:      # um braço para cima, punho fechado
        braco_para(cx - (larg - 4 * k), ombro + 6 * k, cx - (larg + 2 * k), 10 * k)
    elif pose == 2:      # cachecol esticado acima da cabeça
        for d in (dc, df):
            d.rectangle([cx - 30 * k, 9 * k, cx + 30 * k, 17 * k], fill=255)
        for lado in (-1, 1):
            braco_para(cx + lado * (larg - 4 * k), ombro + 6 * k, cx + lado * 27 * k, 16 * k)
    elif pose == 3:      # batendo palmas (mãos na frente do peito)
        for lado in (-1, 1):
            braco_para(cx + lado * (larg - 2 * k), ombro + 8 * k, cx + lado * 3 * k, ombro + 20 * k)
    elif pose == 4:      # bandeirinha
        braco_para(cx + (larg - 4 * k), ombro + 6 * k, cx + (larg + 6 * k), 20 * k)
        for d in (dc, df):
            d.rectangle([cx + larg + 5 * k, 2 * k, cx + larg + 34 * k, 20 * k], fill=255)
            d.line([(cx + larg + 6 * k, 0), (cx + larg + 6 * k, 30 * k)], fill=255, width=int(2 * k))
    # (pose 5: braços para baixo)
    # cabeça (rosto um pouco oval) e o cabelo/boné
    cy = 34 * k
    r = RNG.uniform(10.5, 12.5) * k
    for d in (dp, df):
        d.ellipse([cx - r * 0.92, cy - r, cx + r * 0.92, cy + r * 1.08], fill=255)
    estilo = (v // 6 + v) % 5
    if estilo == 0:      # curto
        dh.chord([cx - r * 0.98, cy - r * 1.08, cx + r * 0.98, cy + r * 0.5], 180, 360, fill=255)
    elif estilo == 1:    # comprido
        dh.chord([cx - r * 1.05, cy - r * 1.1, cx + r * 1.05, cy + r * 0.7], 180, 360, fill=255)
        dh.rectangle([cx - r * 1.05, cy - r * 0.1, cx - r * 0.7, cy + r * 1.5], fill=255)
        dh.rectangle([cx + r * 0.7, cy - r * 0.1, cx + r * 1.05, cy + r * 1.5], fill=255)
    elif estilo == 2:    # boné (da cor da camisa) com aba
        for d in (dc, df):
            d.chord([cx - r * 1.02, cy - r * 1.12, cx + r * 1.02, cy + r * 0.3], 180, 360, fill=255)
            d.rectangle([cx - r * 1.1, cy - r * 0.18, cx + r * 1.25, cy - r * 0.02], fill=255)
    elif estilo == 3:    # cacheado (volume)
        for i in range(7):
            a = math.pi * (1.0 + i / 6.0)
            px, py = cx + math.cos(a) * r * 0.85, cy - r * 0.15 + math.sin(a) * r * 0.85
            dh.ellipse([px - r * 0.38, py - r * 0.38, px + r * 0.38, py + r * 0.38], fill=255)
            df.ellipse([px - r * 0.38, py - r * 0.38, px + r * 0.38, py + r * 0.38], fill=255)
    # (estilo 4: careca)
    a_forma = np.asarray(forma, np.float32) / 255
    a_cab = np.asarray(cabelo, np.float32) / 255
    a_pel = np.asarray(pele, np.float32) / 255 * (1 - a_cab)
    a_cam = np.asarray(camisa, np.float32) / 255 * (1 - a_pel) * (1 - a_cab)
    # volume: luz de cima/esquerda, sombra redonda nas bordas do corpo e da cabeça
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    corpo = 1.0 - 0.45 * np.clip(np.abs(xx - cx) / (larg * 1.15), 0, 1) ** 2
    cabeca = 1.0 - 0.5 * np.clip(np.sqrt((xx - cx + r * 0.25) ** 2 + (yy - cy + r * 0.3) ** 2) / (r * 1.35), 0, 1) ** 2
    luz = np.where(yy < ombro - 6 * k, cabeca, corpo) * (1.0 - 0.3 * (yy / h))
    luz = np.clip(luz, 0.3, 1.0)
    arr = np.zeros((h, w, 4), np.float32)
    arr[..., 0] = luz
    arr[..., 1] = a_cam
    arr[..., 2] = a_pel
    arr[..., 3] = a_forma
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    return im.resize((W, H), Image.LANCZOS)


atlas = Image.new("RGBA", (W * N, H), (0, 0, 0, 0))
for v in range(N):
    atlas.paste(torcedor(v), (v * W, 0))
atlas.save(os.path.join(IMG, "torcedores.png"), optimize=True)
print("torcedores.png", atlas.size)

# céu estrelado (noite) e nuvens (chuva) para o fundo do estádio 3D
w, h = 1024, 512
gy = np.linspace(0, 1, h)[:, None]
# noite em 2048x1024 com estrelas redondas e suaves (sem pixel quadrado)
wn, hn = 2048, 1024
gyn = np.linspace(0, 1, hn)[:, None]
ceu = np.zeros((hn, wn, 3), np.float32)
ceu[..., 0] = 0.02 + 0.05 * gyn
ceu[..., 1] = 0.03 + 0.07 * gyn
ceu[..., 2] = 0.09 + 0.14 * gyn
rng_c = np.random.default_rng(7)
ey, ex = np.mgrid[-4:5, -4:5].astype(np.float32)
for _ in range(1500):
    x, y = int(rng_c.integers(5, wn - 5)), int(rng_c.integers(5, int(hn * 0.78)))
    b = rng_c.uniform(0.25, 1.0) ** 1.6
    sig = rng_c.uniform(0.7, 1.3)
    g = np.exp(-(ex ** 2 + ey ** 2) / (2 * sig * sig))[..., None] * b
    cor = np.array([0.9, 0.93, 1.0]) if rng_c.random() < 0.7 else np.array([1.0, 0.92, 0.8])
    ceu[y - 4:y + 5, x - 4:x + 5] = np.maximum(ceu[y - 4:y + 5, x - 4:x + 5], g * cor)
Image.fromarray((np.clip(ceu, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(IMG, "ceu_noite.png"))
nuv = RNG.normal(0, 1, (h // 8, w // 8))
nimg = Image.fromarray(((nuv - nuv.min()) / (nuv.max() - nuv.min()) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(12))
n = np.asarray(nimg, np.float32) / 255
chuva = np.stack([0.36 + 0.2 * n, 0.39 + 0.2 * n, 0.44 + 0.2 * n], -1) * (0.75 + 0.25 * gy[..., None] * 0 + 0.25 * (1 - gy)[..., None])
Image.fromarray((np.clip(chuva, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(IMG, "ceu_chuva.png"))
dia = np.stack([0.32 + 0.4 * gy + 0.1 * n, 0.55 + 0.3 * gy + 0.1 * n, 0.92 + 0.05 * gy + 0.05 * n], -1)
Image.fromarray((np.clip(dia, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(IMG, "ceu_dia.png"))
print("ceus ok")

# ruído 64x64 (sorteio por célula da torcida sem conta de seno: GPUs simples
# do Android não têm precisão para o "hash" clássico)
r = RNG.integers(0, 256, (64, 64, 4), dtype=np.uint8)
Image.fromarray(r, "RGBA").save(os.path.join(IMG, "ruido.png"))
print("ruido.png")

# lua cheia (crateras suaves) para o céu da noite
t = 256
yy, xx = np.mgrid[0:t, 0:t].astype(np.float32)
c = (t - 1) / 2
d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / (t * 0.42)
disco = np.clip((1 - d) * 40, 0, 1)
base = 0.92 - 0.12 * (xx / t) - 0.05 * (yy / t)
cr = np.zeros((t, t), np.float32)
for _ in range(26):
    cx_, cy_ = RNG.uniform(40, 216, 2)
    r_ = RNG.uniform(6, 30)
    dd = np.sqrt((xx - cx_) ** 2 + (yy - cy_) ** 2) / r_
    cr += np.clip(1 - dd, 0, 1) ** 1.5 * RNG.uniform(0.05, 0.16)
mar = np.asarray(Image.fromarray((RNG.normal(0, 1, (16, 16)) * 40 + 128).clip(0, 255).astype(np.uint8)).resize((t, t), Image.BICUBIC).filter(ImageFilter.GaussianBlur(10)), np.float32) / 255
lum = np.clip(base - cr - 0.18 * np.clip(mar - 0.5, 0, 1), 0, 1)
arr = np.zeros((t, t, 4), np.float32)
arr[..., 0] = lum * 0.97
arr[..., 1] = lum * 0.98
arr[..., 2] = lum * 1.0
arr[..., 3] = disco
Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(IMG, "lua.png"))
print("lua.png")
