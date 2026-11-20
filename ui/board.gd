# 盤の描画(仕様書 §9.1・§9.10・画面設計書 §3・§8)。sim.snapshot() の中身を描くだけ(INV-1)。
# 2 人は色・模様(P1 は点、P2 は斜線)・線(P1 は実線、P2 は破線)・頭(P1 は丸、P2 は四角)の 3 つで分ける(D-13・FR-28)。
# 囲んだ所の塗り・線の始まりの光・浮かぶ数字・決着の演出は、play が時刻(ms)を書き込み、ここで時刻から描く。光は全部 _flash() を通す。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Grid := preload("res://core/grid.gd")
const Kit := preload("res://ui/kit.gd")

const DIRS := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

var snap: Dictionary = {}
var reduce_flash := false
var now_ms := 0  # 描く時刻(テストが固定できるように持つ)
var draws := 0  # 描いた回数(smoke が読む)
var reveal := {}  # マス → [塗る時刻, 前の持ち主]
var glows: Array = []  # [時刻, マス]
var floats: Array = []  # [時刻, 位置, 文字, 大きいか, 人]
var rings: Array = []  # [時刻, 位置, 人](大きな囲み)
var end_fx: Dictionary = {}  # { at, reason, winner, point(決め手の位置 px) }


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


func clear_fx() -> void:
	reveal.clear()
	glows.clear()
	floats.clear()
	rings.clear()
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
	var at := center(head_cell) - Vector2(0, 22)
	at.y = maxf(at.y, B.GRID_Y + B.FLOAT_RISE_PX + 30.0)  # 上の端の近くでも、浮かんだ数字が盤の外の札に重ならない
	floats.append([t, at, S.PLUS % int(e["count"]), big, p])
	if big:
		rings.append([t, center(head_cell), p])


func on_trail_start(cell: int) -> void:
	glows.append([_now(), cell])


# 決着(§9.10)。決め手の位置: 線を切った・時間切れは勝った頭、自分の線・囲んだ・陣地が 0 は負けた頭、引き分けは 2 つの頭の間。
func on_round_end(winner: int, reason: int, heads: Array = []) -> void:
	var point := Vector2(640, 384)
	var sparks: Array = []
	if heads.size() == 2:
		var a := center(int(heads[0]))
		var b := center(int(heads[1]))
		if winner < 0:
			point = (a + b) / 2.0
			sparks = [a, b] if reason == Sim.REASON_BOTH else [point]  # 相打ちは頭が離れていることがあるので、両方の頭で光る
		elif reason == Sim.REASON_CUT or reason == Sim.REASON_TIME:
			point = a if winner == 0 else b
		else:
			point = b if winner == 0 else a
	end_fx = {"at": _now(), "winner": winner, "reason": reason, "point": point, "sparks": sparks if not sparks.is_empty() else [point]}


func _flash(a: float) -> float:
	return minf(a, B.REDUCED_FLASH_ALPHA) if reduce_flash else a


