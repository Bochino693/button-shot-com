"""Sons do clima do Craque de Botao (sintetizados, nada gravado).

    python3 tools/gerar_sons_clima.py

chuva.ogg: chuva em loop (chiado grave + gotas); respingo.wav: botao/bola
passando na agua; grama.wav: raspada na grama seca.
"""
import os
import subprocess
import wave

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SONS = os.path.join(RAIZ, "sons")
SR = 22050
RNG = np.random.default_rng(11)


def normal(x, pico=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * pico


def filtro(x, f0, f1):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    X *= np.clip((fr - f0) / (f0 * 0.3 + 1), 0, 1) * np.clip((f1 - fr) / (f1 * 0.3 + 1), 0, 1)
    return np.fft.irfft(X, len(x))


def wav(nome, x, pico=0.9):
    x = normal(x, pico)
    with wave.open(os.path.join(SONS, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(nome, "%.2fs" % (len(x) / SR))


def ogg(nome, x, pico=0.6):
    x = normal(x, pico)
    tmp = os.path.join(SONS, nome + "_tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(SONS, nome + ".ogg")], check=True)
    os.remove(tmp)
    print(nome + ".ogg", "%.1fs" % (len(x) / SR))


def gota(dur=0.05):
    n = int(SR * dur)
    x = np.arange(n) / SR
    f = RNG.uniform(1800, 4200)
    return np.sin(2 * np.pi * f * x * (1 + 2.5 * x)) * np.exp(-x / 0.008)


# chuva em loop: o fim emenda no começo (cross-fade)
dur = 10.0
n = int(SR * dur)
base = filtro(RNG.normal(0, 1, n + SR), 250, 5200) * 0.8 + filtro(RNG.normal(0, 1, n + SR), 60, 400) * 0.6
for _ in range(1600):
    g = gota() * RNG.uniform(0.05, 0.35)
    i = RNG.integers(0, n + SR - len(g))
    base[i:i + len(g)] += g
fade = np.linspace(0, 1, SR)
loop = base[:n].copy()
loop[:SR] = base[:SR] * fade + base[n:n + SR] * (1 - fade)
ogg("chuva", loop, 0.55)

# respingo (tchap na água)
n = int(SR * 0.35)
x = np.arange(n) / SR
r = filtro(RNG.normal(0, 1, n), 600, 7000) * np.exp(-x / 0.06)
for k in range(5):
    g = gota(0.04) * 0.6
    i = int(RNG.uniform(0.0, 0.15) * SR)
    r[i:i + len(g)] += g
wav("respingo", r, 0.8)

# raspada na grama seca
n = int(SR * 0.25)
x = np.arange(n) / SR
gr = filtro(RNG.normal(0, 1, n), 1500, 9000) * np.exp(-x / 0.05) * (1 + 0.5 * np.sin(2 * np.pi * 60 * x))
wav("grama", gr, 0.6)
