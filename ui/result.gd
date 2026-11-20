# S3 結果(画面設計書 §4・FR-21・FR-22)。試合の勝者と勝ち数、ラウンドごとの勝者・理由・2 人の割合、CPU の試合ではその段の通算。
# もう1回は 300 ms 後から押せる(Enter・R でも)。結果の文字コピーは作らない(仕様書 D-11)。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

var menu: Menu
var headline := ""
var _shown_at := 0
var _retry: Button


# result は match.result()、record はその段の通算(ふたりでは空)、saved は書けたか。
@warning_ignore("integer_division")
func build(mode: int, result: Dictionary, record: Dictionary, saved: bool) -> void:
	size = Vector2(1280, 720)
	_shown_at = Time.get_ticks_msec()
	var names: Array = S.NAMES[mode]
	var wins: Array = result["wins"]
	var w: int = result["winner"]
	headline = S.RES_DRAW % [wins[0], wins[1]] if w < 0 else S.RES_WIN % [names[w], wins[0], wins[1]]
	add_child(Kit.place(Kit.label(headline, 56, Kit.C_TEXT if w < 0 else Kit.C_TRAIL[w], 800), 0, 32, 1280, 90))
	var cols := [[200, 120, S.COL_ROUND], [320, 200, S.COL_WINNER], [520, 260, S.COL_REASON], [780, 150, names[0]], [930, 150, names[1]]]
	for col: Array in cols:
		add_child(Kit.place(Kit.label(col[2], 18, Kit.C_DIM, 700), col[0], 140, col[1], 32))
	var rounds: Array = result["rounds"]
	for k in rounds.size():
		var r: Dictionary = rounds[k]
		var rw: int = r["winner"]
		var counts: Array = r["counts"]
		var cells := [str(k + 1), S.DRAW_SHORT if rw < 0 else names[rw], S.REASONS[int(r["reason"])],
			S.PERCENT % (int(counts[0]) * 100 / 1248), S.PERCENT % (int(counts[1]) * 100 / 1248)]
		# 勝者はその人の色(引き分けは弱い字)、割合はその人の色を淡くして、表を色でも追えるようにする
		var tints: Array = [Kit.C_DIM, Kit.C_DIM if rw < 0 else Kit.C_TRAIL[rw], Kit.C_TEXT,
			Kit.C_TRAIL[0].lerp(Kit.C_WHITE, 0.5), Kit.C_TRAIL[1].lerp(Kit.C_WHITE, 0.5)]
		for c in cols.size():
			add_child(Kit.place(Kit.label(cells[c], 22, tints[c], 700 if c == 1 else 500), cols[c][0], 174 + k * 36, cols[c][1], 34))
	if not record.is_empty():
		var rec := S.REC_DRAW % [record["win"], record["lose"], record["draw"]] if int(record["draw"]) > 0 else S.REC % [record["win"], record["lose"]]
		add_child(Kit.place(Kit.label(S.CPU_TOTAL % [S.LEVELS[mode], rec], 24, Kit.C_DIM, 700), 0, 510, 1280, 40))
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 30), 380, 576, 240, 72)
	_retry.disabled = true
	var title := Kit.place(Kit.button("title", S.B_TITLE, 26), 660, 576, 240, 72)
	add_child(_retry)
	add_child(title)
	if not saved:
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 20, Kit.C_WARN), 0, 664, 1280, 40))
	_retry.pressed.connect(func() -> void: retry.emit())
	title.pressed.connect(func() -> void: to_title.emit())
	menu = Menu.new([_retry, title] as Array[Button], 0)


func _process(_delta: float) -> void:
	if _retry.disabled and Time.get_ticks_msec() - _shown_at >= B.RETRY_LOCK_MS:
		_retry.disabled = false


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_R and not _retry.disabled:
		retry.emit()
		return
	menu.key(ev)
