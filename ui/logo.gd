# 題字(v0.3.0): 「Key」を P1 の陣地(青緑・点)、「Turf」を P2 の陣地(橙・斜線)の上に置き、2 つの陣地の境を盤のマスの階段にする。
# 下では P1 の実線と丸い頭、P2 の破線と四角い頭が向き合う。字は象牙の駒の色に墨の影。
# 出る時は陣地が階段ごとに塗られ、字が落ちてはねる(LOGO_IN_MS)。animate が偽なら止まった形で描く。時刻は now_ms で固定できる。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

const FS := 112  # 字の大きさ
const H := 132.0  # 陣地の高さ
const STEP := 24.0  # 階段の 1 段(盤のマス)

var start_ms := 0
var animate := true
var now_ms := 0
var words: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_ms = Time.get_ticks_msec()
	var name_s: String = S.NAME
	words = [name_s.substr(0, 3), name_s.substr(3)]  # Key / Turf


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


func _k() -> float:
	return 1.0 if not animate else clampf(float(_now() - start_ms) / B.LOGO_IN_MS, 0.0, 1.0)


func _process(_delta: float) -> void:
	if animate and _now() - start_ms <= B.LOGO_IN_MS + 50:
		queue_redraw()


func _draw() -> void:
	var f := Kit.num_font()
	var k := _k()
	var ws := [f.get_string_size(words[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x, f.get_string_size(words[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x]
	var pad := 40.0
	var total: float = ws[0] + ws[1] + pad * 4.0
	var x0 := (size.x - total) / 2.0
	var split: float = x0 + ws[0] + pad * 2.0
	var third := H / 3.0
	# 陣地: 3 段の帯。境は上から +1 段・0・−1 段
	for row in 3:
		var off := STEP * (1 - row)
		var y := row * third
		var reveal := Kit.ease_out(k * 3.0 - row * 0.5)
		if reveal <= 0.0:
			continue
		var left := Rect2(x0, y, (split + off - x0) * reveal, third)
		var right_w := (x0 + total - (split + off)) * reveal
		var right := Rect2(x0 + total - right_w, y, right_w, third)
		for p in 2:
			var r: Rect2 = left if p == 0 else right
			draw_rect(r, Kit.C_LAND[p])
			Kit.draw_pattern(self, r, p, Color(Kit.C_TRAIL[p], 0.5), STEP)
	draw_rect(Rect2(x0, 0, total, H), Color(Kit.C_INK, 0.35 * (1.0 - k)))
	# 字(落ちてはねる)
	for w in 2:
		var lk := Kit.ease_back(clampf(k * 1.6 - 0.35 - w * 0.12, 0.0, 1.0))
		var drop := (1.0 - lk) * -60.0
		var x: float = x0 + pad if w == 0 else split + pad
		var base := Vector2(x, H * 0.5 + FS * 0.36 + drop)
		var a := clampf(lk * 2.0, 0.0, 1.0)
		draw_string(f, base + Vector2(5, 7), words[w], HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(Kit.C_INK, 0.85 * a))
		draw_string(f, base, words[w], HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(Kit.C_PAPER, a))
	# 下の線と頭(向き合う)
	var ly := H + 26.0
	var tk := Kit.ease_out(k * 1.4 - 0.4)
	if tk > 0.0:
		var mid := split
		var p1_end := lerpf(x0, mid - 34.0, tk)
		var p2_end := lerpf(x0 + total, mid + 34.0, tk)
		draw_line(Vector2(x0, ly), Vector2(p1_end, ly), Kit.C_TRAIL[0], 8.0, true)
		draw_dashed_line(Vector2(x0 + total, ly), Vector2(p2_end, ly), Kit.C_TRAIL[1], 8.0, 7.0, false)
		Kit.draw_mark(self, Vector2(p1_end, ly), 0, 26.0, Kit.C_BG)
		Kit.draw_mark(self, Vector2(p1_end, ly), 0, 22.0, Kit.C_HEAD[0])
		Kit.draw_mark(self, Vector2(p2_end, ly), 1, 26.0, Kit.C_BG)
		Kit.draw_mark(self, Vector2(p2_end, ly), 1, 20.0, Kit.C_HEAD[1])
	# 旗(左右の端に 1 本ずつ)
	var fk := Kit.ease_back(clampf(k * 1.5 - 0.5, 0.0, 1.0))
	if fk > 0.0:
		Kit.draw_flag(self, Vector2(x0 + 14.0, 2.0), 46.0 * fk, 0, Kit.C_TRAIL[0])
		Kit.draw_flag(self, Vector2(x0 + total - 40.0, 2.0), 46.0 * fk, 1, Kit.C_TRAIL[1])
