"""Heritage Square's music (assets/audio/music/heritage_square.ogg), made from
scratch: python tools/compose_heritage_music.py out.wav, then encode to Ogg
(ffmpeg -i out.wav -c:a libvorbis -q:a 5 heritage_square.ogg).

Soothing and traditional, built like a Nolan cue.

Nepali sarangi carries it, bansuri answers, madal keeps an easy jhyaure
groove; the Nolan side is the slow build and the low warm swell, not
bright rising tones. Folk major pentatonic on D (Sa Re Ga Pa Dha), 84 bpm.

  0:00  tanpura + singing bowl; sarangi alone, free and slow (alaap)
  0:25  madal comes in softly; bansuri plays the tune
  0:57  sarangi takes the second tune, bansuri answers; warm low swell
  1:30  fuller: madal busier, soft dhime, both voices, one distant narsinga
  2:03  settles: sarangi and bansuri together, home on Sa, the bowl
"""
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt
import wave, sys

SR = 44100
LEN = 152.0
N = int(SR * LEN)
rng = np.random.default_rng(11)
L = np.zeros(N); R = np.zeros(N)
SA = 146.83                      # D3
BPM = 84.0
BEAT = 60.0 / BPM
def hz(semis): return SA * 2 ** (semis / 12.0)

def lp(x, cut, order=2): return sosfilt(butter(order, cut / (SR / 2), "low", output="sos"), x)
def hp(x, cut, order=2): return sosfilt(butter(order, cut / (SR / 2), "high", output="sos"), x)
def bp(x, lo, hi, order=2): return sosfilt(butter(order, [lo / (SR / 2), hi / (SR / 2)], "band", output="sos"), x)
def peak(x, f, q=4.0):
    bw = f / q
    return bp(x, max(20, f - bw / 2), f + bw / 2, 2)

def add(sig, start, gain=1.0, pan=0.0):
    i = int(start * SR)
    if i >= N: return
    sig = sig[: N - i]
    L[i:i + len(sig)] += sig * np.cos((pan + 1) * np.pi / 4) * gain
    R[i:i + len(sig)] += sig * np.sin((pan + 1) * np.pi / 4) * gain

def env(n, a, r):
    e = np.ones(n)
    ai = min(int(a * SR), n); e[:ai] = np.linspace(0, 1, ai) ** 1.5
    ri = min(int(r * SR), n); e[n - ri:] *= np.linspace(1, 0, ri) ** 1.5
    return e

def glide_freq(notes, octave_shift, glide):
    """notes: (semitone, seconds); returns per-sample frequency with meend."""
    total = sum(d for _, d in notes)
    n = int(total * SR)
    f = np.zeros(n); pos = 0; prev = hz(notes[0][0] + octave_shift)
    for semis, d in notes:
        m = int(d * SR); target = hz(semis + octave_shift)
        g = min(int(glide * SR), m)
        seg = np.full(m, target)
        # a curved slide, the way a sarangi player leans into a note
        seg[:g] = prev + (target - prev) * (1 - (1 - np.linspace(0, 1, g)) ** 2)
        f[pos:pos + m] = seg[:max(0, n - pos)]; pos += m; prev = target
    return f, total

# ── Tanpura (soft) and singing bowl ──
def tanpura(f, dur=4.5):
    n = int(dur * SR); t = np.arange(n) / SR; s = np.zeros(n)
    for k in range(1, 10):
        bloom = np.exp(-t * (0.5 + 0.08 * k)) * (1 - np.exp(-t * (2 + 0.5 * k)))
        s += np.sin(2 * np.pi * f * k * t) * bloom / k ** 1.2
    return lp(s * np.exp(-t * 0.45), 2500)
pat = [hz(7 - 12), hz(0), hz(0), hz(-12)]
tt, k = 0.0, 0
while tt < 146:
    add(tanpura(pat[k % 4]), tt, 0.045, -0.25 if k % 2 else 0.25)
    tt += 1.3; k += 1

def bowl(f, dur=11.0):
    n = int(dur * SR); t = np.arange(n) / SR; s = np.zeros(n)
    for ratio, amp, dec in [(1, 1.0, 0.22), (2.76, 0.35, 0.4), (5.4, 0.12, 0.7)]:
        s += amp * np.sin(2 * np.pi * f * ratio * t) * (1 + 0.2 * np.sin(2 * np.pi * 0.6 * ratio * t)) * np.exp(-t * dec)
    return lp(s * (1 - np.exp(-t * 60)), 3000)
for at, f, g in [(0.3, 220.0, 0.10), (24.0, 196.0, 0.07), (56.5, 220.0, 0.07), (140.0, 196.0, 0.12)]:
    add(bowl(f), at, g)

