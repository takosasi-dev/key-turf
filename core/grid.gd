# 盤(仕様書 §9.1・§9.5)。マスごとの持ち主 owner と線 trail(0 = 無し、1 = P1、2 = P2)と、囲んだ所を求める計算。
# 囲んだ所を求めるのはこのファイルの capture_cells だけ(INV-5)。盤の番号は i = y × 48 + x。
extends RefCounted

const B := preload("res://core/balance.gd")

const W := B.GRID_W
const H := B.GRID_H
const N := W * H
const DX := [0, 1, 0, -1]  # 向き 0 上・1 右・2 下・3 左
const DY := [-1, 0, 1, 0]

var owner := PackedInt32Array()
var trail := PackedInt32Array()
var nb := PackedInt32Array()  # 隣の表: nb[i * 4 + d] は向き d へ 1 マス先(盤の外は -1)
var _seen := PackedInt32Array()
var _queue := PackedInt32Array()


func _init() -> void:
	owner.resize(N)
	trail.resize(N)
	_seen.resize(N)
	_queue.resize(N)
	nb.resize(N * 4)
	for i in N:
		for d in 4:
			nb[i * 4 + d] = step_from(i, d)
	reset()


# 初めの形: 2 人の 5×5 の陣地(§9.2)。P2 は P1 を盤の中心で 180 度回した位置。
func reset() -> void:
	owner.fill(0)
	trail.fill(0)
	var h := home_head(0)
	for y in range(h.y - B.HOME_HALF, h.y + B.HOME_HALF + 1):
		for x in range(h.x - B.HOME_HALF, h.x + B.HOME_HALF + 1):
			owner[idx(x, y)] = 1
			owner[idx(W - 1 - x, H - 1 - y)] = 2


static func home_head(p: int) -> Vector2i:
	return B.P1_HEAD if p == 0 else Vector2i(W - 1 - B.P1_HEAD.x, H - 1 - B.P1_HEAD.y)


static func idx(x: int, y: int) -> int:
	return y * W + x


static func inside(x: int, y: int) -> bool:
	return x >= 0 and x < W and y >= 0 and y < H


# 向き d へ 1 マス先の番号。盤の外なら -1。
@warning_ignore("integer_division")
static func step_from(i: int, d: int) -> int:
	var x: int = i % W + DX[d]
	var y: int = i / W + DY[d]
	return idx(x, y) if inside(x, y) else -1


func count(p: int) -> int:
	return owner.count(p + 1)


func trail_count(p: int) -> int:
	return trail.count(p + 1)


func trail_cells(p: int) -> Array[int]:
	var out: Array[int] = []
	for i in N:
		if trail[i] == p + 1:
			out.append(i)
	return out


# p が今囲んだら取るマスの番号の一覧(§9.5)。盤は書き換えない。
# p の線を仮に p の陣地とみなし、盤の外側(を 1 周する仮のマス)から、仮の p の陣地でないマスを 4 方向にたどる。
# 取るマス = p の線のマス + たどり着けなかった「仮の p の陣地でないマス」。
func capture_cells(p: int) -> Array[int]:
	var me := p + 1
	var ow := owner
	var tr := trail
	var nbt := nb
	var seen := _seen
	var q := _queue
	seen.fill(0)
	var head := 0
	var tail := 0
	for i in N:
		var x := i % W
		if (i < W or i >= N - W or x == 0 or x == W - 1) and ow[i] != me and tr[i] != me:
			seen[i] = 1
			q[tail] = i
			tail += 1
	while head < tail:
		var c := q[head]
		head += 1
		var k := c * 4
		for d in 4:
			var n := nbt[k + d]
			if n >= 0 and seen[n] == 0 and ow[n] != me and tr[n] != me:
				seen[n] = 1
				q[tail] = n
				tail += 1
	var out: Array[int] = []
	for i in N:
		if tr[i] == me or (ow[i] != me and seen[i] == 0):
			out.append(i)
	return out


# cells の持ち主を p にし、cells の中の線(どちらの線も)と p の線を全部消す。
func apply(p: int, cells: Array[int]) -> void:
	for i in cells:
		owner[i] = p + 1
		trail[i] = 0
	for i in N:
		if trail[i] == p + 1:
			trail[i] = 0