# 1 マスの番号から決まる 0〜1 の値(欠片の向きをばらけさせる。乱数は使わない)。
static func _hash01(i: int, salt: int) -> float:
	return float(((i + 1) * 2654435761 + salt * 40503) & 0xFFFF) / 65535.0


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
	var ef_point: Vector2 = end_fx.get("point", Vector2.ZERO)
	var loser := 1 - ef_winner if ef_winner >= 0 else -1
	# 盤の地とマス目
	var board := Rect2(B.GRID_X, B.GRID_Y, Grid.W * B.CELL, Grid.H * B.CELL)
	for x in range(1, Grid.W):
		draw_line(Vector2(B.GRID_X + x * B.CELL, B.GRID_Y), Vector2(B.GRID_X + x * B.CELL, board.end.y), Kit.C_GRID, 1.0)
	for y in range(1, Grid.H):
		draw_line(Vector2(B.GRID_X, B.GRID_Y + y * B.CELL), Vector2(board.end.x, B.GRID_Y + y * B.CELL), Kit.C_GRID, 1.0)
	# 陣地(塗っている途中のマスは前の持ち主で描く。塗られた瞬間に白く光り、光の波が線の側から奥へ進む)
	var glow_land := -1
	if ef_reason == Sim.REASON_TIME and ef_age >= 0 and ef_age < B.END_FX_MS:
		glow_land = ef_winner + 1
	for i in Grid.N:
		var o := owner_arr[i]
		var lit := 0.0
		if reveal.has(i):
			var rv: Array = reveal[i]
			var since := now - int(rv[0])
			if since < 0:
				o = int(rv[1])
			elif since > maxi(B.FILL_MS, B.FILL_FLASH_MS):
				reveal.erase(i)
			if since >= 0 and since < B.FILL_FLASH_MS:
				lit = 1.0 - float(since) / B.FILL_FLASH_MS
		if o == 0:
			continue
		var r := cell_rect(i)
		draw_rect(r, Kit.C_LAND[o - 1])
		var pc: Color = Color(Kit.C_TRAIL[o - 1], 0.55)
		if o == 1:
			draw_circle(r.get_center(), 2.5, pc, true, -1.0, true)
		else:
			draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), pc, 1.5, true)
		if lit > 0.0:
			draw_rect(r, Color(Kit.C_WHITE, _flash(B.FILL_FLASH_ALPHA * lit)))
		if o == glow_land:
			draw_rect(r, Color(Kit.C_WHITE, _flash(0.35 * (1.0 - float(ef_age) / B.END_FX_MS))))
	draw_rect(board, Kit.C_EDGE, false, 2.0)
	# 線
	for i in Grid.N:
		var v := trail_arr[i]
		if v == 0:
			continue
		var p := v - 1
		var a := center(i)
		if p == loser and ef_reason == Sim.REASON_CUT and ef_age >= 0:
			# 切られた線: 白く光り、切った点から近い順に割れて、欠片が飛んで消える
			var brk := B.CUT_BREAK_MS + a.distance_to(ef_point) * B.CUT_WAVE_MS_PER_PX
			if ef_age >= brk:
				_fragments(i, a, ef_point, (ef_age - brk) / B.CUT_FLY_MS, Kit.C_TRAIL[p])
				continue
		var col: Color = Kit.C_TRAIL[p]
		if p == loser and ef_reason == Sim.REASON_SELF and ef_age >= 0 and ef_age < B.END_FX_MS:
			if (ef_age / 150) % 2 == 0 and ef_age < 600:
				col = Kit.C_RED if not reduce_flash else col.lerp(Kit.C_RED, 0.2)  # 赤く 2 回点滅
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
	# 大きな囲みの輪
	rings = rings.filter(func(g: Array) -> bool: return now - int(g[0]) < B.RING_MS)
	for g: Array in rings:
		var k := float(now - int(g[0])) / B.RING_MS
		var grown := 1.0 - (1.0 - k) * (1.0 - k)
		draw_circle(g[1], 12.0 + B.RING_PX * grown, Color(Kit.C_TRAIL[int(g[2])], _flash(0.9 * (1.0 - k))), false, 4.0 * (1.0 - k) + 1.0, true)
	# 頭と向きの矢印。負けた頭は灰色へ寄せ、勝った頭からは輪が広がる
	for p in 2:
		var c := center(int(heads[p]))
		var size := B.HEAD_PX
		var col: Color = Kit.C_HEAD[p]
		if p == loser and ef_age >= 0:
			col = col.lerp(Kit.C_DIM, B.LOSER_DIM * minf(1.0, float(ef_age) / B.FILL_MS))
			if ef_reason == Sim.REASON_ENCLOSE:
				size *= maxf(0.0, 1.0 - float(ef_age) / B.END_FX_MS)  # 囲まれた頭は縮んで消える
				if size <= 0.0:
					continue
		if p == ef_winner and ef_age >= 0 and ef_age < B.RING_MS * 2:
			for w in 2:
				var k := float(ef_age - w * B.RING_MS / 2) / B.RING_MS
				if k >= 0.0 and k < 1.0:
					draw_circle(c, 14.0 + 34.0 * k, Color(Kit.C_TRAIL[p], _flash(0.8 * (1.0 - k))), false, 3.0, true)
		if p == 0:
			draw_circle(c, size / 2.0 + 2.0, Kit.C_BG, true, -1.0, true)
			draw_circle(c, size / 2.0, col, true, -1.0, true)
		else:
			draw_rect(Rect2(c - Vector2(size / 2.0 + 2.0, size / 2.0 + 2.0), Vector2(size + 4.0, size + 4.0)), Kit.C_BG)
			draw_rect(Rect2(c - Vector2(size / 2.0, size / 2.0), Vector2(size, size)), col)
		var q: Array = snap["queues"][p]
		var d: int = q.back() if not q.is_empty() else int(snap["dirs"][p])
		var above := c.y - 20.0 > B.GRID_Y
		_arrow(c + Vector2(0, -20 if above else 20), d, col)  # 一番上の行では頭の下に出す(盤の外の札に重ねない)
	# 切った点・自分の線に入った点の × 印
	if (ef_reason == Sim.REASON_CUT or ef_reason == Sim.REASON_SELF) and ef_age >= 0 and ef_age < B.MARK_MS:
		var k := float(ef_age) / B.MARK_MS
		var grow := minf(1.0, k * 4.0)
		var mc: Color = Kit.C_WHITE if ef_reason == Sim.REASON_CUT else Kit.C_RED
		var mcol := Color(mc, _flash(1.0 - k * k))
		for v: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			draw_line(ef_point - v * 18.0 * grow, ef_point + v * 18.0 * grow, mcol, 4.0, true)
		draw_circle(ef_point, 10.0 + 26.0 * k, Color(mc, _flash(0.7 * (1.0 - k))), false, 2.0, true)
	# 正面衝突・相打ちの火花
	if (ef_reason == Sim.REASON_HEADON or ef_reason == Sim.REASON_BOTH) and ef_age >= 0 and ef_age < B.END_FX_MS:
		var k := float(ef_age) / B.END_FX_MS
		for at: Vector2 in end_fx.get("sparks", [ef_point]):
			for n in 12:
				var v := Vector2.RIGHT.rotated(TAU * n / 12.0)
				var len_k := 1.0 if n % 2 == 0 else 0.6
				draw_line(at + v * (6.0 + 30.0 * k), at + v * (6.0 + (14.0 + 34.0 * len_k) * (0.3 + k)), Color(Kit.C_WARN, _flash(1.0 - k)), 3.0, true)
	# 浮かぶ数字(人の色・縁取り。出た瞬間に大きく、すぐ戻る)
	floats = floats.filter(func(f: Array) -> bool: return now - int(f[0]) < B.FLOAT_MS)
	for f: Array in floats:
		var age := now - int(f[0])
		var k := float(age) / B.FLOAT_MS
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - float(age) / B.FLOAT_POP_MS)
		var fs := int(26 * (B.BIG_SCALE if f[3] else 1.0) * pop)
		var pos: Vector2 = f[1] - Vector2(100, B.FLOAT_RISE_PX * k)
		var alpha := 1.0 - k * k
		draw_string_outline(Kit.font(800), pos, f[2], HORIZONTAL_ALIGNMENT_CENTER, 200, fs, 6, Color(Kit.C_BG, alpha))
		draw_string(Kit.font(800), pos, f[2], HORIZONTAL_ALIGNMENT_CENTER, 200, fs, Color(Kit.C_TRAIL[int(f[4])].lerp(Kit.C_WHITE, 0.25), alpha))


