# 盤の描画(仕様書 §9.1・§9.10・画面設計書 §3・§8)。sim.snapshot() の中身を描くだけ(INV-1)。
# 2 人は色・模様(P1 は点、P2 は斜線)・線(P1 は実線、P2 は破線)・頭(P1 は丸、P2 は四角)の 3 つで分ける(D-13・FR-28)。
# 囲んだ所の塗り・線の始まりの光・浮かぶ数字・決着の演出は、play が時刻(ms)を書き込み、ここで時刻から描く。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Grid := preload("res://core/grid.gd")
const Kit := preload("res://ui/kit.gd")

var snap: Dictionary = {}
var reduce_flash := false
var now_ms := 0  # 描く時刻(テストが固定できるように持つ)
var draws := 0  # 描いた回数(smoke が読む)
var reveal := {}  # マス → [塗る時刻, 前の持ち主]
var glows: Array = []  # [時刻, マス]
var floats: Array = []  # [時刻, 位置, 文字, 大きいか]
var end_fx: Dictionary = {}  # { at, reason, winner, heads }


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


func clear_fx() -> void:
	reveal.clear()
	glows.clear()
	floats.clear()
	end_fx = {}


@warning_ignore("integer_division")
static func cell_rect(i: int) -> Rect2:
	return Rect2(B.GRID_X + (i % Grid.W) * B.CELL, B.GRID_Y + (i / Grid.W) * B.CELL, B.CELL, B.CELL)


static func center(i: int) -> Vector2:
	return cell_rect(i).get_center()


# 囲んだ(§9.10): 取ったマスを、線の側から順に FILL_MS で塗る。前の盤(snap)の線から幅優先で段を数える。
@warning_ignore("integer_division")
func on_capture(e: Dictionary, head_cell: int, big: bool) -> void:
	var t := _now()
	var cells: Array = e["cells"]
	var p: int = e["p"]
	var inset := {}
	for c: int in cells:
		inset[c] = -1
	var front: Array = []
	var old_trail: PackedInt32Array = snap.get("trail", PackedInt32Array())
	var old_owner: PackedInt32Array = snap.get("owner", PackedInt32Array())
	for c: int in cells:
		if old_trail.size() > c and old_trail[c] == p + 1:
			inset[c] = 0
			front.append(c)
	if front.is_empty() and not cells.is_empty():
		inset[cells[0]] = 0
		front.append(cells[0])
	var layer := 0
	while not front.is_empty():
		var nxt: Array = []
		for c: int in front:
			for d in 4:
				var n := Grid.step_from(c, d)
				if n >= 0 and inset.has(n) and int(inset[n]) < 0:
					inset[n] = layer + 1
					nxt.append(n)
		front = nxt
		if not nxt.is_empty():
			layer += 1
	for c: int in cells:
		var prev := old_owner[c] if old_owner.size() > c else 0
		reveal[c] = [t + B.FILL_MS * maxi(int(inset[c]), 0) / maxi(layer, 1), prev]
	floats.append([t, center(head_cell) - Vector2(0, 22), S.PLUS % int(e["count"]), big])


func on_trail_start(cell: int) -> void:
	glows.append([_now(), cell])


func on_round_end(winner: int, reason: int) -> void:
	end_fx = {"at": _now(), "winner": winner, "reason": reason}


func _flash(a: float) -> float:
	return minf(a, B.REDUCED_FLASH_ALPHA) if reduce_flash else a


