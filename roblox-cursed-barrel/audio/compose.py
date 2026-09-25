"""Cursed Barrel 배경음악 · 심장 소리 · 잭팟 소리를 코드로 작곡해서 .ogg 로 굽는다.

모든 소리는 이 파일이 직접 합성한다 (샘플 · 남의 음원 없음 → 저작권 걱정 없이 Roblox 에 올릴 수 있다).

    pip install numpy scipy soundfile
    python3 audio/compose.py            # audio/*.ogg 전부
    python3 audio/compose.py match      # 하나만

만들어지는 것 (ReleaseConfig.Audio 의 이름)
    lobby.ogg      Lobby       로비 뱃노래 (6/8 · 라단조 · 아코디언 + 바이올린), 반복
    match.ogg      Match       게임 중 긴장 음악 (100 BPM · 첼로 반복음 + 북 + 시계 소리), 반복
    final.ogg      MatchFinal  결승(마지막 2명) 음악 (124 BPM · 더 빠르고 크게), 반복
    heartbeat.ogg  Heartbeat   "쿵-쿵" 한 번. 게임이 라운드마다 더 빨리 틀어서 박동이 빨라진다
    jackpot.ogg    Jackpot     잭팟 팡파르 (금관 + 동전 반짝임)

반복 음악은 끝의 울림(잔향)을 앞머리에 겹쳐 두어서 이음새 없이 돈다.
"""
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = Path(__file__).resolve().parent
RNG = np.random.default_rng(20260925)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ─────────────────────────────── 기본 파형 ───────────────────────────────

def _blep(t, dt):
    out = np.zeros_like(t)
    a = t < dt
    x = t[a] / dt[a]
    out[a] = x + x - x * x - 1
    b = t > 1 - dt
    x = (t[b] - 1) / dt[b]
    out[b] = x * x + x + x + 1
    return out


def phase_of(freq, n, vibrato=0.0, vib_rate=5.5, vib_delay=0.15, glide=None):
    """주파수(배열 가능) → 누적 위상(바퀴 수)."""
    t = np.arange(n) / SR
    f = np.full(n, float(freq)) if np.isscalar(freq) else freq
    if glide is not None:
        f = f * glide
    if vibrato:
        depth = vibrato * np.clip((t - vib_delay) / 0.35, 0, 1)
        f = f * (1 + depth * np.sin(2 * np.pi * vib_rate * t + RNG.uniform(0, 6.28)))
    return np.cumsum(f) / SR + RNG.uniform(0, 1), f / SR


def saw(freq, n, **kw):
    ph, dt = phase_of(freq, n, **kw)
    t = ph % 1.0
    return (2 * t - 1) - _blep(t, dt)


def square(freq, n, width=0.5, **kw):
    ph, dt = phase_of(freq, n, **kw)
    t1 = ph % 1.0
    t2 = (ph + width) % 1.0
    s1 = (2 * t1 - 1) - _blep(t1, dt)
    s2 = (2 * t2 - 1) - _blep(t2, dt)
    return (s1 - s2) * 0.5


def sine(freq, n, **kw):
    ph, _ = phase_of(freq, n, **kw)
    return np.sin(2 * np.pi * ph)


def noise(n):
    return RNG.standard_normal(n)


def env(n, a=0.01, d=0.1, s=0.7, r=0.2, hold=None):
    """ADSR. hold 초 동안 누르고(없으면 n 에서 r 을 뺀 만큼) 뗀다."""
    t = np.arange(n) / SR
    hold = (n / SR - r) if hold is None else hold
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip((t - hold) / max(r, 1e-4), 0, 1)
    e = e * np.where(t > hold, np.exp(-5 * rel) * (1 - rel), 1)
    return e


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, SR * 0.45) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def peak(x, freq, q, gain_db):
    """피킹 EQ (몸통 울림 · 모음 소리)."""
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * freq / SR
    alpha = np.sin(w) / (2 * q)
    b = [1 + alpha * A, -2 * np.cos(w), 1 - alpha * A]
    a = [1 + alpha / A, -2 * np.cos(w), 1 - alpha / A]
    return signal.lfilter(b, a, x)