# ── Sarangi: bowed, a nasal wooden body, vibrato, meend, sympathetic ring ──
def sarangi(notes, start, gain, octave=0, pan=-0.15):
    f, total = glide_freq(notes, octave, 0.22)
    n = len(f); t = np.arange(n) / SR
    vib = 1 + 0.0045 * np.sin(2 * np.pi * 5.0 * t + 1.3) * np.clip(t * 0.6, 0, 1)
    phase = 2 * np.pi * np.cumsum(f * vib) / SR
    s = np.zeros(n)
    for k in range(1, 14):
        s += np.sin(k * phase) / k ** 1.05
    # body: the skin-covered belly's resonances, nasal but warm
    body = 0.55 * peak(s, 320, 2.5) + 0.8 * peak(s, 780, 3) + 0.45 * peak(s, 1500, 3) + 0.18 * peak(s, 2600, 4)
    bow = lp(rng.standard_normal(n), 1800) * 0.025
    e = env(n, 0.35, 1.0)
    # each note swells with the bow stroke
    p = 0
    for _, d in notes:
        m = int(d * SR); seg = min(m, n - p)
        if seg > 0:
            e[p:p + seg] *= 0.6 + 0.4 * np.sin(np.linspace(0.15, np.pi * 0.85, seg))
        p += m
    out = lp((body + bow) * e, 3800)
    add(out, start, gain, pan)
    # sympathetic strings ring on, tuned to Sa and Pa, behind the bow
    ring = np.zeros(n + int(3 * SR)); rt = np.arange(len(ring)) / SR
    for fr in (hz(0), hz(7), hz(12)):
        ring += np.sin(2 * np.pi * fr * rt) * 0.015
    ring *= np.convolve(np.abs(out), np.ones(2000) / 2000, "same").tolist() + [0] * int(3 * SR) if False else 1
    add(lp(ring * np.exp(-rt * 0.2) * env(len(ring), 1.5, 2.5), 2500), start, gain * 0.5, 0.3)

def beats(phrase):
    return [(s, d * BEAT) for s, d in phrase]

# Alaap: free and slow, alone over the drone.
sarangi([(0, 2.6), (2, 1.2), (4, 2.2), (7, 1.0), (4, 1.4), (2, 1.0), (0, 2.4), (-3, 1.4), (0, 3.6)], 3.0, 0.18, 12)

# ── Bansuri: warm, little breath ──
def bansuri(notes, start, gain, octave=12, pan=0.2):
    f, total = glide_freq(notes, octave, 0.08)
    n = len(f); t = np.arange(n) / SR
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.3 * t) * np.clip(t * 0.7, 0, 1)
    phase = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(phase) + 0.12 * np.sin(2 * phase) + 0.03 * np.sin(3 * phase)
    breath = bp(rng.standard_normal(n), 1000, 2600) * 0.02
    e = env(n, 0.2, 0.9)
    p = 0
    for _, d in notes:
        m = int(d * SR); seg = min(m, n - p)
        if seg > 0:
            e[p:p + seg] *= 0.7 + 0.3 * np.sin(np.linspace(0.1, np.pi * 0.9, seg)) ** 0.6
        p += m
    add(lp((tone + breath) * e, 4200), start, gain, pan)

# The tunes (semitones from Sa; durations in beats). Folk major pentatonic.
TUNE_A = [(7, 1), (9, 0.5), (12, 1.5), (9, 0.5), (7, 0.5), (4, 1), (2, 1), (4, 2),
          (7, 1), (9, 0.5), (12, 1), (14, 1), (12, 0.5), (9, 1), (7, 1), (7, 2)]
TUNE_B = [(12, 1.5), (14, 0.5), (16, 1), (14, 1), (12, 1), (9, 1), (7, 2),
          (9, 1), (12, 1), (9, 0.5), (7, 0.5), (4, 1), (2, 1), (0, 3)]
ANSWER = [(7, 0.5), (9, 0.5), (7, 1), (4, 2), (2, 1), (4, 1), (0, 2)]

A_START = 25.0 + 4 * BEAT
bansuri(beats(TUNE_A), A_START, 0.17)
B_START = 57.0
sarangi(beats(TUNE_B), B_START, 0.16, 12)
bansuri(beats(ANSWER), B_START + 14 * BEAT, 0.11, 12, 0.35)
bansuri(beats(TUNE_A), B_START + 22 * BEAT, 0.14, 12, 0.25)
C_START = 90.0
sarangi(beats(TUNE_A), C_START, 0.15, 12)
bansuri(beats(TUNE_A), C_START, 0.07, 24, 0.3)          # an octave above, softly
sarangi(beats(TUNE_B), C_START + 16 * BEAT, 0.17, 12)
bansuri(beats(ANSWER), C_START + 30 * BEAT, 0.09, 24, 0.3)
END = 123.0
sarangi(beats([(7, 2), (4, 1), (2, 1), (4, 2), (2, 1), (0, 5)]), END, 0.16, 12)
bansuri(beats([(7, 2), (4, 1), (2, 1), (4, 2), (2, 1), (0, 5)]), END + 0.04, 0.08, 12, 0.3)

