# 1 ラウンドの全状態と step()(仕様書 §9.3・§9.4・§9.6)。入力は queue_turn(人, 向き) の整数だけ(INV-4)。
# 2 人は同じ step で同時に動き、負けは 2 人ぶんを同じ盤で求めてからまとめて当てる(D-7・INV-3。P1 を先に処理する所を作らない)。
# ui は snapshot() と events() を読むだけ(INV-1)。CPU の向きは移動の前に cpus[p].decide(self) で決める。
extends RefCounted

const B := preload("res://core/balance.gd")
const Grid := preload("res://core/grid.gd")
const Cpu := preload("res://core/cpu.gd")

const MODE_DUO := 0
const MODE_EASY := 1
const MODE_NORMAL := 2

const PHASE_COUNT := 0
const PHASE_MOVE := 1
const PHASE_OVER := 2

# 理由。数が小さいほど §9.6 の表で上(1 人に理由が 2 つ出た時は小さい方)
const REASON_CUT := 0  # 線を切った
const REASON_SELF := 1  # 自分の線
const REASON_ENCLOSE := 2  # 囲んだ
const REASON_ZERO := 3  # 陣地が 0
const REASON_HEADON := 4  # 正面衝突
const REASON_BOTH := 5  # 相打ち
const REASON_TIME := 6  # 時間切れ(広さ)
const REASON_TIE := 7  # 時間切れ(同じ広さ)

var mode := MODE_DUO
var round_ticks := B.ROUND_TICKS
var grid: Grid
var heads: Array[int] = [0, 0]  # 頭のマスの番号
var dirs: Array[int] = [1, 3]
var queues: Array = [[], []]  # 予約(QUEUE_MAX まで)
var cpus: Array = [null, null]  # CPU が動かす人の Cpu(人なら null)
var phase := PHASE_COUNT
var count_tick := 0
var move_tick := 0
var remaining := 0
var step_no := 0
var winner := -1
var reason := -1
var _events: Array = []


func _init(p_mode: int = MODE_DUO, p_round_ticks: int = B.ROUND_TICKS, cpu_seed: int = 1) -> void:
	mode = p_mode
	round_ticks = p_round_ticks
	remaining = p_round_ticks
	grid = Grid.new()
	for p in 2:
		var h := Grid.home_head(p)
		heads[p] = Grid.idx(h.x, h.y)
	if mode != MODE_DUO:
		cpus[1] = Cpu.new(1, mode, cpu_seed)


# 予約(§9.4 の 1)。予約の最後(空なら今の向き)と同じ・逆の向きと、QUEUE_MAX を超えた物は捨てて偽を返す。
func queue_turn(p: int, d: int) -> bool:
	if phase == PHASE_OVER or p < 0 or p > 1 or d < 0 or d > 3:
		return false
	var q: Array = queues[p]
	var last: int = q.back() if not q.is_empty() else dirs[p]
	if d == last or d == (last + 2) % 4 or q.size() >= B.QUEUE_MAX:
		return false
	q.append(d)
	return true


func step() -> void:
	_events.clear()
	if phase == PHASE_OVER:
		return
	step_no += 1
	if phase == PHASE_COUNT:
		count_tick += 1
		if count_tick >= B.COUNTDOWN_TICKS:
			phase = PHASE_MOVE
			_events.append({"type": "go"})
		return
	move_tick += 1
	if move_tick >= B.MOVE_TICKS:
		move_tick = 0
		for p in 2:
			if cpus[p] != null:
				queues[p] = [cpus[p].decide(self)]  # 出た向き 1 つだけを予約にする(§9.3 の 3)
		_move()
		if phase == PHASE_OVER:
			return
	remaining -= 1
	if remaining <= 0:
		var c0 := grid.count(0)
		var c1 := grid.count(1)
		if c0 == c1:
			_end(-1, REASON_TIE)
		else:
			_end(0 if c0 > c1 else 1, REASON_TIME)