# ─────────────────────────────── 악기 ───────────────────────────────

def fiddle(note, dur, vel=1.0):
    n = int((dur + 0.25) * SR)
    f = midi(note)
    x = saw(f, n, vibrato=0.006, vib_rate=5.6, vib_delay=0.12)
    x += 0.35 * saw(f * 1.003, n, vibrato=0.005, vib_rate=5.2)
    x = lowpass(x, 3000, 4)
    x = peak(x, 520, 1.2, 5)  # 나무 몸통
    x = peak(x, 2900, 2.0, 4)
    x += 0.012 * highpass(noise(n), 3000) * np.exp(-np.arange(n) / SR / 0.06)  # 활 긁는 소리
    return x * env(n, 0.035, 0.25, 0.8, 0.22, hold=dur) * 0.30 * vel


def whistle(note, dur, vel=1.0):
    n = int((dur + 0.2) * SR)
    f = midi(note)
    x = sine(f, n, vibrato=0.004, vib_rate=5.0) + 0.12 * sine(2 * f, n)
    x += 0.03 * bandpass(noise(n), f * 0.8, f * 1.6)
    return x * env(n, 0.03, 0.2, 0.85, 0.12, hold=dur) * 0.22 * vel


def accordion(notes, dur, vel=1.0):
    n = int((dur + 0.12) * SR)
    x = np.zeros(n)
    for note in notes:
        f = midi(note)
        # 뮈제트 : 리드 두 개를 살짝 어긋나게
        x += square(f * 0.9965, n, width=0.42) + square(f * 1.0035, n, width=0.42) + 0.5 * saw(f * 2, n)
    x = lowpass(x, 1900, 4)
    x = peak(x, 1100, 1.0, 3)
    return x * env(n, 0.012, 0.09, 0.55, 0.07, hold=dur) * 0.07 * vel


def pluck_bass(note, dur, vel=1.0):
    n = int((dur + 0.4) * SR)
    f = midi(note)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(1, 14):
        x += np.sin(2 * np.pi * f * k * t) / k ** 1.3 * np.exp(-t * (2.2 + 1.6 * k))
    x = lowpass(x, 1400)
    return x * env(n, 0.004, 0.3, 0.6, 0.12, hold=dur) * 0.55 * vel


def cello(note, dur, vel=1.0, bright=1.0):
    """짧게 끊는 첼로 반복음 (긴장 음악의 뼈대)."""
    n = int((dur + 0.18) * SR)
    f = midi(note)
    x = saw(f, n) + 0.6 * saw(f * 1.004, n) + 0.4 * saw(f * 0.997, n)
    t = np.arange(n) / SR
    cut = 500 + 1900 * bright * np.exp(-t / 0.09)  # 활이 닿는 순간 밝게
    # 시간에 따라 바뀌는 저역 필터 : 짧게 쪼개 적용
    y = np.zeros(n)
    step = 512
    zi = None
    for i in range(0, n, step):
        b, a = signal.butter(2, min(cut[i], SR * 0.45) / (SR / 2), "low")
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        y[i:i + step], zi = signal.lfilter(b, a, x[i:i + step], zi=zi)
    y = peak(y, 260, 1.0, 4)
    return y * env(n, 0.006, 0.12, 0.45, 0.1, hold=dur) * 0.2 * vel