# ── Madal: an easy jhyaure groove, warm (no bright crack) ──
def madal_tin(soft=1.0):
    n = int(0.28 * SR); t = np.arange(n) / SR
    s = np.sin(2 * np.pi * 360 * t) * np.exp(-t * 26) + 0.25 * lp(rng.standard_normal(n), 1800) * np.exp(-t * 70)
    return lp(s, 2200) * soft
def madal_dhin():
    n = int(0.55 * SR); t = np.arange(n) / SR
    f = 72 + 40 * np.exp(-t * 16)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6.5)
EIGHTH = BEAT / 2
# dhin . tin tin dhin tin . tin, with soft ghost notes
GROOVE = [("dhin", 1.0), ("ghost", 0.4), ("tin", 0.8), ("tin", 0.6), ("dhin", 0.9), ("tin", 0.8), ("ghost", 0.35), ("tin", 0.7)]
def groove(start, end, level):
    tt, k = start, 0
    while tt < end:
        kind, g = GROOVE[k % 8]
        lev = level(tt)
        if kind == "dhin": add(madal_dhin(), tt, 0.24 * g * lev, -0.1)
        elif kind == "tin": add(madal_tin(), tt, 0.11 * g * lev, 0.2)
        else: add(madal_tin(0.5), tt, 0.08 * g * lev, 0.25)
        tt += EIGHTH; k += 1
groove(25.0, 123.0 + 8 * BEAT, lambda t: np.interp(t, [25, 32, 88, 92, 118, 127], [0.3, 0.75, 0.8, 1.0, 1.0, 0.4]))

# ── Soft dhime under the fullest part ──
def dhime():
    n = int(0.9 * SR); t = np.arange(n) / SR
    f = 58 + 22 * np.exp(-t * 22)
    return lp(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4) + lp(rng.standard_normal(n), 900) * np.exp(-t * 35) * 0.25, 1200)
tt = 90.0
while tt < 122.0:
    add(dhime(), tt, 0.16, 0.0)
    tt += BEAT * 4

# ── The warm low swell (the Nolan side): low strings on Sa and Pa ──
def swell(f, start, dur, gain):
    n = int(dur * SR); t = np.arange(n) / SR
    s = np.zeros(n)
    for det in (-0.12, 0.0, 0.11):
        ph = 2 * np.pi * f * (1 + det / 100) * t
        for k in range(1, 7):
            s += np.sin(k * ph) / k ** 1.4
    e = np.sin(np.linspace(0, np.pi, n)) ** 1.6
    add(lp(s * e, 900), start, gain, 0.0)
for at, semis, dur, g in [(52.0, -12, 14, 0.05), (52.0, -5, 14, 0.035), (86.0, -12, 22, 0.06), (86.0, -5, 22, 0.045), (86.0, 0, 22, 0.03), (104.0, -10, 16, 0.04)]:
    swell(hz(semis), at, dur, g)

# One distant narsinga at the top of the build: dark, far away.
def narsinga(f, dur=4.5):
    n = int(dur * SR); t = np.arange(n) / SR; s = np.zeros(n)
    for k in range(1, 16):
        s += np.sin(2 * np.pi * f * k * t) / k
    s *= 1 + 0.15 * np.sin(2 * np.pi * 24 * t)
    return lp(s, 420) * np.sin(np.linspace(0, np.pi, n)) ** 1.2
add(narsinga(hz(-24)), 104.0, 0.12, -0.2)

# ── Warm hall, gentle top end, master ──
ir_n = int(3.6 * SR); it = np.arange(ir_n) / SR
ir = lp(rng.standard_normal(ir_n), 3500) * np.exp(-it * 1.4)
ir /= np.sqrt(np.sum(ir ** 2))
L = L + fftconvolve(L, ir)[:N] * 0.4
R = R + fftconvolve(R, ir)[:N] * 0.4
tail = np.ones(N); tail[-int(3 * SR):] = np.linspace(1, 0, int(3 * SR)) ** 2
st = np.stack([L * tail, R * tail])
st = hp(st, 35)
st = lp(st, 7000, 1)          # a soft roll-off: nothing sharp up top
st = st / np.max(np.abs(st)) * 0.88
pcm = (st.T * 32767).astype(np.int16)
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("wrote", sys.argv[1])
