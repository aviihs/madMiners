"""Generates Mad Miners' original sound effects and music loop.

Pure standard library (no samples, no licences): every sound is synthesised
from sine/square waves and filtered noise. Run from the repo root:

    python3 tool/gen_audio.py
"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'audio')
rnd = random.Random(7)


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    k = 0.9 / peak if peak > 0.9 else 1.0
    with wave.open(os.path.join(OUT, name), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * k)) * 32767)) for s in samples))


def env(i, n, a=0.005, r=None):
    t = i / SR
    attack = min(1.0, t / a) if a > 0 else 1.0
    rel = (1 - i / n) ** (r or 1.5)
    return attack * rel


def noise_lp(n, cutoff):
    """Low-passed white noise (one-pole); cutoff 0..1."""
    out, y = [], 0.0
    for _ in range(n):
        y += cutoff * (rnd.uniform(-1, 1) - y)
        out.append(y)
    return out


def dig():
    n = int(SR * 0.12)
    nz = noise_lp(n, 0.35)
    return [(0.6 * nz[i] + 0.5 * math.sin(2 * math.pi * (180 - 600 * i / SR) * i / SR)) * env(i, n, 0.002, 3) for i in range(n)]


def rock_break():
    n = int(SR * 0.35)
    nz = noise_lp(n, 0.18)
    crack = noise_lp(n, 0.8)
    return [(nz[i] * env(i, n, 0.003, 2) + 0.4 * crack[i] * env(i, n, 0.001, 8)) for i in range(n)]


def coin():
    n = int(SR * 0.32)
    out = []
    for i in range(n):
        t = i / SR
        f = 988 if t < 0.07 else 1319
        out.append(0.5 * math.sin(2 * math.pi * f * t) * env(i, n, 0.002, 2))
    return out


def gem():
    n = int(SR * 0.6)
    notes = [1047, 1319, 1568, 2093]
    out = []
    for i in range(n):
        t = i / SR
        s = 0
        for k, f in enumerate(notes):
            if t > k * 0.06:
                tt = t - k * 0.06
                s += 0.25 * math.sin(2 * math.pi * f * tt) * math.exp(-tt * 6)
        out.append(s)
    return out


def explosion(length=1.1, cutoff=0.06):
    n = int(SR * length)
    nz = noise_lp(n, cutoff)
    rumble = noise_lp(n, 0.015)
    return [(1.2 * nz[i] * env(i, n, 0.004, 2.5) + 2.5 * rumble[i] * env(i, n, 0.01, 1.5)
             + 0.6 * math.sin(2 * math.pi * (70 - 30 * i / n) * i / SR) * env(i, n, 0.002, 3)) for i in range(n)]


def jump():
    n = int(SR * 0.16)
    out, ph = [], 0
    for i in range(n):
        f = 280 + 900 * i / n
        ph += 2 * math.pi * f / SR
        out.append(0.35 * (1 if math.sin(ph) > 0 else -1) * env(i, n, 0.002, 2) * 0.6)
    return out


def land():
    n = int(SR * 0.14)
    nz = noise_lp(n, 0.12)
    return [(nz[i] * 1.5 + 0.5 * math.sin(2 * math.pi * 90 * i / SR)) * env(i, n, 0.001, 3) for i in range(n)]


def jet():
    # Seamless 0.5 s loop of rushing air.
    n = int(SR * 0.5)
    nz = noise_lp(n, 0.25)
    fade = int(SR * 0.05)
    out = []
    for i in range(n):
        s = nz[i] * (0.8 + 0.2 * math.sin(2 * math.pi * 30 * i / SR))
        out.append(s)
    for i in range(fade):  # crossfade ends so it loops without a click
        a = i / fade
        out[i] = out[i] * a + out[n - fade + i] * (1 - a)
    return out[: n - fade]


def hurt():
    n = int(SR * 0.22)
    out, ph = [], 0
    for i in range(n):
        f = 420 - 260 * i / n
        ph += 2 * math.pi * f / SR
        out.append(0.45 * (1 if math.sin(ph) > 0 else -1) * env(i, n, 0.002, 1.5))
    return out


def lava():
    n = int(SR * 0.7)
    nz = noise_lp(n, 0.05)
    out = []
    for i in range(n):
        t = i / SR
        bub = sum(math.sin(2 * math.pi * (150 + 80 * k) * t) * math.exp(-((t - 0.12 - 0.17 * k) * 30) ** 2) for k in range(3))
        out.append(0.8 * nz[i] * env(i, n, 0.05, 1) + 0.25 * bub)
    return out


def victory():
    notes = [(523, 0.12), (659, 0.12), (784, 0.12), (1047, 0.45)]
    out = []
    for f, d in notes:
        n = int(SR * d)
        for i in range(n):
            t = i / SR
            out.append(0.35 * (math.sin(2 * math.pi * f * t) + 0.4 * math.sin(4 * math.pi * f * t)) * env(i, n, 0.004, 1.2))
    return out


def defeat():
    notes = [(392, 0.18), (330, 0.18), (262, 0.5)]
    out = []
    for f, d in notes:
        n = int(SR * d)
        for i in range(n):
            t = i / SR
            out.append(0.35 * math.sin(2 * math.pi * f * t) * env(i, n, 0.004, 1.2))
    return out


def music():
    """16-bar underground groove: bass line, plucked arpeggio, soft drums."""
    bpm = 104
    beat = 60 / bpm
    bars = 8
    n = int(SR * beat * 4 * bars)
    out = [0.0] * n
    # A minor - F - C - G
    chords = [(220, 261.6, 329.6), (174.6, 220, 261.6), (130.8, 164.8, 196), (196, 246.9, 293.7)]

    def add(start, dur, fn):
        s0 = int(start * SR)
        m = int(dur * SR)
        for i in range(m):
            if s0 + i < n:
                out[s0 + i] += fn(i, m)

    for bar in range(bars):
        root, third, fifth = chords[bar % 4]
        t0 = bar * 4 * beat
        for b8 in range(8):
            f = root / 2 if b8 % 2 == 0 else root / 2 * 1.5
            add(t0 + b8 * beat / 2, beat / 2, lambda i, m, f=f: 0.32 * math.sin(2 * math.pi * f * i / SR) * env(i, m, 0.005, 1.2))
        arp = [root * 2, third * 2, fifth * 2, third * 2]
        for k in range(8):
            f = arp[k % 4]
            add(t0 + k * beat / 2, beat / 2, lambda i, m, f=f: 0.10 * (1 if math.sin(2 * math.pi * f * i / SR) > 0 else -1) * math.exp(-i / SR * 9))
        for b in range(4):
            add(t0 + b * beat, 0.15, lambda i, m: 0.5 * math.sin(2 * math.pi * (110 - 400 * i / SR) * i / SR) * env(i, m, 0.001, 4) if b % 2 == 0 else 0)
            hh = noise_lp(int(0.05 * SR), 0.9)
            add(t0 + b * beat + beat / 2, 0.05, lambda i, m, hh=hh: 0.07 * hh[i] * env(i, m, 0.001, 3))
    return out


SFX = {
    'dig.wav': dig, 'break.wav': rock_break, 'coin.wav': coin, 'gem.wav': gem,
    'explosion.wav': explosion, 'small_blast.wav': lambda: explosion(0.6, 0.12),
    'jump.wav': jump, 'land.wav': land, 'jet.wav': jet, 'hurt.wav': hurt, 'lava.wav': lava,
    'victory.wav': victory, 'defeat.wav': defeat, 'music.wav': music,
}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SFX.items():
        write(name, fn())
        print('wrote', name)
