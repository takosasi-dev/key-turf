# テストの土台。ok / eq で確かめ、失敗は errors にたまる。盤・頭・線を直接組み、移動を 1 回ずつ進める道具も持つ。
# 各テストは最後に true を返す(途中で止まったことを見分けるため)。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Grid := preload("res://core/grid.gd")
const Match := preload("res://core/match.gd")
const Cpu := preload("res://core/cpu.gd")
const Bots := preload("res://core/bots.gd")

var errors: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if typeof(got) != typeof(want) or got != want:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


static func c(x: int, y: int) -> int:
	return Grid.idx(x, y)


# 数えを済ませ、動く段階にした Sim。
static func moving(mode: int = Sim.MODE_DUO, ticks: int = B.ROUND_TICKS, cpu_seed: int = 1) -> Sim:
	var sim := Sim.new(mode, ticks, cpu_seed)
	sim.phase = Sim.PHASE_MOVE
	sim.count_tick = B.COUNTDOWN_TICKS
	return sim


# 頭を (x, y) に置き、向きを d にする。
static func put(sim: Sim, p: int, x: int, y: int, d: int) -> void:
	sim.heads[p] = c(x, y)
	sim.dirs[p] = d


static func trail(sim: Sim, p: int, cells: Array) -> void:
	for xy: Vector2i in cells:
		sim.grid.trail[c(xy.x, xy.y)] = p + 1


static func land(sim: Sim, p: int, cells: Array) -> void:
	for xy: Vector2i in cells:
		sim.grid.owner[c(xy.x, xy.y)] = p + 1


# 移動を n 回進める(移動の tick まで step する)。起きた events を全部返す。
static func moves(sim: Sim, n: int = 1) -> Array:
	var ev: Array = []
	for k in n:
		if sim.is_over():
			break
		var left := B.MOVE_TICKS - sim.move_tick
		for t in left:
			sim.step()
			ev.append_array(sim.events())
			if sim.is_over():
				break
	return ev


static func run(sim: Sim, ticks: int) -> Array:
	var ev: Array = []
	for k in ticks:
		sim.step()
		ev.append_array(sim.events())
	return ev


static func of_type(ev: Array, t: String) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return e["type"] == t)


@warning_ignore("integer_division")
static func head_xy(sim: Sim, p: int) -> Vector2i:
	return Vector2i(sim.heads[p] % Grid.W, sim.heads[p] / Grid.W)


# CPU 同士のラウンド(level[0] が P1、level[1] が P2)。
static func cpu_round(levels: Array, p_seed: int, ticks: int = B.ROUND_TICKS) -> Dictionary:
	var sim := Sim.new(Sim.MODE_DUO, ticks, 1)
	for p in 2:
		Bots.attach_cpu(sim, p, levels[p], p_seed * 2 + p)
	return Bots.play_round(sim, [])


# CPU 同士の試合。
static func cpu_match(levels: Array, p_seed: int) -> Dictionary:
	var m := Match.new(Sim.MODE_DUO, false, p_seed)
	while not m.is_over():
		var sim := m.next_round()
		for p in 2:
			Bots.attach_cpu(sim, p, levels[p], (p_seed + m.rounds.size() * 7919) * 2 + p)
		m.finish_round(Bots.play_round(sim, []))
	return m.result()
