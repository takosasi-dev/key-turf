# 卓の背景(v0.3.0): 見えている範囲(view)全体に藍の地と、盤と揃ったマス目を薄く敷く。
# demo が真なら、タイトルの空気として 2 陣が盤の外で小さく陣を取り合う様子を薄く流す(時刻だけで決まる。乱数・sim は使わない)。
# P1 は丸い頭・実線・点の陣地、P2 は四角い頭・破線・斜線の陣地(盤と同じ見分け)。animate が偽なら止まった 1 枚を描く(点滅を弱める 入)。
# 地・マス目・いつも敷く陣地は自分に 1 回だけ描き、毎フレーム描き直すのは動く輪だけ(子の _live)。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

const C := 24.0  # マスの大きさ(盤と同じ)
# 陣を取る輪(マスの座標。舞台の左上が 0。x, y, 幅, 高さ)。P1 は左、P2 は右を回る
const LOOPS := [
	[[-6, 18, 7, 5], [2, 3, 5, 4], [-9, 6, 6, 8]],
	[[44, 3, 6, 5], [46, 17, 7, 6], [38, 23, 6, 4]],
]
# いつも敷いてある陣地(左下と右上。階段の形)
const LANDS := [
	[[-12, 20, 16, 12], [-12, 15, 9, 6], [4, 24, 6, 8]],
	[[42, -6, 18, 8], [52, 2, 8, 6], [38, -6, 5, 4]],
]

var view := Rect2(0, 0, 1280, 720)
var demo := true
var animate := true
var now_ms := 0  # 描く時刻(テストが固定できるように持つ)
var _still_ms := 2600  # 動かさない時に描く時刻
var _live := Control.new()  # 動く輪だけを描く層


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live.draw.connect(_draw_live)
	add_child(_live)


func _now() -> int:
	if now_ms > 0:
		return now_ms
	return Time.get_ticks_msec() if animate else _still_ms


func _process(_delta: float) -> void:
	if demo and animate and is_visible_in_tree():
		_live.queue_redraw()


static func _cell_rect(r: Array) -> Rect2:
	return Rect2(B.GRID_X + float(r[0]) * C, B.GRID_Y + float(r[1]) * C, float(r[2]) * C, float(r[3]) * C)


# 輪の周りの点(左上から時計回り)。k は 0〜1。
static func perimeter_point(r: Rect2, k: float) -> Vector2:
	var per := 2.0 * (r.size.x + r.size.y)
	var d := fposmod(k, 1.0) * per
	if d < r.size.x:
		return r.position + Vector2(d, 0)
	d -= r.size.x
	if d < r.size.y:
		return r.position + Vector2(r.size.x, d)
	d -= r.size.y
	if d < r.size.x:
		return r.end - Vector2(d, 0)
	d -= r.size.x
	return r.position + Vector2(0, r.size.y - d)


func _draw() -> void:
	# 地は塗らない: project の default_clear_color が卓の色(Kit.C_BG と同じ #121A2A。tests/test_ui.gd で確かめる)
	# マス目(盤の格子と揃える。4 マスごとに少し濃く)
	var x0 := floorf((view.position.x - B.GRID_X) / C)
	var x1 := ceilf((view.end.x - B.GRID_X) / C)
	for i in range(int(x0), int(x1) + 1):
		var x := B.GRID_X + i * C
		draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), Color(Kit.C_GRID, 0.55 if i % 4 == 0 else 0.28), 1.0)
	var y0 := floorf((view.position.y - B.GRID_Y) / C)
	var y1 := ceilf((view.end.y - B.GRID_Y) / C)
	for i in range(int(y0), int(y1) + 1):
		var y := B.GRID_Y + i * C
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), Color(Kit.C_GRID, 0.55 if i % 4 == 0 else 0.28), 1.0)
	_live.queue_redraw()
	if not demo:
		return
	for p in 2:
		for r: Array in LANDS[p]:
			_land(self, _cell_rect(r), p, 0.16)


func _draw_live() -> void:
	if not demo:
		return
	var ci := _live
	var t := float(_now()) / 1000.0
	for p in 2:
		var loops: Array = LOOPS[p]
		var cycle := B.DEMO_LOOP_S + B.DEMO_REST_S
		var n := int(floorf((t + p * 2.3) / cycle))
		var into := fposmod(t + p * 2.3, cycle)
		# 前の輪で取った所が薄れていく
		var prev := _cell_rect(loops[posmod(n - 1, loops.size())])
		var fade := clampf(1.0 - (into + B.DEMO_REST_S) / (cycle * 1.6), 0.0, 1.0)
		if fade > 0.0:
			_land(ci, prev, p, 0.3 * fade)
		var r := _cell_rect(loops[posmod(n, loops.size())])
		var k := clampf(into / B.DEMO_LOOP_S, 0.0, 1.0)
		if k >= 1.0:
			var lit := clampf(1.0 - (into - B.DEMO_LOOP_S) / B.DEMO_REST_S, 0.0, 1.0)
			_land(ci, r, p, 0.3)
			ci.draw_rect(r, Color(Kit.C_WHITE, 0.08 * lit))
			_head(ci, perimeter_point(r, 0.0), p)
			continue
		var pts := PackedVector2Array([r.position])
		var per := 2.0 * (r.size.x + r.size.y)
		for ck: float in [r.size.x / per, (r.size.x + r.size.y) / per, (2.0 * r.size.x + r.size.y) / per]:  # 通り過ぎた角
			if ck < k:
				pts.append(perimeter_point(r, ck))
		var head := perimeter_point(r, k)
		pts.append(head)
		var col := Color(Kit.C_TRAIL[p], 0.45)
		if p == 0:
			ci.draw_polyline(pts, col, 5.0, true)
		else:
			for s in pts.size() - 1:
				ci.draw_dashed_line(pts[s], pts[s + 1], col, 5.0, 5.0, false)
		_head(ci, head, p)


static func _land(ci: CanvasItem, r: Rect2, p: int, a: float) -> void:
	ci.draw_rect(r, Color(Kit.C_LAND[p], a))
	Kit.draw_pattern(ci, r, p, Color(Kit.C_TRAIL[p], a * 0.9), C)


static func _head(ci: CanvasItem, at: Vector2, p: int) -> void:
	Kit.draw_mark(ci, at, p, 16.0, Color(Kit.C_HEAD[p], 0.55))