def strings_pad(notes, dur, vel=1.0, tremolo=0.0, cutoff=2600):
    n = int((dur + 1.2) * SR)
    x = np.zeros(n)
    for note in notes:
        f = midi(note)
        for d in (-0.009, -0.004, 0.0, 0.004, 0.009):
            x += saw(f * (1 + d), n, vibrato=0.003, vib_rate=4.6 + d * 50, vib_delay=0.3)
    x = lowpass(x, cutoff, 2)
    x = highpass(x, 180)
    if tremolo:
        t = np.arange(n) / SR
        x *= 1 - 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * tremolo * t))
    return x * env(n, 0.45, 0.8, 0.85, 1.0, hold=dur) * 0.035 * vel


def choir(notes, dur, vel=1.0):
    n = int((dur + 1.2) * SR)
    x = np.zeros(n)
    for note in notes:
        f = midi(note)
        for d in (-0.006, 0.0, 0.006):
            x += saw(f * (1 + d), n, vibrato=0.005, vib_rate=5.1, vib_delay=0.4)
    # "아" 모음 (포먼트)
    y = bandpass(x, 600, 850) * 1.0 + bandpass(x, 1050, 1350) * 0.55 + bandpass(x, 2400, 2800) * 0.25
    return y * env(n, 0.6, 1.0, 0.9, 1.1, hold=dur) * 0.06 * vel


def horn(note, dur, vel=1.0):
    n = int((dur + 0.4) * SR)
    f = midi(note)
    t = np.arange(n) / SR
    x = saw(f, n, vibrato=0.002) + saw(f * 1.005, n) + 0.5 * saw(f / 2, n)
    cut = 300 + 1600 * np.clip(t / 0.12, 0, 1) * np.exp(-t / 0.9) + 250
    y = np.zeros(n)
    step = 512
    zi = None
    for i in range(0, n, step):
        b, a = signal.butter(2, min(cut[i], SR * 0.45) / (SR / 2), "low")
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        y[i:i + step], zi = signal.lfilter(b, a, x[i:i + step], zi=zi)
    return y * env(n, 0.04, 0.4, 0.7, 0.3, hold=dur) * 0.16 * vel


def bell(note, dur=2.5, vel=1.0):
    """FM 종 · 첼레스타 (으스스한 오르골)."""
    n = int(dur * SR)
    f = midi(note)
    t = np.arange(n) / SR
    mod = 2.0 * np.exp(-t / 0.4) * np.sin(2 * np.pi * f * 3.5 * t)
    x = np.sin(2 * np.pi * f * t + mod) * np.exp(-t / 0.9)
    x += 0.3 * np.sin(2 * np.pi * f * 2.01 * t) * np.exp(-t / 0.35)
    return x * np.clip(t / 0.003, 0, 1) * 0.12 * vel


def taiko(vel=1.0, pitch=1.0, dur=1.4):
    vel *= 0.75
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 62 * pitch * (1 + 1.6 * np.exp(-t / 0.025))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.38)
    skin = lowpass(noise(n), 900) * np.exp(-t / 0.05) * 0.8
    x = body + skin
    x = np.tanh(1.6 * x)
    return x * 0.55 * vel


def frame_drum(vel=1.0):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = 95 * (1 + 0.8 * np.exp(-t / 0.02))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    x += bandpass(noise(n), 300, 2500) * np.exp(-t / 0.03) * 0.5
    return x * 0.35 * vel


def shaker(vel=1.0):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    x = highpass(noise(n), 5500) * np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.035)
    return x * 0.06 * vel


def tambourine(vel=1.0):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    x = bandpass(noise(n), 6000, 12000) * np.exp(-t / 0.09)
    for f in (5200, 6900, 8300):
        x += 0.3 * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.07)
    return x * 0.08 * vel


def tick(vel=1.0, pitch=1.0):
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1850 * pitch * t) * np.exp(-t / 0.012) + 0.5 * np.sin(2 * np.pi * 2650 * pitch * t) * np.exp(-t / 0.008)
    return x * 0.09 * vel


def snare(vel=1.0):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    x = bandpass(noise(n), 1500, 9000) * np.exp(-t / 0.07) + np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05) * 0.6
    return x * 0.18 * vel


