"""Dashain Ground's music (assets/audio/music/dashain_ground.ogg), made from
scratch: python tools/compose_dashain_music.py out.wav, then encode to Ogg
(ffmpeg -i out.wav -c:a libvorbis -q:a 5 dashain_ground.ogg).

A fight theme in the spirit of Kung Fu Hustle's score, played on Nepali
instruments: the sarangi races through fast runs over a quick madal, the
music stops dead and a jhyali crash with a dhime "dhung" lands the joke,
a bouncy bansuri tune, then a moment of slow beauty before the last chase.
Dark pentatonic on D (Sa Re ga Pa ni), 150 bpm. Warm, nothing harsh up top.

  0:00  mock-epic opening: slow sarangi over big dhime hits
  0:10  the chase: fast madal, sarangi runs, comic stops
  0:36  the bansuri's bouncy tune over the groove
  1:00  stop, sting, the chase again with both voices
  1:22  a slow, lyrical sarangi moment over the drone
  1:42  the last chase, dhime rolls, the big sting
"""
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt
import wave, sys

SR = 44100
BPM = 150.0
BEAT = 60.0 / BPM
S16 = BEAT / 4
LEN = 124.0
N = int(SR * LEN)
rng = np.random.default_rng(23)
L = np.zeros(N); R = np.zeros(N)
SA = 146.83
SCALE = [0, 2, 3, 7, 10]
def deg(d):
    """Scale degree (0 = Sa, 5 = Sa an octave up) to semitones."""
    return (d // 5) * 12 + SCALE[d % 5]
def hz(semis): return SA * 2 ** (semis / 12.0)

def lp(x, cut, order=2): return sosfilt(butter(order, cut / (SR / 2), "low", output="sos"), x)
def hp(x, cut, order=2): return sosfilt(butter(order, cut / (SR / 2), "high", output="sos"), x)
def bp(x, lo, hi, order=2): return sosfilt(butter(order, [lo / (SR / 2), hi / (SR / 2)], "band", output="sos"), x)
def peak(x, f, q=3.0):
    bw = f / q
    return bp(x, max(20, f - bw / 2), f + bw / 2, 2)

def add(sig, start, gain=1.0, pan=0.0):
    i = int(start * SR)
    if i >= N or i < 0: return
    sig = sig[: N - i]
    L[i:i + len(sig)] += sig * np.cos((pan + 1) * np.pi / 4) * gain
    R[i:i + len(sig)] += sig * np.sin((pan + 1) * np.pi / 4) * gain

def env(n, a, r):
    e = np.ones(n)
    ai = min(int(a * SR), n); e[:ai] = np.linspace(0, 1, ai) ** 1.5
    ri = min(int(r * SR), n); e[n - ri:] *= np.linspace(1, 0, ri) ** 1.5
    return e

def freq_line(notes, glide):
    total = sum(d for _, d in notes)
    n = int(total * SR); f = np.zeros(n); pos = 0; prev = hz(notes[0][0])
    for semis, d in notes:
        m = int(d * SR); target = hz(semis); g = min(int(glide * SR), m)
        seg = np.full(m, target)
        seg[:g] = prev + (target - prev) * (1 - (1 - np.linspace(0, 1, g)) ** 2)
        f[pos:pos + m] = seg[:max(0, n - pos)]; pos += m; prev = target
    return f

# ── Instruments ──
def sarangi(notes, start, gain, glide=0.05, vib=0.004, pan=-0.15):
    """notes: (semitones above Sa, seconds)."""
    f = freq_line(notes, glide); n = len(f); t = np.arange(n) / SR
    v = 1 + vib * np.sin(2 * np.pi * 5.2 * t + 0.7) * np.clip(t * 2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * v) / SR
    s = sum(np.sin(k * ph) / k ** 1.05 for k in range(1, 13))
    body = 0.55 * peak(s, 320, 2.5) + 0.8 * peak(s, 780, 3) + 0.45 * peak(s, 1500, 3) + 0.15 * peak(s, 2600, 4)
    e = env(n, 0.03 if glide < 0.1 else 0.3, 0.25)
    p = 0
    for _, d in notes:            # each bow stroke leans in
        m = int(d * SR); seg = min(m, n - p)
        if seg > 0: e[p:p + seg] *= 0.65 + 0.35 * np.sin(np.linspace(0.2, np.pi * 0.8, seg))
        p += m
    add(lp((body + lp(rng.standard_normal(n), 1800) * 0.02) * e, 3800), start, gain, pan)

def bansuri(notes, start, gain, pan=0.25):
    f = freq_line(notes, 0.03); n = len(f); t = np.arange(n) / SR
    v = 1 + 0.005 * np.sin(2 * np.pi * 5.6 * t)
    ph = 2 * np.pi * np.cumsum(f * v) / SR
    tone = np.sin(ph) + 0.12 * np.sin(2 * ph) + 0.03 * np.sin(3 * ph)
    e = env(n, 0.02, 0.15); p = 0
    for _, d in notes:            # tongued, bouncy
        m = int(d * SR); seg = min(m, n - p)
        if seg > 0: e[p:p + seg] *= np.clip(np.linspace(1.0, 0.55, seg), 0, 1)
        p += m
    breath = bp(rng.standard_normal(n), 1000, 2600) * 0.02
    add(lp((tone + breath) * e, 4200), start, gain, pan)

def madal_dhin():
    n = int(0.45 * SR); t = np.arange(n) / SR; f = 74 + 44 * np.exp(-t * 18)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)