# 切られた線の 1 マスぶんの欠片 2 つ。切った点から外へ飛び、落ちながら小さくなって消える。
func _fragments(i: int, at: Vector2, from: Vector2, k: float, col: Color) -> void:
	if k >= 1.0:
		return
	var out := (at - from).normalized() if at.distance_to(from) > 0.5 else Vector2.UP
	for n in 2:
		var v := out.rotated((_hash01(i, n) - 0.5) * 2.4)
		var pos := at + v * B.CUT_FLY_PX * (0.4 + _hash01(i, n + 7)) * k + Vector2(0, 30.0 * k * k)
		var s := 7.0 * (1.0 - k)
		draw_rect(Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s)), Color(col.lerp(Kit.C_WHITE, 0.4), 1.0 - k))


func _trail_seg(a: Vector2, b: Vector2, col: Color, p: int) -> void:
	if p == 0:
		draw_line(a, b, col, B.TRAIL_PX, true)
	else:
		draw_dashed_line(a, b, col, B.TRAIL_PX, 6.0, false)


# 向き d を指す小さな三角。
func _arrow(at: Vector2, d: int, col: Color) -> void:
	var v: Vector2 = DIRS[d]
	var n := Vector2(-v.y, v.x)
	draw_colored_polygon(PackedVector2Array([at + v * 7.0, at - v * 5.0 + n * 6.0, at - v * 5.0 - n * 6.0]), col)
