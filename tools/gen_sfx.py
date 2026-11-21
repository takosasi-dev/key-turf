"""効果音 12 個(仕様書 §9.10 の 10 個と、v0.3.0 で足した UI の 2 個)を合成して assets/sfx/<名前>.wav に書く。標準ライブラリだけ・乱数は使わない(何度回しても同じバイト列)。
16bit PCM・モノラル・22050 Hz。合計 300 KB 以下(非機能 NFR-7)。作りは KeySwat の tools/gen_sfx.py。

    python tools/gen_sfx.py
"""

import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"
RATE = 22050
TAU = 2 * math.pi


def tone(buf, at, dur, f0, f1=None, gain=1.0, decay=0.0, square=False):
    """音 1 本を buf に足す。f0→f1 へ直線で動き、exp(-decay*t) で消える。square なら矩形に近い音(奇数倍音 3 本)。"""
    f1 = f1 or f0
    start = int(at * RATE)
    n = int(dur * RATE)
    while len(buf) < start + n:
        buf.append(0.0)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        e = gain * math.exp(-decay * t) * min(1.0, (n - i) / (0.004 * RATE), i / (0.001 * RATE))
        s = math.sin(phase)
        if square:
            s += math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5
        buf[start + i] += e * s
        phase += TAU * (f0 + (f1 - f0) * i / n) / RATE


def hiss(buf, at, dur, gain=1.0, decay=0.0):
    """「スッ」: 乱数を使わない雑音(高い周波数の和で作る)。"""
    for k, f in enumerate([3100, 4270, 5530, 6890, 7710]):
        tone(buf, at, dur, f, f * 0.8, gain=gain / (k + 1), decay=decay)


def write(name, buf, peak):
    top = max(abs(x) for x in buf) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / top * peak * 32767)) for x in buf))


def main():
    b = []
    tone(b, 0, 0.03, 1500, 1300, decay=80)  # 予約を受け付けた・メニューの選択: 小さいクリック
    write("turn", b, 0.3)
    b = []
    tone(b, 0, 0.12, 1320, decay=18)  # はじめ: 短い高い音(数えは下げて使う)
    write("go", b, 0.45)
    b = []
    tone(b, 0, 0.09, 220, 160, gain=0.6, decay=25)
    hiss(b, 0, 0.09, gain=0.5, decay=30)  # 線を引き始めた: 低い「スッ」
    write("trail", b, 0.3)
    b = []
    for k, f in enumerate([520, 660, 780]):
        tone(b, k * 0.03, 0.16, f, f * 1.05, decay=14)  # 囲んだ: 塗る音(大きい囲みは 3 つ重ねて和音)
    write("capture", b, 0.4)
    b = []
    tone(b, 0, 0.06, 2600, 1800, square=True, decay=35)
    hiss(b, 0, 0.05, gain=0.6, decay=60)  # 線を切った: 鋭い音
    write("cut", b, 0.5)
    b = []
    tone(b, 0, 0.22, 180, 120, square=True, decay=9)  # 自分の線に入った: 鈍い音
    write("self", b, 0.5)
    b = []
    for k, f in enumerate([300, 220, 150]):
        tone(b, k * 0.07, 0.18, f, decay=10)  # 囲んだ(決着): 低い音
    write("enclose", b, 0.5)
    b = []
    tone(b, 0, 0.12, 400, 90, square=True, decay=18)
    hiss(b, 0, 0.08, gain=0.8, decay=40)  # 正面衝突・相打ち: ぶつかる音
    write("clash", b, 0.5)
    b = []
    for k, f in enumerate([660, 880, 1320]):
        tone(b, k * 0.08, 0.2, f, decay=9)  # 時間切れ: 明るい音(同じ広さは下げて平らに)
    write("time", b, 0.45)
    b = []
    for k, f in enumerate([523, 659, 784, 1047]):
        tone(b, k * 0.12, 0.34, f, square=True, decay=6)  # 試合の終わり
    write("over", b, 0.5)
    b = []
    tone(b, 0, 0.035, 880, 820, gain=0.8, decay=70)
    tone(b, 0, 0.02, 2640, decay=120, gain=0.25)  # UI の選択(v0.3.0): 盤に駒を置くような短い木の音
    write("select", b, 0.28)
    b = []
    tone(b, 0, 0.05, 660, decay=40)
    tone(b, 0.045, 0.09, 990, decay=30)  # UI の決定(v0.3.0): 上がる 2 音
    write("confirm", b, 0.35)
    total = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"{len(list(OUT.glob('*.wav')))} 個、合計 {total:,} バイト")


if __name__ == "__main__":
    main()
