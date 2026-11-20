# CPU の向きの決め方(仕様書 §9.8)。decide(sim) を移動の前に 1 回呼び、次に進む向きを返す。
# 計画は「d1 へ陣地を出て a マス → d2 へ b マス → 陣地まで戻る」。危ない時・道が無い時は戻る。ふつう は相手の線を切りに行く。
# 仕様書は P2 だけを書くが、テストで P1 にも付けられるように人の番号 p を持つ(AC-15・AC-16)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Grid := preload("res://core/grid.gd")
const Rng := preload("res://core/rng.gd")

const EASY := 1
const NORMAL := 2
const INF := 1 << 30
const URDL := [0, 1, 2, 3]  # 同じ時は 上・右・下・左 の順

var p := 1
var level := EASY
var rng: Rng
var plan := {}  # { d1, d2, a, b, home }。home は「戻る」に切り替えた印
var _was_out := false
var _home := PackedInt32Array()  # 自分の陣地までの歩数(自分の線は通れない)
var _opp_home := PackedInt32Array()  # 相手の陣地までの歩数(相手の線は通れない)
var _to_trail := PackedInt32Array()  # 相手の線までの歩数(自分の線は通れない)
var _queue := PackedInt32Array()
var _avoid := PackedInt32Array()  # 攻めの道で通らないマス(1)


func _init(p_player: int, p_level: int, p_seed: int) -> void:
	p = p_player
	level = p_level
	var s := (p_seed ^ B.CPU_RNG_XOR) & Rng.MASK
	rng = Rng.new(s if s != 0 else 1)
	_home.resize(Grid.N)  # Packed の配列は値で渡るので、1 つずつ広げる
	_opp_home.resize(Grid.N)
	_to_trail.resize(Grid.N)
	_queue.resize(Grid.N)
	_avoid.resize(Grid.N)


@warning_ignore("integer_division")
func decide(sim: RefCounted) -> int:
	var g: Grid = sim.grid
	var me := p + 1
	var o := 1 - p
	var head: int = sim.heads[p]
	var dir: int = sim.dirs[p]
	var inside := g.owner[head] == me
	var tc := g.trail_count(p)
	_field(g, g.owner, me, me, _home)
	var t := 0 if inside else _via(g, head, me, _home)
	if plan.is_empty() or (inside and tc == 0 and (_was_out or plan["home"] or _leg(tc) == 3)):
		_make_plan(g, head)
	_was_out = not inside
	# e: 相手の頭から自分の線のどれかまでのマンハッタン距離
	var e := INF
	if tc > 0:
		var oh: int = sim.heads[o]
		var tr := g.trail
		var i := tr.find(me)
		while i >= 0:
			e = mini(e, absi(i % Grid.W - oh % Grid.W) + absi(i / Grid.W - oh / Grid.W))
			i = tr.find(me, i + 1)
	var margin := B.EASY_MARGIN if level == EASY else B.NORMAL_MARGIN
	var fired := false
	var leg := _leg(tc)
	if e <= t + margin:
		fired = true
	elif not plan["home"] and leg < 3:
		var n := g.nb[head * 4 + (plan["d1"] if leg == 1 else plan["d2"])]
		if n < 0 or g.trail[n] == me or _home[n] >= INF:
			fired = true
	if fired:
		plan["home"] = true
	var want := -1
	if not fired and level == NORMAL and g.trail_count(o) > 0:
		want = _attack(g, sim, head, me, o)
	if want < 0:
		if plan["home"] or leg == 3:
			want = _step_toward(g, head, me, _home, t)
			if want < 0:
				want = _any_open(g, head, me, dir)
		else:
			want = plan["d1"] if leg == 1 else plan["d2"]
	if want == (dir + 2) % 4:  # 逆へは曲がれない: 直角の 2 つのうち通れる物を 上・右・下・左 の順で
		want = dir
		for d: int in URDL:
			if d % 2 != dir % 2 and _open(g, head, d, me):
				want = d
				break
	return want


func _leg(tc: int) -> int:
	if plan.is_empty():
		return 1
	if tc < plan["a"]:
		return 1
	if tc < plan["a"] + plan["b"]:
		return 2
	return 3