# 移動 1 回ぶん(§9.4)。
func _move() -> void:
	var nxt: Array[int] = [heads[0], heads[1]]
	var moving: Array[bool] = [false, false]
	for p in 2:
		var q: Array = queues[p]
		if not q.is_empty():
			dirs[p] = q.pop_front()
		var n := grid.nb[heads[p] * 4 + dirs[p]]
		if n >= 0:  # 盤の外なら、この回は動かない(D-5)
			nxt[p] = n
			moving[p] = true
	# 正面衝突(§9.4 の 3)
	var headon := false
	if moving[0] and moving[1]:
		headon = nxt[0] == nxt[1] or (nxt[0] == heads[1] and nxt[1] == heads[0])
	else:
		for p in 2:
			var o := 1 - p
			if moving[p] and not moving[o] and nxt[p] == heads[o] and grid.trail[heads[o]] != o + 1:
				headon = true
	if headon:
		_end(-1, REASON_HEADON)
		return
	# 負け(動かす前の盤で見る。§9.4 の 4)
	var lose: Array[int] = [-1, -1]
	for p in 2:
		if moving[p]:
			var t := grid.trail[nxt[p]]
			if t == p + 1:
				_lose(lose, p, REASON_SELF)
			elif t == 2 - p:
				_lose(lose, 1 - p, REASON_CUT)
	var was_inside: Array[bool] = [grid.owner[heads[0]] == 1, grid.owner[heads[1]] == 2]
	heads = nxt
	if lose[0] >= 0 or lose[1] >= 0:
		_decide(lose)
		return
	# 線(§9.4 の 6 の 2)
	for p in 2:
		if moving[p] and grid.owner[heads[p]] != p + 1:
			grid.trail[heads[p]] = p + 1
			if was_inside[p]:
				_events.append({"type": "trail_start", "p": p, "cell": heads[p]})
	# 囲み(§9.5)。2 人ぶんを、どちらも塗る前の盤で求める
	var caps: Array = [null, null]
	for p in 2:
		if grid.owner[heads[p]] == p + 1 and grid.trail_count(p) > 0:
			caps[p] = grid.capture_cells(p)
	for p in 2:
		if caps[p] != null:
			var o := 1 - p
			for c: int in caps[p]:
				if c == heads[o] or grid.trail[c] == o + 1:
					_lose(lose, o, REASON_ENCLOSE)
					break
	if lose[0] >= 0 or lose[1] >= 0:
		if lose[0] < 0 or lose[1] < 0:
			var w := 0 if lose[1] >= 0 else 1
			if caps[w] != null:
				_paint(w, caps[w])  # 勝った人の取るマスは、塗ってから終わる
		_decide(lose)
		return
	# 重なったマスは持ち主を変えない(重なりに線は無い: あれば上で負けが出ている)
	var paint: Array = [caps[0], caps[1]]
	if caps[0] != null and caps[1] != null:
		var in1 := {}
		for c: int in caps[1]:
			in1[c] = true
		var in0 := {}
		for c: int in caps[0]:
			in0[c] = true
		paint[0] = (caps[0] as Array[int]).filter(func(c: int) -> bool: return not in1.has(c))
		paint[1] = (caps[1] as Array[int]).filter(func(c: int) -> bool: return not in0.has(c))
	for p in 2:
		if paint[p] != null:
			_paint(p, paint[p])
	for p in 2:
		if grid.count(p) == 0:
			_lose(lose, p, REASON_ZERO)
	if lose[0] >= 0 or lose[1] >= 0:
		_decide(lose)


func _paint(p: int, cells: Array) -> void:
	var typed: Array[int] = []
	typed.assign(cells)
	grid.apply(p, typed)
	_events.append({"type": "capture", "p": p, "count": typed.size(), "cells": typed})


static func _lose(lose: Array[int], p: int, why: int) -> void:
	if lose[p] < 0 or why < lose[p]:
		lose[p] = why


func _decide(lose: Array[int]) -> void:
	if lose[0] >= 0 and lose[1] >= 0:
		_end(-1, REASON_BOTH)
	else:
		var loser := 0 if lose[0] >= 0 else 1
		_end(1 - loser, lose[loser])


func _end(w: int, why: int) -> void:
	phase = PHASE_OVER
	winner = w
	reason = why
	_events.append({"type": "round_end", "winner": w, "reason": why})


func events() -> Array:
	return _events


func is_over() -> bool:
	return phase == PHASE_OVER


func result() -> Dictionary:
	return {"winner": winner, "reason": reason, "counts": [grid.count(0), grid.count(1)]}


func snapshot() -> Dictionary:
	return {
		"owner": grid.owner.duplicate(), "trail": grid.trail.duplicate(),
		"heads": heads.duplicate(), "dirs": dirs.duplicate(), "queues": [queues[0].duplicate(), queues[1].duplicate()],
		"counts": [grid.count(0), grid.count(1)], "remaining": remaining, "round_ticks": round_ticks,
		"phase": phase, "count_tick": count_tick, "mode": mode,
	}