def madal_tin(level=1.0):
    n = int(0.22 * SR); t = np.arange(n) / SR
    s = np.sin(2 * np.pi * 365 * t) * np.exp(-t * 30) + 0.25 * lp(rng.standard_normal(n), 1800) * np.exp(-t * 80)
    return lp(s, 2300) * level
def dhime(big=1.0):
    n = int(1.1 * SR); t = np.arange(n) / SR; f = 56 + 30 * np.exp(-t * 20)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 3.5)
    return lp(body + lp(rng.standard_normal(n), 1000) * np.exp(-t * 30) * 0.3, 1400) * big
def jhyali(open_=True):
    """Two brass cymbals clashed: inharmonic ring, warm (no fizz above 7 kHz)."""
    n = int((1.4 if open_ else 0.25) * SR); t = np.arange(n) / SR
    ring = sum(np.sign(np.sin(2 * np.pi * fr * t)) * a for fr, a in [(538, 1), (811, 0.8), (1263, 0.6), (1997, 0.4)])
    s = bp(ring, 1500, 4800) * 0.12 + bp(rng.standard_normal(n), 2500, 5500) * 0.35
    return lp(s * np.exp(-t * (2.2 if open_ else 18)), 5200)
def tanpura_bed(start, dur, gain):
    n = int(dur * SR); t = np.arange(n) / SR; s = np.zeros(n)
    for semis, a in [(-12, 0.5), (-5, 0.35), (0, 0.25)]:
        ph = 2 * np.pi * hz(semis) * t
        s += a * sum(np.sin(k * ph) / k ** 1.3 for k in range(1, 9))
    add(lp(s * env(n, 2.0, 2.0) * (1 + 0.15 * np.sin(2 * np.pi * 0.4 * t)), 1200), start, gain)

# ── The score, bar by bar ──
BAR = BEAT * 4
def at(bar, beat=0.0): return bar * BAR + beat * BEAT

# Opening (bars 0-5): slow, mock-epic.
tanpura_bed(0.0, at(6) + 1.0, 0.06)
for b in range(6):
    add(dhime(1.0), at(b), 0.42)
    if b % 2 == 1: add(dhime(0.7), at(b, 2.5), 0.3)
add(jhyali(), at(5, 3), 0.18, 0.2)
sarangi([(deg(5), BEAT * 3), (deg(4), BEAT), (deg(3), BEAT * 2), (deg(2), BEAT * 2), (deg(3), BEAT * 3), (deg(1), BEAT), (deg(0), BEAT * 4),
         (deg(2), BEAT * 2), (deg(3), BEAT * 2), (deg(4), BEAT * 4)], at(0, 0.5), 0.17, glide=0.25, vib=0.006)

# Drum groove helpers: a quick madal and dhime under the chase; "stop"
# bars cut to silence, then the sting lands.
def chase_bar(b, busy=1.0, dhime_on=True):
    for s in range(16):
        tt = at(b) + s * S16
        if s in (0, 6, 10): add(madal_dhin(), tt, 0.32 * busy, -0.1)
        if s in (2, 4, 7, 8, 12, 14, 15): add(madal_tin(), tt, 0.13 * busy, 0.2)
        if s in (3, 11) and busy > 0.9: add(madal_tin(0.6), tt, 0.10, 0.25)
    if dhime_on:
        add(dhime(0.8), at(b), 0.30)
        add(dhime(0.6), at(b, 2), 0.22)
    add(jhyali(False), at(b, 1), 0.06 * busy, 0.3)
    add(jhyali(False), at(b, 3), 0.06 * busy, 0.3)
def sting(b):
    """Silence for two beats, then crash + dhung, a beat of air."""
    add(jhyali(True), at(b, 2), 0.30, 0.15)
    add(dhime(1.2), at(b, 2), 0.55)
    add(madal_dhin(), at(b, 3), 0.35)
def roll(b, beats=4):
    for k in range(int(beats * 4)):
        add(dhime(0.5 + 0.03 * k), at(b) + k * S16, 0.10 + 0.012 * k, -0.3 if k % 2 else 0.3)

def run(start_deg, length, up=True, step=1):
    """A sarangi run of sixteenths through the scale."""
    out = []; d = start_deg
    for _ in range(length):
        out.append((deg(d), S16)); d += step if up else -step
    return out
def zigzag(start_deg, groups):
    out = []; d = start_deg
    for g in range(groups):
        for k in (0, 1, 2, 1):
            out.append((deg(d + k), S16))
        d += 1
    return out