func _make_plan(g: Grid, head: int) -> void:
	var me := p + 1
	var best := -1
	var ties: Array[int] = []
	for d: int in URDL:
		var n := 0
		var c := head
		for k in B.CPU_LOOK:
			c = g.nb[c * 4 + d]
			if c < 0:
				break
			if g.owner[c] != me:
				n += 1
		if n > best:
			best = n
			ties = [d]
		elif n == best:
			ties.append(d)
	var d1: int = ties[rng.next_int(ties.size())]
	var d2: int = [(d1 + 1) % 4, (d1 + 3) % 4][rng.next_int(2)]
	var ra: Array = B.EASY_A if level == EASY else B.NORMAL_A
	var rb: Array = B.EASY_B if level == EASY else B.NORMAL_B
	var a := rng.pick_range(ra)
	var b := rng.pick_range(rb)
	plan = {"d1": d1, "d2": d2, "a": a, "b": b, "home": false}


# ふつう だけ: 相手の線までの歩数 c が、相手が陣地へ戻る歩数 − ATTACK_MARGIN 以下なら、そこへの道の向き。無ければ -1。
# 相手の頭のマスと、相手の頭が次に入りうるマス(頭の前と左右)は、的からも道からも外す
# (2026-11-20 の依頼者の判断。直進する相手に正面からぶつかって引き分け・負けになっていた)。
func _attack(g: Grid, sim: RefCounted, head: int, me: int, o: int) -> int:
	var oh: int = sim.heads[o]
	_avoid.fill(0)
	_avoid[oh] = 1
	var back := (int(sim.dirs[o]) + 2) % 4
	for d in 4:
		var n := g.nb[oh * 4 + d]
		if d != back and n >= 0:
			_avoid[n] = 1
	_field(g, g.trail, o + 1, me, _to_trail, _avoid)
	var c := _via(g, head, me, _to_trail)
	if c >= INF:
		return -1
	_field(g, g.owner, o + 1, o + 1, _opp_home)
	var ot := 0 if g.owner[oh] == o + 1 else _via(g, oh, o + 1, _opp_home)
	if c > ot - B.ATTACK_MARGIN:
		return -1
	return _step_toward(g, head, me, _to_trail, c)


# 歩数の表で、頭から 1 歩で dist − 1 になる向き(上・右・下・左 の順で先の物)。無ければ -1。
func _step_toward(g: Grid, head: int, me: int, dist: PackedInt32Array, steps: int) -> int:
	if steps <= 0 or steps >= INF:
		return -1
	for d: int in URDL:
		var n := g.nb[head * 4 + d]
		if n >= 0 and g.trail[n] != me and dist[n] == steps - 1:
			return d
	return -1


# 通れる隣のマス(上・右・下・左 の順)。無ければ今の向き。
func _any_open(g: Grid, head: int, me: int, dir: int) -> int:
	for d: int in URDL:
		if d != (dir + 2) % 4 and _open(g, head, d, me):
			return d
	return dir


static func _open(g: Grid, head: int, d: int, me: int) -> bool:
	var n := g.nb[head * 4 + d]
	return n >= 0 and g.trail[n] != me


# 頭のマスの歩数 = 通れる隣の歩数の最小 + 1(頭のマスは自分の線のことがあるので、隣から求める)。
func _via(g: Grid, head: int, me: int, dist: PackedInt32Array) -> int:
	var best := INF
	for d in 4:
		var n := g.nb[head * 4 + d]
		if n >= 0 and g.trail[n] != me and dist[n] < best:
			best = dist[n]
	return best + 1 if best < INF else INF


# 幅優先の歩数の表。src[i] == src_val のマスから始め、線が block のマスと盤の外(と avoid が 1 のマス)は通れない。
func _field(g: Grid, src: PackedInt32Array, src_val: int, block: int, out: PackedInt32Array, avoid := PackedInt32Array()) -> void:
	out.fill(INF)
	var nb := g.nb
	var tr := g.trail
	var q := _queue
	var use_avoid := not avoid.is_empty()
	var head := 0
	var tail := 0
	var i := src.find(src_val)
	while i >= 0:
		if tr[i] != block and not (use_avoid and avoid[i] == 1):
			out[i] = 0
			q[tail] = i
			tail += 1
		i = src.find(src_val, i + 1)
	while head < tail:
		var c := q[head]
		head += 1
		var nd := out[c] + 1
		var k := c * 4
		for d in 4:
			var n := nb[k + d]
			if n >= 0 and out[n] == INF and tr[n] != block and not (use_avoid and avoid[n] == 1):
				out[n] = nd
				q[tail] = n
				tail += 1
