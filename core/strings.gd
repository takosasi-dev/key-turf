# 画面に出す文言(INV-6・画面設計書 §6)。文言はここだけに置く。
# 文言を足したら tools/subset_font.py を回し直す(同梱の字体はここの文字に絞ってある)。
extends RefCounted

const NAME := "KeyTurf"
const VERSION := "v0.3.0"

# S0(共通 §6)
const S0_START := "クリックかキーで始める"
const S0_KEYBOARD := "キーボードで遊ぶゲーム"
const TOUCH := "このゲームはキーボードで遊ぶ。PC で開いてほしい"
const IME := "日本語入力を切って(半角英数で)遊んでほしい"

# S1 タイトル
const TAGLINE := "外に線を引いて戻ると、囲んだ所が自分の色になる"
const B_DUO := "ふたりで"
const B_EASY := "CPU と(やさしい)"
const B_NORMAL := "CPU と(ふつう)"
const B_SETTINGS := "設定"
const REC := "%d勝 %d敗"
const REC_DRAW := "%d勝 %d敗 %d分"
const LOAD_FAILED := "保存を読めなかったので、記録を初めからにした"

# S2 プレイ。人の名前は [ふたりで, やさしい, ふつう] の mode ごとに [P1, P2]
const NAMES := [["P1", "P2"], ["あなた", "CPU やさしい"], ["あなた", "CPU ふつう"]]
const PERCENT := "%d%%"
const ROUND := "ラウンド %d"
const PRACTICE := "練習(数えない)"
const GO := "はじめ"
const PLUS := "+%d"
const PRACTICE_NOTE := "線を引いて陣地へ戻ると、囲んだ所が取れる。数えないラウンド"
const WIN := "%s の勝ち — %s"
const DRAW := "引き分け — %s"
const SCORE_PCT := "%d%%  −  %d%%"  # 時間切れの帯の 2 行目(2 人の広さ。磨きで足した)
const ESC := "Esc"

# 理由(core/sim.gd の REASON_* の順)
const REASONS := ["線を切った", "自分の線に入った", "囲んだ", "陣地が 0", "正面衝突", "相打ち", "広さ", "同じ広さ"]

# S3 結果
const RES_WIN := "%s の勝ち  %d − %d"
const RES_DRAW := "引き分け  %d − %d"
const COL_ROUND := "ラウンド"
const COL_WINNER := "勝者"
const COL_REASON := "理由"
const DRAW_SHORT := "引き分け"
const CPU_TOTAL := "CPU(%s)の通算  %s"
const LEVELS := ["", "やさしい", "ふつう"]
const B_RETRY := "もう1回"
const B_TITLE := "タイトルへ"
const SAVE_FAILED := "このブラウザでは記録を残せない"

# S4 設定・S5 一時停止(共通 §6)
const SETTINGS := "設定"
const SET_VOLUME := "音量"
const SET_SHAKE := "画面の揺れ"
const SET_FLASH := "点滅を弱める"
const SET_KEYTEST := "キーの確かめ"
const ON := "入"
const OFF := "切"
const B_BACK := "戻る"
const KEYTEST_P1 := ["W", "D", "S", "A"]  # 向きの順(上・右・下・左)
const KEYTEST_NOTE := "2 人で同時に押して、両方が光るかを見る。Esc で戻る"
const PAUSE := "一時停止"
const B_RESUME := "続ける"
const B_RESTART := "やり直す"

# キーの確かめ(共通 §3 の 22。?keys=1)
const KEYS_TITLE := "キーの確かめ(押したキーを下に出す。Esc 2 回でタイトルへ)"

# v0.3.0 で足した文言(キーの案内・結果の見出し・設定の値。矢印は字でなく絵で描く)
const HINT_LEFT := "左"
const HINT_RIGHT := "右"
const HINT_OR := "か"
const HINT_SELECT := "選ぶ"
const HINT_DECIDE := "決める"
const HINT_CHANGE := "変える"
const RES_WINNER := "%s の勝ち"
const RES_DRAW_TITLE := "引き分け"
const COL_AREA := "広さ"
const SCORE := "%d  −  %d"  # 結果の大きな勝ち数(v0.3.0)
