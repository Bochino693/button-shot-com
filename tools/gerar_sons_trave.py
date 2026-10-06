"""Bola na trave (build 8): o "PLÉÉIM" do metal e o "UUUUH!" da torcida.

    python3 tools/gerar_sons_trave.py

O "uuuh" de estádio não é vaia: começa de repente, a altura SOBE junto
(susto) e depois desce devagar com o "h" do desânimo; vozes graves e agudas,
com o eco do estádio. O metal é um tubo batido: parciais inarmônicas do
tubo, estalo do impacto e o zumbido que fica.
"""
import os
import wave

import numpy as np
from scipy.signal import lfilter, fftconvolve

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SONS = os.path.join(RAIZ, "sons")
SR = 22050
RNG = np.random.default_rng(81)


def salvar_wav(nome, x, pico=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * pico
    with wave.open(os.path.join(SONS, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(nome, "%.2fs" % (len(x) / SR))


def ressoador(x, f, largura):
    r = np.exp(-np.pi * largura / SR)
    th = 2 * np.pi * f / SR
    return lfilter([1 - r], [1.0, -2 * r * np.cos(th), r * r], x)


def passa_banda(x, f0, f1):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    X[(fr < f0) | (fr > f1)] = 0
    return np.fft.irfft(X, len(x))


# ------------------------------------------------------------- UUUUH
DUR = 2.3
N = int(SR * DUR)
x = np.arange(N) / SR
# contorno da multidão: sobe rápido (0 -> 0.32 s), segura e desce
contorno = np.interp(x, [0, 0.08, 0.32, 0.7, 1.4, DUR], [0.82, 0.95, 1.22, 1.15, 0.92, 0.8])
volume = np.interp(x, [0, 0.07, 0.3, 0.8, 1.6, DUR], [0.0, 0.55, 1.0, 0.85, 0.35, 0.0]) ** 1.2
# vogal: "ô" aberto no susto, fecha para "u" e solta o ar ("h") no fim
mix_o = np.interp(x, [0, 0.3, 0.9, DUR], [1.0, 0.8, 0.3, 0.1])
uh = np.zeros(N)
for k in range(260):
    agudo = RNG.random() < 0.35
    f0 = RNG.uniform(190, 300) if agudo else RNG.uniform(105, 170)
    atraso = abs(RNG.normal(0, 0.06))
    i0 = int(atraso * SR)
    m = N - i0
    xs = np.arange(m) / SR
    c = contorno[:m] * RNG.uniform(0.96, 1.04)
    vib = 1 + 0.015 * np.sin(2 * np.pi * RNG.uniform(4.5, 6.5) * xs + RNG.uniform(0, 6))
    f = f0 * c * vib
    fase = np.cumsum(f) / SR
    pulso = (fase % 1.0) * 2 - 1 + 0.2 * RNG.uniform(-1, 1, m)
    esc = RNG.uniform(0.93, 1.08) * (1.12 if agudo else 1.0)
    vo = ressoador(pulso, 520 * esc, 90) + 0.6 * ressoador(pulso, 880 * esc, 120) + 0.2 * ressoador(pulso, 2400 * esc, 170)
    vu = ressoador(pulso, 340 * esc, 80) + 0.5 * ressoador(pulso, 780 * esc, 110) + 0.12 * ressoador(pulso, 2300 * esc, 170)
    v = vo * mix_o[:m] + vu * (1 - mix_o[:m])
    # cada um para numa hora
    fim = RNG.uniform(1.1, DUR - 0.05)
    corte = np.clip((fim - xs) / 0.25, 0, 1)
    uh[i0:] += v * volume[:m] * corte * RNG.uniform(0.35, 1.0)
# o ar ("hhh") e o mar da torcida
ar = passa_banda(RNG.uniform(-1, 1, N), 300, 2600) * np.interp(x, [0, 0.3, 1.0, DUR], [0, 0.25, 0.4, 0.0])
uh = uh / (np.max(np.abs(uh)) + 1e-9) + ar * 0.35
# eco do estádio (resposta ao impulso de ~1.3 s)
ir_n = int(SR * 1.3)
ir = RNG.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / SR / 0.35)
ir = passa_banda(ir, 120, 5000)
ir[0] = 6.0
uh = fftconvolve(uh, ir)[:N + int(SR * 0.6)]
fade = np.ones(len(uh))
fade[-int(SR * 0.6):] = np.linspace(1, 0, int(SR * 0.6))
salvar_wav("torcida_uuu", uh * fade, 0.85)

# ------------------------------------------------------------- METAL
DUR = 1.6
N = int(SR * DUR)
x = np.arange(N) / SR
# tubo de aço batido: modos de flexão (razões ~1 : 2.76 : 5.40 : 8.93)
f1 = 610.0
metal = np.zeros(N)
for razao, amp, queda in [(1.0, 1.0, 0.55), (2.756, 0.7, 0.42), (5.404, 0.45, 0.25), (8.933, 0.3, 0.15), (13.34, 0.18, 0.08)]:
    for desv in (-0.6, 0.6):  # par de modos levemente desafinados (batimento)
        metal += amp * 0.5 * np.sin(2 * np.pi * (f1 * razao + desv * razao) * x + RNG.uniform(0, 6)) * np.exp(-x / queda)
# estalo do impacto (bola de couro no metal)
n_est = int(SR * 0.03)
estalo = passa_banda(RNG.uniform(-1, 1, N), 1500, 9000) * np.exp(-x / 0.006)
baque = np.sin(2 * np.pi * 140 * x) * np.exp(-x / 0.04)
metal = metal / np.max(np.abs(metal)) + 0.9 * estalo / np.max(np.abs(estalo)) + 0.5 * baque
# um pouco de ambiente
ir_n = int(SR * 0.6)
ir = RNG.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / SR / 0.12) * 0.08
ir[0] = 1.0
metal = fftconvolve(metal, ir)[:N]
salvar_wav("trave", metal, 0.92)