@warning_ignore("integer_division")
func _draw() -> void:
	draws += 1
	if snap.is_empty():
		return
	var now := _now()
	var owner_arr: PackedInt32Array = snap["owner"]
	var trail_arr: PackedInt32Array = snap["trail"]
	var heads: Array = snap["heads"]
	var ef_age := now - int(end_fx.get("at", -100000))
	var ef_reason: int = end_fx.get("reason", -1)
	var ef_winner: int = end_fx.get("winner", -1)
	var loser := 1 - ef_winner if ef_winner >= 0 else -1
	# 盤の地とマス目
	var board := Rect2(B.GRID_X, B.GRID_Y, Grid.W * B.CELL, Grid.H * B.CELL)
	for x in range(1, Grid.W):
		draw_line(Vector2(B.GRID_X + x * B.CELL, B.GRID_Y), Vector2(B.GRID_X + x * B.CELL, board.end.y), Kit.C_GRID, 1.0)
	for y in range(1, Grid.H):
		draw_line(Vector2(B.GRID_X, B.GRID_Y + y * B.CELL), Vector2(board.end.x, B.GRID_Y + y * B.CELL), Kit.C_GRID, 1.0)
	# 陣地(塗っている途中のマスは前の持ち主で描く)
	var glow_land := -1
	if ef_reason == Sim.REASON_TIME and ef_age >= 0 and ef_age < B.END_FX_MS:
		glow_land = ef_winner + 1
	for i in Grid.N:
		var o := owner_arr[i]
		if reveal.has(i):
			var rv: Array = reveal[i]
			if now < int(rv[0]):
				o = int(rv[1])
			elif now - int(rv[0]) > B.FILL_MS:
				reveal.erase(i)
		if o == 0:
			continue
		var r := cell_rect(i)
		draw_rect(r, Kit.C_LAND[o - 1])
		var pc: Color = Color(Kit.C_TRAIL[o - 1], 0.55)
		if o == 1:
			draw_circle(r.get_center(), 2.5, pc, true, -1.0, true)
		else:
			draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), pc, 1.5, true)
		if o == glow_land:
			draw_rect(r, Color(Kit.C_WHITE, _flash(0.35 * (1.0 - float(ef_age) / B.END_FX_MS))))
	draw_rect(board, Kit.C_EDGE, false, 2.0)
	# 線
	for i in Grid.N:
		var v := trail_arr[i]
		if v == 0:
			continue
		var p := v - 1
		if p == loser and ef_reason == Sim.REASON_CUT and ef_age >= B.END_FX_MS / 2:
			continue  # 切られた線は光って消える
		var col: Color = Kit.C_TRAIL[p]
		if p == loser and ef_reason == Sim.REASON_SELF and ef_age >= 0 and ef_age < B.END_FX_MS:
			if (ef_age / 150) % 2 == 0 and ef_age < 600:
				col = Kit.C_RED if not reduce_flash else col.lerp(Kit.C_RED, 0.2)  # 赤く 2 回点滅
		var a := center(i)
		var linked := false
		for d in [1, 2]:
			var n := Grid.step_from(i, d)
			if n >= 0 and trail_arr[n] == v:
				_trail_seg(a, center(n), col, p)
				linked = true
		if not linked:
			var up := Grid.step_from(i, 0)
			var left := Grid.step_from(i, 3)
			linked = (up >= 0 and trail_arr[up] == v) or (left >= 0 and trail_arr[left] == v)
		if not linked:
			draw_rect(Rect2(a - Vector2(4, 4), Vector2(8, 8)), col)
		if p == 0:
			draw_circle(a, B.TRAIL_PX / 2.0, col, true, -1.0, true)
		if p == loser and ef_reason == Sim.REASON_CUT and ef_age >= 0 and ef_age < B.END_FX_MS:
			draw_rect(cell_rect(i), Color(Kit.C_WHITE, _flash(0.9 * (1.0 - float(ef_age) / B.END_FX_MS))))
	# 線の始まりの光
	glows = glows.filter(func(g: Array) -> bool: return now - int(g[0]) < B.TRAIL_GLOW_MS)
	for g: Array in glows:
		var k := float(now - int(g[0])) / B.TRAIL_GLOW_MS
		draw_circle(center(int(g[1])), 6.0 + 14.0 * k, Color(Kit.C_WHITE, _flash(0.6 * (1.0 - k))), false, 2.0, true)
	# 頭と向きの矢印
	for p in 2:
		var c := center(int(heads[p]))
		var size := B.HEAD_PX
		if p == loser and ef_reason == Sim.REASON_ENCLOSE and ef_age >= 0:
			size *= maxf(0.0, 1.0 - float(ef_age) / B.END_FX_MS)  # 囲まれた頭は縮んで消える
			if size <= 0.0:
				continue
		if p == 0:
			draw_circle(c, size / 2.0 + 2.0, Kit.C_BG, true, -1.0, true)
			draw_circle(c, size / 2.0, Kit.C_HEAD[0], true, -1.0, true)
		else:
			draw_rect(Rect2(c - Vector2(size / 2.0 + 2.0, size / 2.0 + 2.0), Vector2(size + 4.0, size + 4.0)), Kit.C_BG)
			draw_rect(Rect2(c - Vector2(size / 2.0, size / 2.0), Vector2(size, size)), Kit.C_HEAD[1])
		var q: Array = snap["queues"][p]
		var d: int = q.back() if not q.is_empty() else int(snap["dirs"][p])
		_arrow(c + Vector2(0, -20), d, Kit.C_HEAD[p])
	# 正面衝突・相打ちの火花
	if (ef_reason == Sim.REASON_HEADON or ef_reason == Sim.REASON_BOTH) and ef_age >= 0 and ef_age < B.END_FX_MS:
		var mid := (center(int(heads[0])) + center(int(heads[1]))) / 2.0
		var k := float(ef_age) / B.END_FX_MS
		for v: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7)]:
			draw_line(mid + v * (6.0 + 30.0 * k), mid + v * (14.0 + 40.0 * k), Color(Kit.C_WARN, _flash(1.0 - k)), 3.0, true)
	# 浮かぶ数字
	floats = floats.filter(func(f: Array) -> bool: return now - int(f[0]) < B.FLOAT_MS)
	for f: Array in floats:
		var k := float(now - int(f[0])) / B.FLOAT_MS
		var fs := int(26 * (B.BIG_SCALE if f[3] else 1.0))
		draw_string(Kit.font(800), f[1] - Vector2(100, B.FLOAT_RISE_PX * k), f[2], HORIZONTAL_ALIGNMENT_CENTER, 200, fs, Color(Kit.C_TEXT, 1.0 - k * k))


func _trail_seg(a: Vector2, b: Vector2, col: Color, p: int) -> void:
	if p == 0:
		draw_line(a, b, col, B.TRAIL_PX, true)
	else:
		draw_dashed_line(a, b, col, B.TRAIL_PX, 6.0, false)


# 向き d を指す小さな三角。
func _arrow(at: Vector2, d: int, col: Color) -> void:
	var v: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][d]
	var n := Vector2(-v.y, v.x)
	draw_colored_polygon(PackedVector2Array([at + v * 7.0, at - v * 5.0 + n * 6.0, at - v * 5.0 - n * 6.0]), col)
