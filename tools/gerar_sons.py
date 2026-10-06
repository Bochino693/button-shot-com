"""Sintetiza os sons do Craque de Botao (nada gravado, nada de terceiros).

    python3 tools/gerar_sons.py

Efeitos em WAV 22 kHz mono (leves e sem atraso no Android) e a batucada da
abertura/menus e a torcida ambiente em OGG (loop).
"""
import os
import subprocess
import wave

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SONS = os.path.join(RAIZ, "sons")
MUS = os.path.join(RAIZ, "musicas")
os.makedirs(SONS, exist_ok=True)
os.makedirs(MUS, exist_ok=True)
SR = 22050
RNG = np.random.default_rng(5)


def t(seg):
    return np.arange(int(SR * seg)) / SR


def env(n, ataque=0.002, queda=0.1):
    x = np.arange(n) / SR
    a = np.clip(x / max(ataque, 1e-4), 0, 1)
    return a * np.exp(-x / max(queda, 1e-4))


def ruido(n):
    return RNG.uniform(-1, 1, n)


def passa_banda(x, f0, f1):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    X[(fr < f0) | (fr > f1)] = 0
    return np.fft.irfft(X, len(x))


def normal(x, pico=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * pico


def salvar_wav(nome, x, pico=0.9):
    x = normal(x, pico)
    dados = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(SONS, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print(nome, "%.2fs" % (len(x) / SR))


def salvar_ogg(nome, x, pico=0.85, pasta=MUS):
    x = normal(x, pico)
    tmp = os.path.join(pasta, nome + "_tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(pasta, nome + ".ogg")], check=True)
    os.remove(tmp)
    print(nome + ".ogg", "%.1fs" % (len(x) / SR))


# ---------------------------------------------------------------- toques
def toque(freq, dur=0.09, brilho=1.0):
    n = int(SR * dur)
    x = t(dur)
    corpo = np.sin(2 * np.pi * freq * x) * env(n, 0.0005, dur * 0.25)
    corpo += 0.5 * np.sin(2 * np.pi * freq * 2.7 * x) * env(n, 0.0005, dur * 0.12)
    clique = passa_banda(ruido(n), 1500, 9000) * env(n, 0.0002, 0.004) * brilho
    return corpo + clique * 1.4


salvar_wav("peteleco", toque(1650, 0.08, 1.2) + 0.4 * toque(900, 0.08, 0.3))      # dedo no botao
salvar_wav("batida", toque(1250, 0.1, 1.0))                                        # botao x botao
salvar_wav("bola", toque(700, 0.12, 0.6) + 0.5 * passa_banda(ruido(int(SR * 0.12)), 200, 1200) * env(int(SR * 0.12), 0.001, 0.02))
salvar_wav("placa", passa_banda(ruido(int(SR * 0.2)), 150, 1500) * env(int(SR * 0.2), 0.001, 0.05) + 0.6 * toque(260, 0.2, 0.2))

# trave: metal com parciais inarmonicas
x = t(1.2)
n = len(x)
trave = sum(a * np.sin(2 * np.pi * f * x) * np.exp(-x / d) for f, a, d in
            [(520, 1.0, 0.5), (1340, 0.6, 0.35), (2410, 0.4, 0.2), (3620, 0.25, 0.12)])
trave += passa_banda(ruido(n), 2000, 8000) * env(n, 0.0002, 0.01)
salvar_wav("trave", trave)

# rede balancando
x = t(0.45)
salvar_wav("rede", passa_banda(ruido(len(x)), 400, 4000) * env(len(x), 0.02, 0.15) * (1 + 0.5 * np.sin(2 * np.pi * 18 * x)))


# ---------------------------------------------------------------- apitos
def apito(dur, trinado=28.0):
    x = t(dur)
    n = len(x)
    freq = 2850 + 60 * np.sin(2 * np.pi * trinado * x)
    fase = 2 * np.pi * np.cumsum(freq) / SR
    tom = np.sin(fase) * (0.75 + 0.25 * np.sin(2 * np.pi * trinado * x))
    sopro = passa_banda(ruido(n), 2400, 3400) * 0.25
    en = np.clip(x / 0.015, 0, 1) * np.clip((dur - x) / 0.04, 0, 1)
    return (tom + sopro) * en


salvar_wav("apito", apito(0.32), 0.7)
salvar_wav("apito_longo", apito(1.1), 0.7)
pausa = np.zeros(int(SR * 0.16))
salvar_wav("apito_fim", np.concatenate([apito(0.3), pausa, apito(0.3), pausa, apito(1.0)]), 0.7)
salvar_wav("apito_falta", np.concatenate([apito(0.18), np.zeros(int(SR * 0.08)), apito(0.45)]), 0.7)


# ---------------------------------------------------------------- torcida
def multidao(dur, intensidade=1.0, grito=0.0, vogal=(700, 1150)):
    """Muita gente falando ao mesmo tempo + opcional grito (vogal)."""
    n = int(SR * dur)
    x = t(dur)
    base = passa_banda(ruido(n), 250, 2600)
    # 'vozes': ruido modulado por varias ondas lentas
    mod = np.zeros(n)
    for _ in range(14):
        f = RNG.uniform(0.6, 4.0)
        mod += np.abs(np.sin(2 * np.pi * f * x + RNG.uniform(0, 6.28)))
    mod /= 14
    som = base * (0.55 + 0.6 * mod) * intensidade
    if grito > 0:
        # formantes de uma vogal cantada por muitos (Eeee / Uuuu)
        g = np.zeros(n)
        for f in vogal:
            g += passa_banda(ruido(n), f * 0.85, f * 1.15)
        som += g * grito
    return som


x = multidao(12.0, 1.0)
# loop sem emenda: cruza o fim com o comeco
cruz = int(SR * 1.0)
x[:cruz] = x[:cruz] * np.linspace(0, 1, cruz) + x[-cruz:] * np.linspace(1, 0, cruz)
x = x[:-cruz]
salvar_ogg("torcida", x, 0.5, SONS)

# GOOOL: rugido que cresce e fica
dur = 5.5
x = t(dur)
rug = multidao(dur, 1.0, grito=1.6, vogal=(600, 1050, 2500))
en = np.clip(x / 0.35, 0, 1) ** 1.5 * np.clip((dur - x) / 1.6, 0, 1)
salvar_wav("torcida_gol", rug * (0.5 + 0.8 * en))

# UUUH (quase gol)
dur = 1.8
x = t(dur)
uh = multidao(dur, 0.7, grito=2.0, vogal=(320, 800))
en = np.sin(np.pi * np.clip(x / dur, 0, 1)) ** 1.2
salvar_wav("torcida_uh", uh * en)

# vaia curta (falta / cartao)
dur = 1.6
x = t(dur)
vaia = multidao(dur, 0.5, grito=1.8, vogal=(280, 620))
salvar_wav("torcida_vaia", vaia * np.sin(np.pi * x / dur))


# ---------------------------------------------------------------- interface
def bip(f, dur=0.07):
    x = t(dur)
    return np.sin(2 * np.pi * f * x) * env(len(x), 0.002, dur * 0.4)


def junta(a, b):
    n = max(len(a), len(b))
    return np.pad(a, (0, n - len(a))) + np.pad(b, (0, n - len(b)))


salvar_wav("clique", junta(bip(1300, 0.05), 0.5 * bip(2600, 0.04)))
salvar_wav("confirma", np.concatenate([bip(880, 0.08), bip(1320, 0.14)]))
salvar_wav("volta", np.concatenate([bip(900, 0.07), bip(620, 0.12)]))
x = t(0.5)
salvar_wav("swoosh", passa_banda(ruido(len(x)), 500, 5000) * np.sin(np.pi * x / 0.5) ** 2)
# cartao: acorde de metal curto
x = t(0.9)
salvar_wav("cartao", sum(np.sin(2 * np.pi * f * x) * np.exp(-x / 0.35) for f in (233, 277, 349, 466)) +
           0.3 * passa_banda(ruido(len(x)), 200, 3000) * env(len(x), 0.001, 0.05))
# tambores do penalti (rufar crescendo)
dur = 2.2
x = t(dur)
rufar = np.zeros(len(x))
k = 0.0
while k < dur - 0.05:
    i = int(k * SR)
    m = min(len(x) - i, int(SR * 0.06))
    rufar[i:i + m] += (0.4 + 0.6 * k / dur) * passa_banda(ruido(m), 150, 900) * env(m, 0.001, 0.02)
    k += 0.055 - 0.02 * (k / dur)
salvar_wav("rufar", rufar)
# fogos (estouro)
x = t(1.0)
fogo = passa_banda(ruido(len(x)), 80, 3000) * env(len(x), 0.001, 0.12)
fogo += 0.4 * passa_banda(ruido(len(x)), 3000, 9000) * (RNG.random(len(x)) < 0.004) * np.exp(-x / 0.5)
salvar_wav("fogos", fogo)


# ---------------------------------------------------------------- batucada
def batucada(compassos=8, bpm=104):
    passo = 60.0 / bpm / 4          # semicolcheia
    total = compassos * 16
    n = int(total * passo * SR) + SR
    mix = np.zeros(n)

    def por(amostra, seg, vol=1.0):
        i = int(seg * SR)
        m = min(len(amostra), n - i)
        mix[i:i + m] += amostra[:m] * vol

    def surdo(f=62, dur=0.5):
        x = t(dur)
        fr = f * (1 + 0.6 * np.exp(-x / 0.03))
        return np.sin(2 * np.pi * np.cumsum(fr) / SR) * env(len(x), 0.002, 0.18)

    def caixa(dur=0.12):
        m = int(SR * dur)
        return passa_banda(ruido(m), 900, 7000) * env(m, 0.0005, 0.035)

    def chocalho(dur=0.06):
        m = int(SR * dur)
        return passa_banda(ruido(m), 5000, 10000) * env(m, 0.004, 0.02)

    def tamborim(dur=0.08):
        x = t(dur)
        return (np.sin(2 * np.pi * 820 * x) * 0.6 + passa_banda(ruido(len(x)), 2000, 6000) * 0.6) * env(len(x), 0.0005, 0.02)

    def agogo(f, dur=0.25):
        x = t(dur)
        return (np.sin(2 * np.pi * f * x) + 0.4 * np.sin(2 * np.pi * f * 2.76 * x)) * env(len(x), 0.001, 0.09)

    tam_padrao = [1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0]
    ago = {0: 1100, 3: 1100, 6: 820, 8: 1100, 10: 820, 12: 820, 14: 1100}
    for k in range(total):
        seg = k * passo
        b = k % 16
        # surdos: resposta no 2o e 4o tempo (marcacao)
        if b in (4, 12):
            por(surdo(60), seg, 1.0)
        if b in (0, 8):
            por(surdo(78, 0.3), seg, 0.55)
        if b in (7, 15) and (k // 16) % 2 == 1:
            por(surdo(95, 0.2), seg, 0.35)
        por(chocalho(), seg, 0.22 + (0.12 if b % 4 == 0 else 0.0))
        if tam_padrao[b]:
            por(tamborim(), seg, 0.35)
        if b in ago and (k // 16) % 2 == 0:
            por(agogo(ago[b]), seg, 0.22)
        if b in (2, 6, 10, 14):
            por(caixa(), seg, 0.30)
        # virada no ultimo compasso
        if k >= total - 8 and b % 2 == 0:
            por(caixa(), seg, 0.45)
    # 'loop' exato
    return mix[:int(total * passo * SR)]


salvar_ogg("batucada", batucada(), 0.85)



# =====================================================================
# VERSAO 2: sons mais ricos (regravam os de cima com o mesmo nome)
# =====================================================================
from scipy.signal import lfilter


def por_em(dst, v, i):
    """Soma v em dst a partir de i, cortando o que passar do fim."""
    if i >= len(dst):
        return
    m = min(len(v), len(dst) - i)
    dst[i:i + m] += v[:m]


def ressoador(x, f, largura):
    """Filtro passa-banda ressonante (formante da voz, corpo do botao)."""
    r = np.exp(-np.pi * largura / SR)
    th = 2 * np.pi * f / SR
    a = [1.0, -2 * r * np.cos(th), r * r]
    b = [1 - r]
    return lfilter(b, a, x)


VOGAIS = {"a": (800, 1200, 2500), "e": (500, 1800, 2500), "o": (500, 850, 2400), "u": (330, 800, 2300), "eh": (650, 1650, 2500)}


def voz(dur, f0, vogal="a", vib=5.0, forca=1.0):
    """Uma voz: pulsos da garganta + formantes da vogal."""
    x = t(dur)
    n = len(x)
    f = f0 * (1 + 0.012 * np.sin(2 * np.pi * vib * x + RNG.uniform(0, 6)) + 0.01 * RNG.standard_normal(n).cumsum() / np.sqrt(n))
    fase = np.cumsum(f) / SR
    pulso = (fase % 1.0) * 2 - 1           # dente de serra (garganta)
    pulso += 0.15 * RNG.uniform(-1, 1, n)  # ar
    out = np.zeros(n)
    for k, fr in enumerate(VOGAIS[vogal]):
        out += ressoador(pulso, fr * RNG.uniform(0.95, 1.05), 90 + 40 * k) * (1.0, 0.6, 0.25)[k]
    return out * forca


def multidao2(dur, vozes=46, excitacao=0.4, vogais=("a", "e", "o", "eh"), grito=False):
    """Estadio: muitas vozes falando/gritando em silabas, mais o 'mar' de fundo."""
    n = int(SR * dur)
    mix = np.zeros(n)
    for _ in range(vozes):
        f0 = RNG.uniform(95, 150) if RNG.random() < 0.7 else RNG.uniform(180, 280)
        ini = RNG.uniform(0, dur * 0.9)
        dd = RNG.uniform(0.25, 1.4) if not grito else RNG.uniform(1.0, dur)
        dd = min(dd, dur - ini)
        if dd < 0.1:
            continue
        v = voz(dd, f0 * (1.25 if grito else 1.0), vogais[RNG.integers(0, len(vogais))])
        m = len(v)
        # silabas: envelope que abre e fecha
        xs = np.arange(m) / SR
        sil = np.clip(np.sin(np.pi * xs / dd), 0, 1) ** 0.5
        if not grito:
            sil *= 0.5 + 0.5 * np.abs(np.sin(2 * np.pi * RNG.uniform(2.5, 5.5) * xs))
        i = int(ini * SR)
        por_em(mix, v * sil * RNG.uniform(0.3, 1.0), i)
    mar = passa_banda(ruido(n), 250, 3000) * (0.6 + 0.4 * excitacao)
    return mix / max(1.0, np.max(np.abs(mix)) + 1e-9) * (0.7 + excitacao) + mar * 0.35


def palmas(n_palmas, intervalo):
    dur = n_palmas * intervalo + 0.3
    out = np.zeros(int(SR * dur))
    for k in range(n_palmas):
        for _ in range(25):   # muita gente batendo junto (quase junto)
            m = int(SR * 0.05)
            i = int((k * intervalo + RNG.normal(0, 0.012)) * SR)
            if 0 <= i < len(out) - m:
                out[i:i + m] += passa_banda(ruido(m), 800, 6000) * env(m, 0.0005, 0.012) * RNG.uniform(0.4, 1)
    return out


# torcida ambiente: murmurio + de vez em quando palmas ritmadas e "ô-ô"
dur = 16.0
amb = multidao2(dur, vozes=70, excitacao=0.3)
canto = np.zeros(len(amb))
p_ = palmas(12, 0.42)
por_em(canto, p_ * 0.8, int(SR * 6))
for k, (nota, ini, d) in enumerate([(196, 3.0, 0.5), (220, 3.55, 0.5), (196, 4.1, 0.9), (196, 11.0, 0.5), (247, 11.55, 0.5), (220, 12.1, 0.9)]):
    for _ in range(18):
        v = voz(d, nota * RNG.uniform(0.98, 1.02), "o")
        i = int((ini + RNG.normal(0, 0.02)) * SR)
        por_em(canto, v * np.sin(np.pi * np.arange(len(v)) / len(v)) * 0.08, i)
amb = amb + canto
cruz = int(SR * 1.0)
amb[:cruz] = amb[:cruz] * np.linspace(0, 1, cruz) + amb[-cruz:] * np.linspace(1, 0, cruz)
amb = amb[:-cruz]
# compressao suave: o murmurio fica presente sem os cantos estourarem
amb = np.tanh(amb / (3.0 * np.sqrt(np.mean(amb ** 2))))
salvar_ogg("torcida", amb, 0.6, SONS)

# GOL: a galera explode no "GOOOL" (vozes em 'o' subindo) + buzinas
dur = 5.5
gol = multidao2(dur, vozes=80, excitacao=1.0, vogais=("o", "a"), grito=True)
x = t(dur)
en = np.clip(x / 0.25, 0, 1) * np.clip((dur - x) / 1.8, 0, 1)
gol = gol * (0.4 + 0.8 * en)


def buzina(d, f=370):
    xx_ = t(d)
    s_ = sum(np.sign(np.sin(2 * np.pi * f * m * xx_ * (1 + 0.003 * np.sin(2 * np.pi * 6 * xx_)))) / m for m in (1, 1.26, 1.5))
    s_ = ressoador(s_, 1200, 600) + ressoador(s_, 2500, 800) * 0.5
    return s_ * np.clip(xx_ / 0.03, 0, 1) * np.clip((d - xx_) / 0.1, 0, 1)


bz = buzina(1.2)
por_em(gol, normal(bz, 0.35), int(SR * 0.3))
bz2 = buzina(0.8, 330)
por_em(gol, normal(bz2, 0.3), int(SR * 1.9))
salvar_wav("torcida_gol", gol)
salvar_wav("buzina", buzina(1.0))

# UUUH e vaia com vozes de verdade
dur = 1.9
uh = np.zeros(int(SR * dur))
for _ in range(60):
    f0 = RNG.uniform(100, 180)
    v = voz(dur * RNG.uniform(0.7, 1.0), f0 * np.linspace(1.0, 1.0, 1)[0], "u")
    xs = np.arange(len(v)) / len(v)
    pit = np.sin(np.pi * xs) ** 1.3
    i = int(RNG.uniform(0, 0.15) * SR)
    por_em(uh, v * pit * RNG.uniform(0.4, 1), i)
salvar_wav("torcida_uh", uh + passa_banda(ruido(len(uh)), 200, 1500) * 0.15 * np.sin(np.pi * np.arange(len(uh)) / len(uh)))
dur = 1.7
vaia = np.zeros(int(SR * dur))
for _ in range(50):
    v = voz(dur * RNG.uniform(0.6, 1.0), RNG.uniform(90, 140), "u")
    i = int(RNG.uniform(0, 0.2) * SR)
    por_em(vaia, v * np.sin(np.pi * np.arange(len(v)) / len(v)) * RNG.uniform(0.4, 1), i)
salvar_wav("torcida_vaia", vaia)


# apito de verdade: tom agudo com a "bolinha" batendo (trinado irregular)
def apito2(dur):
    x = t(dur)
    n = len(x)
    trin = 32 + 6 * np.sin(2 * np.pi * 1.3 * x)
    am = 0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(trin) / SR) ** 2
    f = 3150 + 90 * np.sin(2 * np.pi * np.cumsum(trin) / SR)
    tom = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.25 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    sopro = ressoador(ruido(n), 3150, 500) * 0.4
    en = np.clip(x / 0.02, 0, 1) * np.clip((dur - x) / 0.05, 0, 1)
    return (tom * am + sopro) * en


salvar_wav("apito", apito2(0.34), 0.7)
salvar_wav("apito_longo", apito2(1.2), 0.7)
pausa = np.zeros(int(SR * 0.15))
salvar_wav("apito_fim", np.concatenate([apito2(0.32), pausa, apito2(0.32), pausa, apito2(1.1)]), 0.7)
salvar_wav("apito_falta", np.concatenate([apito2(0.16), np.zeros(int(SR * 0.07)), apito2(0.5)]), 0.7)


# botao de mesa: estalo do plastico com corpo (dois ressoadores)
def estalo(f1, f2, dur=0.11, forca=1.0):
    n = int(SR * dur)
    imp = np.zeros(n)
    imp[0] = 1.0
    imp[1:40] += ruido(39) * 0.3
    corpo = ressoador(imp, f1, 60) + 0.7 * ressoador(imp, f2, 90) + 0.3 * ressoador(imp, f2 * 2.3, 200)
    clique = passa_banda(ruido(n), 3000, 9000) * env(n, 0.0001, 0.003)
    return (corpo * 40 + clique * 0.8) * forca


salvar_wav("peteleco", junta(estalo(1450, 2900), 0.5 * estalo(620, 1300, 0.08)))
salvar_wav("batida", estalo(1150, 2400, 0.12))
salvar_wav("bola", junta(estalo(820, 1750, 0.1), 0.3 * passa_banda(ruido(int(SR * 0.1)), 150, 900) * env(int(SR * 0.1), 0.001, 0.02)))

# efeitos da cena de apresentacao e do embalo
x = t(1.2)
salvar_wav("impacto", ressoador(ruido(len(x)), 70, 40) * env(len(x), 0.001, 0.35) * 3 + passa_banda(ruido(len(x)), 2000, 8000) * env(len(x), 0.001, 0.05))
x = t(0.9)
sub = np.sin(2 * np.pi * np.cumsum(300 + 900 * (x / 0.9) ** 2) / SR) * np.sin(np.pi * x / 0.9)
salvar_wav("embalo", sub * 0.6 + passa_banda(ruido(len(x)), 2000, 7000) * np.sin(np.pi * x / 0.9) ** 3 * 0.5)
x = t(0.6)
salvar_wav("brilho", sum(np.sin(2 * np.pi * f * x) * np.exp(-x / 0.25) for f in (1568, 2093, 2637)) * 0.5)


# ---------------------------------------------------------------- musica
def corda(f, dur, brilho=0.5):
    """Corda dedilhada (Karplus-Strong): violao/cavaquinho/baixo."""
    n = int(SR * dur)
    p_ = max(2, int(SR / f))
    buf = RNG.uniform(-1, 1, p_) * 1.0
    out = np.zeros(n)
    for i in range(n):
        j = i % p_
        out[i] = buf[j]
        buf[j] = (buf[j] + buf[(j + 1) % p_]) * (0.498 + 0.0015 * brilho)
    return out


def nota_hz(nome):
    notas = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    oit = int(nome[-1])
    return 440.0 * 2 ** ((notas[nome[:-1]] - 9) / 12 + (oit - 4))


def samba(compassos=8, bpm=104):
    passo = 60.0 / bpm / 4
    total = compassos * 16
    n = int(total * passo * SR) + SR
    mix = np.zeros(n)
    base_perc = batucada(compassos, bpm)
    mix[:len(base_perc)] += base_perc * 0.8

    def por(a, seg, vol):
        i = int(seg * SR)
        m = min(len(a), n - i)
        mix[i:i + m] += a[:m] * vol

    # progressao de samba: C | A7 | Dm | G7
    acordes = [["C4", "E4", "G4", "C5"], ["A3", "C#4", "G4", "E5"], ["D4", "F4", "A4", "D5"], ["G3", "B3", "F4", "D5"]]
    baixos = ["C2", "A1", "D2", "G1"]
    ritmo_cav = [0, 3, 6, 8, 10, 13]              # batida do cavaquinho (semicolcheias)
    for c in range(compassos):
        ac = acordes[c % 4]
        for b in ritmo_cav:
            seg = (c * 16 + b) * passo
            for k, nm in enumerate(ac):
                por(corda(nota_hz(nm), 0.35, 0.8), seg + k * 0.006, 0.07)
        # baixo: tonica e quinta
        f_b = nota_hz(baixos[c % 4])
        por(corda(f_b, 0.5, 0.2), (c * 16) * passo, 0.55)
        por(corda(f_b * 1.5, 0.4, 0.2), (c * 16 + 8) * passo, 0.45)
        por(corda(f_b, 0.3, 0.2), (c * 16 + 14) * passo, 0.35)
    return mix[:int(total * passo * SR)]


salvar_ogg("batucada", samba(), 0.85)


def tema_copa():
    """Tema elegante da apresentacao: pad de cordas + sino + tambor grave."""
    bpm = 80
    batida = 60.0 / bpm
    dur = batida * 16
    n = int(SR * dur)
    x = np.arange(n) / SR
    mix = np.zeros(n)
    acordes = [["D3", "A3", "D4", "F4"], ["A#2", "F3", "A#3", "D4"], ["F3", "C4", "F4", "A4"], ["C3", "G3", "C4", "E4"]]
    for i, ac in enumerate(acordes):
        ini = i * 4 * batida
        m = int(4 * batida * SR)
        xs = np.arange(m) / SR
        pad = np.zeros(m)
        for nm in ac:
            f = nota_hz(nm)
            for det in (0.997, 1.0, 1.003):
                pad += np.sign(np.sin(2 * np.pi * f * det * xs)) * 0.3 + np.sin(2 * np.pi * f * det * xs)
        pad = ressoador(pad, 900, 900) * 0.2 + pad * 0.02
        en = np.clip(xs / 0.6, 0, 1) * np.clip((4 * batida - xs) / 0.6, 0, 1)
        j = int(ini * SR)
        por_em(mix, pad * en, j)
        # sino na cabeca do compasso
        sino = sum(np.sin(2 * np.pi * nota_hz(ac[-1]) * 2 * h * xs[:int(SR * 2)]) * np.exp(-xs[:int(SR * 2)] / (0.9 / h)) / h for h in (1, 2.4, 3.9))
        por_em(mix, sino * 0.25, j)
    for k in range(16):
        m = int(SR * 0.6)
        tb = np.sin(2 * np.pi * np.cumsum(55 * (1 + 0.8 * np.exp(-np.arange(m) / SR / 0.04))) / SR) * env(m, 0.002, 0.3)
        j = int(k * batida * SR)
        por_em(mix, tb * (0.8 if k % 4 == 0 else 0.35), j)
    return mix


salvar_ogg("tema_copa", tema_copa(), 0.8)
