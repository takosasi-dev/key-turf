# 調整値(仕様書 §9.9・INV-6)。時間は tick(1/120 秒)の整数で持つ。
# 演出の時間(ms)・設定の段・テスト用の bot の値もここに置く。ほかのファイルに数値の調整値を書かない。
extends RefCounted

const TICK_HZ := 120
const MAX_STEPS_PER_FRAME := 8

# 盤(§9.1・§9.2)
const GRID_W := 48
const GRID_H := 26
const CELL := 24
const GRID_X := 64
const GRID_Y := 72
const HOME_HALF := 2
const P1_HEAD := Vector2i(8, 13)  # P2 は盤の中心で 180 度回した (39, 12)
const P1_HOME_TOP := 11  # P1 の陣地の上の端の y(頭の y − 2)

# 動き(§9.3・§9.4)
const MOVE_TICKS := 14
const QUEUE_MAX := 2

# ラウンドと試合(§9.6・§9.7)
const COUNTDOWN_TICKS := 180
const ROUND_END_TICKS := 240
const ROUND_TICKS := 3600
const PRACTICE_TICKS := 1800
const WINS_TO_WIN := 3
const MAX_ROUNDS := 9

# CPU(§9.8)。範囲は両端を含む
const CPU_LOOK := 8  # d1 を選ぶ時に見る先のマス数
const EASY_A := [2, 4]
const EASY_B := [2, 5]
const EASY_MARGIN := 4
const NORMAL_A := [3, 7]
const NORMAL_B := [3, 9]
const NORMAL_MARGIN := 1
const ATTACK_MARGIN := 2
const CPU_RNG_XOR := 0x43505521

# テスト用の bot(§9.12)
const BOT_RNG_XOR := 0x6B747266
const BOT_RANDOM_EVERY := 14  # ランダム bot が向きを選び直す間隔(tick)
const BOT_RANDOM_TURN_PCT := 35  # その時に曲がる割合

# 演出(§9.10・画面設計書 §8)
const BIG_CAPTURE := 60

# 設定(共通 §3 の 17)
const VOLUMES := [0, 25, 50, 75, 100]
const DEFAULT_VOLUME := 75

# 演出の時間(ms)と大きさ(px)。画面設計書 §8
const FILL_MS := 300
const FLOAT_MS := 600
const FLOAT_RISE_PX := 60
const BIG_SCALE := 1.6
const BANNER_TICKS := 240  # 決着の帯(2 秒)
const GO_TICKS := 60  # 「はじめ」を出す長さ
const COUNT_STEP_TICKS := 60  # 3・2・1 の 1 段
const OVER_TICKS := 72  # 試合の決着から結果画面まで(600 ms)
const SHAKE_BIG_PX := 4.0
const SHAKE_BIG_MS := 120
const SHAKE_END_PX := 6.0
const SHAKE_END_MS := 150
const END_FX_MS := 900  # 決着の光・点滅・縮みの長さ
const TRAIL_GLOW_MS := 400
const REDUCED_FLASH_ALPHA := 0.2
const RETRY_LOCK_MS := 300
const IME_NOTE_MS := 3000
const LAST_SECONDS := 5  # 残り時間の字を明るくし、1 秒ごとに鳴らす
const COUNT_PITCH := -7  # 数えの音(go を下げて使う)
const TIE_PITCH := -12  # 同じ広さの平らな音(time を下げて使う)
const CHORD := [0, 4, 7]  # 大きな囲みの和音(半音)
const TRAIL_PX := 8.0
const HEAD_PX := 20.0
