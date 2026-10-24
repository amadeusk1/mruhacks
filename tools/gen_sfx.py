#!/usr/bin/env python3
"""Synthesises the minigame sound effects into audio/sfx/*.wav (16-bit mono, 22.05 kHz).
  python3 tools/gen_sfx.py
Chiptune blips for the arcade, soft noise/whoosh for the sled hill. Deterministic (fixed seed)."""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio", "sfx")
rng = random.Random(7)


def env(i, n, a=0.005, r=0.08):
    t, d = i / RATE, n / RATE
    return min(1.0, t / a if a else 1.0) * min(1.0, (d - t) / r if r else 1.0)


def tone(freq_fn, dur, wave_fn="square", vol=0.45, a=0.004, r=0.06, duty=0.5):
    n, out, ph = int(dur * RATE), [], 0.0
    for i in range(n):
        f = freq_fn(i / RATE)
        ph = (ph + f / RATE) % 1.0
        if wave_fn == "square":
            s = 1.0 if ph < duty else -1.0
        elif wave_fn == "tri":
            s = 4 * abs(ph - 0.5) - 1
        else:
            s = math.sin(ph * math.tau)
        out.append(s * vol * env(i, n, a, r))
    return out


def noise(dur, vol=0.4, a=0.01, r=0.2, lp=0.2, sweep=None):
    n, out, y = int(dur * RATE), [], 0.0
    for i in range(n):
        k = sweep(i / dur / RATE) if sweep else lp
        y += (rng.uniform(-1, 1) - y) * k
        out.append(y * vol * env(i, n, a, r))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def seq(*parts):
    return [s for p in parts for s in p]


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


# arcade
save("blip", tone(lambda t: 880, 0.06, duty=0.25, r=0.03))
save("select", tone(lambda t: 660 if t < 0.05 else 990, 0.11, duty=0.25))
save("coin", seq(tone(lambda t: 988, 0.07, duty=0.5, r=0.01), tone(lambda t: 1319, 0.22, duty=0.5, r=0.18)))
save("hit", mix(tone(lambda t: 320 - 900 * t, 0.12, "square", 0.35, duty=0.5), noise(0.08, 0.25, lp=0.5)))
save("paddle", tone(lambda t: 520, 0.05, "tri", 0.6, r=0.04))
save("score", seq(*[tone(lambda t, f=f: f, 0.07, duty=0.25, r=0.02) for f in (523, 659, 784, 1047)]))
save("explode", noise(0.45, 0.55, r=0.4, sweep=lambda u: 0.6 * (1 - u) + 0.03))
save("lose", seq(*[tone(lambda t, f=f: f * (1 - 0.3 * t), 0.16, "square", 0.35, duty=0.5) for f in (392, 330, 262)]))
save("win", seq(*[tone(lambda t, f=f: f, d, duty=0.25, r=0.03) for f, d in ((523, .1), (659, .1), (784, .1), (1047, .32))]))
save("tick", tone(lambda t: 1200, 0.03, duty=0.5, r=0.02, vol=0.3))
save("laser", tone(lambda t: 1500 * math.exp(-14 * t) + 200, 0.13, "square", 0.3, duty=0.3))
save("powerup", tone(lambda t: 300 + 1800 * t, 0.35, "square", 0.3, duty=0.25))
save("gulp", tone(lambda t: 260 + 500 * math.sin(t * 40), 0.12, "sine", 0.6))
save("count", tone(lambda t: 587, 0.14, "square", 0.35, duty=0.5, r=0.06))
save("go", tone(lambda t: 1175, 0.4, "square", 0.35, duty=0.5, r=0.3))
# sled hill
save("whoosh", noise(0.6, 0.6, a=0.15, r=0.4, sweep=lambda u: 0.04 + 0.5 * math.sin(math.pi * u)))
save("boost", mix(noise(0.7, 0.45, a=0.02, r=0.5, sweep=lambda u: 0.5 - 0.4 * u), tone(lambda t: 200 + 900 * t, 0.5, "tri", 0.35)))
save("bump", mix(noise(0.18, 0.6, lp=0.08, r=0.15), tone(lambda t: 120 - 200 * t, 0.15, "sine", 0.6)))
save("crash", noise(0.7, 0.7, a=0.002, r=0.6, sweep=lambda u: 0.35 * (1 - u) + 0.02))
save("checkpoint", seq(tone(lambda t: 784, 0.08, "tri", 0.5, r=0.02), tone(lambda t: 1175, 0.25, "tri", 0.5, r=0.2)))
save("finish", seq(*[tone(lambda t, f=f: f, d, "square", 0.3, duty=0.25, r=0.03) for f, d in ((523, .12), (659, .12), (784, .12), (1047, .12), (784, .1), (1047, .45))]))
save("jump", tone(lambda t: 220 + 500 * t, 0.25, "tri", 0.5))
save("land", noise(0.25, 0.6, lp=0.06, r=0.2))
loop = noise(2.0, 0.5, a=0, r=0, lp=0.05)  # sled hiss loop: looped in-engine
save("slide_loop", [s * (0.8 + 0.2 * math.sin(i / RATE * 9)) for i, s in enumerate(loop)])
print("SFX written to", OUT)
