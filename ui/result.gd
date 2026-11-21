# S3 結果(画面設計書 §4・FR-21・FR-22・「UI の見た目(v0.3.0)」)。試合の勝者と勝ち数、ラウンドごとの勝者・理由・2 人の割合、CPU の試合ではその段の通算。
# v0.3.0: 勝った陣の旗が立ち(まわりに陣の印が散る)、勝ち数を数え上げ、表の行を上から順に出す。割合は 2 人の陣の帯(点・斜線)で見せる。
# 「もう1回」は最初から選んである(300 ms 後から押せる。Enter・R でも)。結果の文字コピーは作らない(仕様書 D-11)。
# 動きは時刻だけで決まる(now_ms で固定できる)。animate が偽(点滅を弱める 入)なら初めから全部出す。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const TABLE_X := 220.0
const TABLE_W := 840.0
const BAR_X := 640.0  # 割合の帯の左
const BAR_W := 400.0

var menu: Menu
var headline := ""
var animate := true
var now_ms := 0
var winner := -1
var wins: Array = [0, 0]
var rows: Array = []  # [勝者, 割合 P1, 割合 P2]
var row_y0 := 0.0
var row_h := 36.0
var _shown_at := 0
var _retry: Button
var _score: Label
var _row_nodes: Array = []


# result は match.result()、record はその段の通算(ふたりでは空)、saved は書けたか。
@warning_ignore("integer_division")
func build(mode: int, result: Dictionary, record: Dictionary, saved: bool) -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown_at = Time.get_ticks_msec()
	var names: Array = S.NAMES[mode]
	wins = result["wins"]
	winner = result["winner"]
	headline = S.RES_DRAW % [wins[0], wins[1]] if winner < 0 else S.RES_WIN % [names[winner], wins[0], wins[1]]
	var title := S.RES_DRAW_TITLE if winner < 0 else S.RES_WINNER % names[winner]
	add_child(Kit.place(Kit.label(title, 40, Kit.C_TEXT if winner < 0 else Kit.C_TRAIL[winner].lerp(Kit.C_WHITE, 0.25), 800), 0, 22, 1280, 56))
	_score = Kit.num_label("", 104, Kit.C_TEXT)
	add_child(Kit.place(_score, 390, 74, 500, 124))
	# 表の見出し
	var list: Array = result["rounds"]
	row_h = minf(44.0, 300.0 / maxf(list.size(), 1))
	row_y0 = 246.0 + (300.0 - row_h * list.size()) / 2.0  # 行が少ない時は表を縦の真ん中へ
	var cols := [[TABLE_X, 90, S.COL_ROUND], [TABLE_X + 90, 150, S.COL_WINNER], [TABLE_X + 240, 180, S.COL_REASON], [BAR_X, BAR_W, S.COL_AREA]]
	for col: Array in cols:
		var h := Kit.label(col[2], 16, Kit.C_DIM, 700)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if col[0] != TABLE_X else HORIZONTAL_ALIGNMENT_CENTER
		add_child(Kit.place(h, col[0], row_y0 - 30.0, col[1], 26))
	for k in list.size():
		var r: Dictionary = list[k]
		var rw: int = r["winner"]
		var counts: Array = r["counts"]
		rows.append([rw, int(counts[0]) * 100 / 1248, int(counts[1]) * 100 / 1248])
		var row := Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(Kit.place(row, 0, row_y0 + k * row_h, 1280, row_h))
		var fs := 20 if row_h >= 30.0 else 17
		row.add_child(Kit.place(Kit.label(str(k + 1), fs, Kit.C_DIM, 700), TABLE_X, 0, 90, row_h))
		var wl := Kit.label(S.DRAW_SHORT if rw < 0 else names[rw], fs, Kit.C_DIM if rw < 0 else Kit.C_TRAIL[rw].lerp(Kit.C_WHITE, 0.2), 700)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(Kit.place(wl, TABLE_X + 118, 0, 150, row_h))
		var why := Kit.label(S.REASONS[int(r["reason"])], fs, Kit.C_TEXT, 500)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(Kit.place(why, TABLE_X + 240, 0, 180, row_h))
		for p in 2:
			var pl := Kit.label(S.PERCENT % rows[k][1 + p], fs - 2, Kit.C_TEXT, 800)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if p == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			pl.add_theme_constant_override("outline_size", 5)
			pl.add_theme_color_override("font_outline_color", Kit.C_INK)
			row.add_child(Kit.place(pl, BAR_X + 8 if p == 0 else BAR_X + BAR_W - 88, 0, 80, row_h))
		row.draw.connect(_draw_row.bind(row, k))
		_row_nodes.append(row)
	if not record.is_empty():
		var rec := S.REC_DRAW % [record["win"], record["lose"], record["draw"]] if int(record["draw"]) > 0 else S.REC % [record["win"], record["lose"]]
		add_child(Kit.place(Kit.label(S.CPU_TOTAL % [S.LEVELS[mode], rec], 20, Kit.C_DIM, 700), 0, 556, 1280, 32))
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 30), 384, 600, 252, 72)
	_retry.disabled = true
	var to_t := Kit.place(Kit.button("title", S.B_TITLE, 26), 660, 600, 236, 72)
	add_child(_retry)
	add_child(to_t)
	if not saved:
		var warn := Kit.label(S.SAVE_FAILED, 16, Kit.C_WARN, 700)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(Kit.place(warn, 24, 680, 520, 30))
	add_child(Kit.place(KeyHint.new([[["Enter", "R"], S.B_RETRY]], HORIZONTAL_ALIGNMENT_RIGHT), 680, 676, 576, 36))
	_retry.pressed.connect(func() -> void: retry.emit())
	to_t.pressed.connect(func() -> void: to_title.emit())
	menu = Menu.new([_retry, to_t] as Array[Button], 0)
	_step()


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