def crash(vel=1.0, dur=2.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = highpass(noise(n), 4000) * np.exp(-t / 0.8)
    return x * 0.12 * vel


def riser(dur=2.0, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = bandpass(noise(n), 1500, 7000) * (t / dur) ** 2
    x *= np.clip((dur - t) / 0.06, 0, 1)  # 끝에서 뚝 끊기지 않게
    return x * 0.1 * vel


# ─────────────────────────────── 섞기 ───────────────────────────────

class Track:
    def __init__(self, seconds, tail=4.0):
        self.length = int(seconds * SR)
        self.buf = np.zeros((self.length + int(tail * SR), 2))
        self.send = np.zeros_like(self.buf)  # 잔향으로 보내는 몫

    def add(self, x, at, pan=0.0, gain=1.0, wet=0.25):
        i = int(at * SR)
        x = x * gain
        j = min(len(self.buf), i + len(x))
        if j <= i:
            return
        x = x[: j - i]
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        self.buf[i:j, 0] += x * left
        self.buf[i:j, 1] += x * right
        self.send[i:j, 0] += x * left * wet
        self.send[i:j, 1] += x * right * wet

    def render(self, loop=True, room=2.2, brightness=6000, low_cut=0.0):
        ir_n = int(room * SR)
        t = np.arange(ir_n) / SR
        wet = np.zeros_like(self.buf)
        for ch in range(2):
            ir = noise(ir_n) * np.exp(-6.9 * t / room)
            ir = lowpass(ir, brightness)
            ir[: int(0.012 * SR)] = 0  # 앞 반사음 전 빈 틈
            ir /= np.sqrt(np.sum(ir ** 2))
            wet[:, ch] = signal.fftconvolve(self.send[:, ch], ir)[: len(self.buf)]
        mix = self.buf + wet * 0.9
        if low_cut:
            # 저음을 조금 덜어낸다 : 크기를 맞출 때 가운데 소리가 올라와 휴대폰 스피커에서 잘 들린다
            mix = mix - low_cut * lowpass(mix.T, 160, 2).T
        if loop:
            # 끝에서 넘친 소리(잔향 · 끝음)를 앞에 겹친다 → 반복할 때 이음새가 없다
            tail = mix[self.length:]
            out = mix[: self.length].copy()
            out[: len(tail)] += tail[: self.length]
        else:
            out = mix
        return master(out)


def master(x, target_peak=0.89):
    x = highpass(x.T, 28).T
    # 부드러운 압축 (소리가 튀지 않게)
    level = np.max(np.abs(x)) + 1e-9
    x = x / level
    x = np.tanh(1.35 * x) / np.tanh(1.35)
    return x * target_peak


def write(name, audio):
    path = OUT / f"{name}.ogg"
    # libsndfile 은 긴 소리를 한 번에 OGG 로 쓰면 죽는다 → 조금씩 나눠 쓴다
    data = np.ascontiguousarray(audio.astype(np.float32))
    with sf.SoundFile(path, "w", SR, data.shape[1], format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), 4096):
            f.write(data[i:i + 4096])
    print(f"{path.name}: {len(audio) / SR:.1f}s  {path.stat().st_size // 1024} KB")


# ─────────────────────────────── 로비 뱃노래 ───────────────────────────────
# 6/8 박자, 점4분음표 = 68. 라단조(D minor). A · A' · B · B' 각 8마디 = 32마디 (약 56초)

LOBBY_CHORDS = {
    "Dm": ([62, 65, 69], 38, 45), "C": ([60, 64, 67], 36, 43), "Bb": ([58, 62, 65], 34, 41),
    "A": ([57, 61, 64], 33, 40), "F": ([60, 65, 69], 41, 48), "Gm": ([58, 62, 67], 43, 50),
}
LOBBY_FORM = [
    # (화음들, 가락 [음, 8분음표 길이])
    (["Dm"], [(69, 2), (74, 1), (74, 2), (76, 1)]), (["Dm"], [(77, 3), (76, 2), (74, 1)]),
    (["C"], [(72, 2), (76, 1), (76, 2), (79, 1)]), (["C"], [(76, 3), (74, 2), (72, 1)]),
    (["Bb"], [(70, 2), (74, 1), (77, 2), (74, 1)]), (["C"], [(72, 2), (76, 1), (79, 2), (76, 1)]),
    (["Dm"], [(77, 2), (76, 1), (74, 2), (72, 1)]), (["A"], [(73, 3), (69, 3)]),

    (["Dm"], [(69, 2), (74, 1), (74, 2), (76, 1)]), (["Dm"], [(77, 3), (79, 2), (81, 1)]),
    (["C"], [(79, 2), (76, 1), (72, 2), (76, 1)]), (["C"], [(79, 3), (77, 2), (76, 1)]),
    (["Bb"], [(74, 2), (77, 1), (74, 2), (70, 1)]), (["Gm"], [(70, 2), (74, 1), (79, 2), (77, 1)]),
    (["A"], [(76, 2), (73, 1), (76, 2), (79, 1)]), (["Dm"], [(74, 6)]),

    (["F"], [(81, 3), (77, 3)]), (["C"], [(79, 3), (76, 3)]),
    (["Dm"], [(77, 2), (76, 1), (74, 2), (77, 1)]), (["A"], [(76, 3), (73, 3)]),
    (["Bb"], [(74, 2), (77, 1), (82, 2), (81, 1)]), (["F"], [(81, 2), (79, 1), (77, 3)]),
    (["Gm", "A"], [(79, 2), (77, 1), (76, 2), (73, 1)]), (["Dm"], [(74, 3), (69, 3)]),

    (["F"], [(81, 2), (84, 1), (81, 2), (77, 1)]), (["C"], [(79, 2), (76, 1), (72, 3)]),
    (["Dm"], [(74, 2), (77, 1), (81, 2), (77, 1)]), (["Bb"], [(82, 3), (81, 2), (79, 1)]),
    (["Gm"], [(79, 2), (77, 1), (74, 2), (70, 1)]), (["C"], [(72, 2), (76, 1), (79, 3)]),
    (["A"], [(81, 3), (79, 2), (76, 1)]), (["A"], [(73, 3), (69, 2), (73, 1)]),
]


def lobby():
    eighth = 60 / (68 * 3)
    bar = eighth * 6
    tr = Track(bar * len(LOBBY_FORM))
    for b, (chords, melody) in enumerate(LOBBY_FORM):
        start = b * bar
        section = b // 8  # 0 A · 1 A' · 2 B · 3 B'
        # 반주 : 1 · 4 번째 8분음표에 베이스, 나머지에 아코디언 "짝짝"
        for e in range(6):
            chord = chords[0] if (len(chords) == 1 or e < 3) else chords[1]
            voicing, root, fifth = LOBBY_CHORDS[chord]
            at = start + e * eighth
            if e in (0, 3):
                tr.add(pluck_bass(root if e == 0 else fifth, eighth * 1.6, 1.0 if e == 0 else 0.8), at, pan=-0.05, wet=0.12)
                tr.add(frame_drum(0.9 if e == 0 else 0.6), at, pan=0.1, wet=0.2)
            else:
                tr.add(accordion(voicing, eighth * 0.55, 0.85 if e in (1, 4) else 0.65), at, pan=-0.35, wet=0.25)
            if section >= 1:
                tr.add(shaker(0.8 if e in (0, 3) else 0.5), at + 0.004, pan=0.45, wet=0.1)
            if section == 3 and e in (2, 5):
                tr.add(tambourine(0.8), at, pan=0.5, wet=0.2)
        # 가락 : 바이올린. A' 는 한 옥타브 위 휘파람이 겹친다. B 는 현악 화음이 받친다
        t = start
        for note, length in melody:
            dur = length * eighth
            tr.add(fiddle(note, dur * 0.94, 1.0), t, pan=0.2, wet=0.35)
            if section in (1, 3):
                tr.add(whistle(note + 12, dur * 0.9, 0.7 if section == 1 else 0.9), t, pan=0.35, wet=0.4)
            t += dur
        if section >= 2:
            voicing, _, _ = LOBBY_CHORDS[chords[0]]
            tr.add(strings_pad([v + 12 for v in voicing], bar * 0.95, 0.9), start, pan=-0.2, wet=0.5)
    return tr.render(room=2.0, brightness=5500)


# ─────────────────────────────── 게임 중 긴장 음악 ───────────────────────────────
# 100 BPM 4/4, 라단조(A minor) · 24마디 (57.6초). 1~8 조용히 · 9~16 커지고 · 17~24 가장 크게 → 다시 1마디로

TENSE_ROOTS = [45, 45, 41, 41, 38, 38, 40, 40]  # A A F F D D E E (두 마디씩)
TENSE_PAD = {45: [64, 69], 41: [65, 72], 38: [65, 69], 40: [68, 69]}  # E 에서는 G#+A 반음 부딪힘


def tense(bpm=100, bars=24, final=False):
    beat = 60 / bpm
    bar = beat * 4
    tr = Track(bar * bars)
    sixteenth = beat / 4
    for b in range(bars):
        start = b * bar
        root = TENSE_ROOTS[b % 8]
        part = 2 if final else min(2, b // 8)
        # 첼로 반복음
        pattern = [0, 0, 12, 0, 1 if root == 45 else 0, 0, 7, 0]
        steps = 16 if final else 8
        step = bar / steps
        for i in range(steps):
            rel = pattern[i % 8] if steps == 8 else pattern[(i // 2) % 8] if i % 2 == 0 else 0
            accent = 1.0 if i % (steps // 2) == 0 else (0.8 if i % (steps // 4) == 0 else 0.62)
            tr.add(cello(root - 12 + rel, step * 0.62, accent, bright=0.7 + 0.3 * accent), start + i * step, pan=-0.25, wet=0.18)
            # 한 옥타브 위 첼로 : 휴대폰 스피커(낮은 소리가 잘 안 나온다)에서도 반복음이 들리게
            tr.add(cello(root + rel, step * 0.5, accent * (0.4 if part == 0 else 0.6), bright=0.8), start + i * step, pan=0.3, wet=0.2)
        # 낮게 깔리는 울림
        tr.add(strings_pad([root - 24], bar * 0.98, 0.8, cutoff=500), start, wet=0.1)
        # 북 : 1박 · 3박 반. 4마디마다 몰아치기
        tr.add(taiko(1.0 if part else 0.7), start, pan=0, wet=0.3)
        tr.add(taiko(0.75 if part else 0.5, 1.12), start + beat * 2.5, pan=0.1, wet=0.3)
        if final or part >= 1:
            tr.add(taiko(0.55, 0.9), start + beat * 2, pan=-0.1, wet=0.3)
        if final:
            for k in (1, 3):
                tr.add(taiko(0.5, 1.25), start + beat * k, pan=0.2, wet=0.3)
            tr.add(snare(0.5), start + beat * 1, pan=0.15, wet=0.25)
            tr.add(snare(0.5), start + beat * 3, pan=0.15, wet=0.25)
        if b % 4 == 3:
            for k in range(4 if not final else 8):
                tr.add(taiko(0.35 + 0.1 * k, 1.35), start + beat * 3 + k * (sixteenth if not final else sixteenth / 2), pan=0.2, wet=0.3)
        # 째깍째깍 (시계)
        for i in range(8):
            tr.add(tick(0.9 if i % 2 == 0 else 0.55, 1.0 if i % 2 == 0 else 1.18), start + i * beat / 2, pan=0.55, wet=0.15)
        # 높은 현 · 떨림 (둘째 부분부터)
        if part >= 1 and b % 2 == 0:
            tr.add(strings_pad(TENSE_PAD[root], bar * 2 * 0.97, 1.0 if part == 1 else 1.3, tremolo=11), start, pan=0.1, wet=0.45)
        # 금관 "빠암" (둘째 부분 두 마디마다 · 셋째 부분은 매 마디)
        if (part == 1 and b % 2 == 0) or part == 2:
            tr.add(horn(root - 12, beat * 1.4, 0.9), start, pan=-0.1, wet=0.35)
            tr.add(horn(root - 5, beat * 1.4, 0.6), start, pan=0.1, wet=0.35)
        # 셋째 부분 : 합창
        if part == 2 and b % 2 == 0:
            tr.add(choir([root + 12, root + 19], bar * 2 * 0.95, 1.0), start, pan=0, wet=0.6)
        # 오르골 가락 : 반음 오르내림 (해적이 다가오는 느낌)
        if part >= 1 and b % 2 == 1:
            for k, note in enumerate([76, 77, 76, 0, 76, 77, 81, 80] if root != 40 else [80, 81, 80, 0, 80, 81, 84, 83]):
                if note:
                    tr.add(bell(note, 2.0, 0.8), start + k * beat / 2, pan=0.4, wet=0.55)
        # 마지막 두 마디는 끝에서 쓱 끌어올려 첫 마디로 이어진다
        if b == bars - 1:
            tr.add(riser(bar, 0.9), start, pan=0, wet=0.3)
    return tr.render(room=2.6, brightness=4800, low_cut=0.5)


# ─────────────────────────────── 효과음 ───────────────────────────────

def heartbeat():
    tr = Track(0.62, tail=0.2)
    for at, vel, pitch in ((0.02, 1.0, 1.0), (0.29, 0.72, 1.18)):
        n = int(0.5 * SR)
        t = np.arange(n) / SR
        f = 48 * pitch * (1 + 0.9 * np.exp(-t / 0.018))
        thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.085)
        thump += lowpass(noise(n), 180) * np.exp(-t / 0.03) * 0.35
        thump = np.tanh(2.2 * thump) * np.clip(t / 0.004, 0, 1)
        tr.add(lowpass(thump, 400), at, gain=vel, wet=0.05)
    return tr.render(loop=False, room=0.6, brightness=1200)


def jackpot():
    tr = Track(3.2, tail=2.0)
    # 금관 팡파르 (D 장조 : 라 레 파# 라 — 레)
    for k, (note, at, dur) in enumerate([(62, 0.0, 0.16), (66, 0.14, 0.16), (69, 0.28, 0.16), (74, 0.42, 1.6)]):
        tr.add(horn(note, dur, 1.2), at, pan=-0.1, wet=0.35)
        tr.add(horn(note + 12, dur, 0.6), at, pan=0.1, wet=0.35)
    tr.add(strings_pad([62, 66, 69, 74], 1.8, 1.6, cutoff=5000), 0.42, wet=0.5)
    tr.add(taiko(1.0, 1.2), 0.42, wet=0.3)
    tr.add(crash(1.2), 0.42, wet=0.3)
    # 동전 반짝임
    for i in range(34):
        at = 0.4 + RNG.uniform(0, 2.2)
        tr.add(bell(int(RNG.integers(86, 101)), 0.9, 0.5 * RNG.uniform(0.4, 1)), at, pan=RNG.uniform(-0.8, 0.8), wet=0.5)
    return tr.render(loop=False, room=1.8, brightness=9000)


TRACKS = {
    "lobby": lobby,
    "match": lambda: tense(100, 24),
    "final": lambda: tense(124, 16, final=True),
    "heartbeat": heartbeat,
    "jackpot": jackpot,
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(TRACKS)
    for name in names:
        write(name, TRACKS[name]())