# The chase (bars 6-15) with comic stops at bars 9 and 13.
for b in range(6, 16):
    if b in (9, 13): sting(b); continue
    chase_bar(b, 1.0)
CH1 = run(5, 8) + run(12, 8, up=False) + zigzag(5, 4) + run(10, 8, up=False) + [(deg(5), BEAT * 2), (deg(4), BEAT), (deg(3), BEAT)]
sarangi(CH1, at(6), 0.16)
sarangi(zigzag(3, 8) + run(11, 8, up=False) + [(deg(5), BEAT * 2)], at(10), 0.16)
sarangi([(deg(7), BEAT), (deg(8), BEAT), (deg(10), BEAT * 2)] + run(10, 8, up=False) + zigzag(4, 4) + [(deg(5), BEAT * 2)], at(14) - BEAT * 0, 0.16)

# The bansuri's bouncy tune (bars 16-23) over a lighter groove.
for b in range(16, 24):
    chase_bar(b, 0.8, dhime_on=(b % 2 == 0))
TUNE = [(deg(5), BEAT / 2), (deg(5), BEAT / 2), (deg(7), BEAT), (deg(6), BEAT / 2), (deg(5), BEAT / 2), (deg(4), BEAT),
        (deg(3), BEAT / 2), (deg(4), BEAT / 2), (deg(5), BEAT), (deg(3), BEAT), (deg(2), BEAT * 2)]
tune_len = sum(d for _, d in TUNE)
for k, b in enumerate((16, 18, 20, 22)):
    shift = 0 if k < 2 else 1
    bansuri([(s + (deg(shift) if shift else 0), d) for s, d in TUNE], at(b), 0.16)
sarangi(run(0, 8) + [(deg(4), BEAT * 2)], at(19, 2), 0.09, pan=-0.35)   # answers
sarangi(run(2, 8) + [(deg(5), BEAT * 2)], at(23, 0), 0.10, pan=-0.35)

# Stop, sting, and the chase with both voices (bars 24-32).
sting(24)
for b in range(25, 33):
    if b == 29: sting(b); continue
    chase_bar(b, 1.1)
sarangi(CH1, at(25), 0.15)
bansuri([(s + 12, d) for s, d in CH1[:16]] + [(deg(10), BEAT * 2)], at(25), 0.08, 0.35)
sarangi(zigzag(5, 8) + run(12, 8, up=False), at(30), 0.16)
roll(32, 4)

# The slow, lyrical moment (bars 33-40): drone and sarangi only.
tanpura_bed(at(33), at(41) - at(33) + 1.5, 0.07)
add(jhyali(True), at(33), 0.10)
LYRIC = [(deg(5), BEAT * 3), (deg(6), BEAT), (deg(7), BEAT * 2), (deg(6), BEAT), (deg(5), BEAT), (deg(4), BEAT * 4),
         (deg(3), BEAT * 2), (deg(4), BEAT), (deg(3), BEAT), (deg(2), BEAT * 2), (deg(1), BEAT * 2), (deg(0), BEAT * 6)]
sarangi(LYRIC, at(33, 1), 0.17, glide=0.28, vib=0.007)
bansuri([(s + 12, d) for s, d in [(deg(5), BEAT * 4), (deg(4), BEAT * 4), (deg(3), BEAT * 8)]], at(37), 0.06, 0.35)

# The last chase and the big sting (bars 41-49), then air back to the top.
roll(40, 4)
for b in range(41, 49):
    chase_bar(b, 1.2)
sarangi(CH1, at(41), 0.16)
bansuri([(s + 12, d) for s, d in CH1], at(41), 0.08, 0.35)
sarangi(zigzag(5, 8) + run(12, 10, up=False) + [(deg(0), BEAT * 2)], at(45), 0.17)
roll(48, 2)
add(jhyali(True), at(49), 0.36, 0.1)
add(dhime(1.4), at(49), 0.6)
add(madal_dhin(), at(49, 0.5), 0.3)
sarangi([(deg(0), BEAT * 3)], at(49), 0.14, glide=0.02)

# ── Hall, warm top, master ──
ir_n = int(2.6 * SR); it = np.arange(ir_n) / SR
ir = lp(rng.standard_normal(ir_n), 4000) * np.exp(-it * 2.0)
ir /= np.sqrt(np.sum(ir ** 2))
L = L + fftconvolve(L, ir)[:N] * 0.28
R = R + fftconvolve(R, ir)[:N] * 0.28
end = min(N, int((at(49) + 4.0) * SR))
st = np.stack([L[:end], R[:end]])
st[:, -int(1.5 * SR):] *= np.linspace(1, 0, int(1.5 * SR)) ** 2
st = hp(st, 35)
st = lp(st, 8000, 1)
st = st / np.max(np.abs(st)) * 0.88
pcm = (st.T * 32767).astype(np.int16)
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("wrote", sys.argv[1], "%.1f s" % (end / SR))