func _age() -> int:
	return 100000 if not animate else _now() - _shown_at


# 数え上げの途中の勝ち数。
func shown_wins() -> Array:
	var k := Kit.ease_out(float(_age()) / B.RESULT_COUNT_MS)
	return [int(round(int(wins[0]) * k)), int(round(int(wins[1]) * k))]


func _step() -> void:
	var w := shown_wins()
	_score.text = S.SCORE % w
	var age := _age()
	for k in _row_nodes.size():
		var row := _row_nodes[k] as Control
		var a := Kit.ease_out(float(age - B.RESULT_COUNT_MS * 0.5 - k * B.RESULT_ROW_MS) / B.RESULT_ROW_IN_MS)
		row.modulate.a = a
		row.position.x = 24.0 * (1.0 - a)
		row.queue_redraw()
	queue_redraw()


func _process(_delta: float) -> void:
	if _retry.disabled and Time.get_ticks_msec() - _shown_at >= B.RETRY_LOCK_MS:
		_retry.disabled = false
	if _age() < B.RESULT_COUNT_MS + B.RESULT_ROW_MS * 10 + B.RESULT_ROW_IN_MS + B.BURST_MS:
		_step()


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_R and not _retry.disabled:
		retry.emit()
		return
	menu.key(ev)


# 1 行: 勝者の印と、2 人の広さの帯(左 P1 の点・右 P2 の斜線。真ん中は空き)。
func _draw_row(row: Control, k: int) -> void:
	var r: Array = rows[k]
	var h := row.size.y
	var cy := h / 2.0
	if k % 2 == 0:
		row.draw_rect(Rect2(TABLE_X - 12, 1, TABLE_W + 24, h - 2), Color(Kit.C_BOARD, 0.8))
	var rw: int = r[0]
	if rw >= 0:
		Kit.draw_mark(row, Vector2(TABLE_X + 100, cy), rw, minf(16.0, h * 0.45), Kit.C_TRAIL[rw])
	else:
		row.draw_line(Vector2(TABLE_X + 92, cy), Vector2(TABLE_X + 108, cy), Kit.C_DIM, 3.0)
	var bar := Rect2(BAR_X, cy - minf(13.0, h * 0.38), BAR_W, minf(26.0, h * 0.76))
	row.draw_rect(bar, Kit.C_INK)
	var grow := Kit.ease_out(float(_age() - B.RESULT_COUNT_MS * 0.5 - k * B.RESULT_ROW_MS - 80) / B.RESULT_ROW_IN_MS)
	for p in 2:
		var w := BAR_W * int(r[1 + p]) / 100.0 * grow
		var seg := Rect2(bar.position.x if p == 0 else bar.end.x - w, bar.position.y, w, bar.size.y)
		row.draw_rect(seg, Kit.C_LAND[p])
		Kit.draw_pattern(row, seg, p, Color(Kit.C_TRAIL[p], 0.75), 10.0)


# 勝ち数の横に陣の印、勝った陣の旗と、まわりに散る印。引き分けは 2 本の旗を寝かせずに並べるだけ。
func _draw() -> void:
	var age := _age()
	var score_c := Vector2(640, 136)
	var font := Kit.num_font()
	var half := font.get_string_size(_score.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 104).x / 2.0
	for p in 2:
		var x := score_c.x - half - 40.0 if p == 0 else score_c.x + half + 40.0
		Kit.draw_mark(self, Vector2(x, score_c.y), p, 30.0, Kit.C_TRAIL[p])
	var fk := Kit.ease_back(float(age - 120) / B.FLAG_MS)
	if winner >= 0:
		var foot := Vector2(score_c.x - half - 150.0 if winner == 0 else score_c.x + half + 110.0, score_c.y + 50.0)
		if fk > 0.0:
			Kit.draw_flag(self, foot, 96.0 * fk, winner, Kit.C_TRAIL[winner])
		var bk := float(age - 200) / B.BURST_MS
		if animate and bk > 0.0 and bk < 1.0:
			for n in 14:
				var v := Vector2.RIGHT.rotated(TAU * n / 14.0 + 0.3)
				var at := foot + Vector2(18, -60) + v * (30.0 + 130.0 * Kit.ease_out(bk)) + Vector2(0, 40.0 * bk * bk)
				Kit.draw_mark(self, at, winner, 10.0 * (1.0 - bk) + 3.0, Color(Kit.C_TRAIL[winner], 1.0 - bk))
	elif fk > 0.0:
		for p in 2:
			Kit.draw_flag(self, Vector2(score_c.x - half - 120.0 if p == 0 else score_c.x + half + 80.0, score_c.y + 46.0), 72.0 * fk, p, Kit.C_TRAIL[p])
