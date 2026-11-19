# テスト用の bot(仕様書 §9.12): 回る bot・何もしない bot・写し bot。加えて、記録の種を作るランダム bot と、
# CPU を人の側に付ける道具(AC-15・AC-16・撤退基準の数字を出す道具が使う)。
# どの bot も feed(sim) を sim.step() の前に毎回呼ぶと、その tick の予約を queue_turn する(入力は整数だけ。INV-4)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")
const Sim := preload("res://core/sim.gd")
const Cpu := preload("res://core/cpu.gd")


# 回る bot: 陣地を出て、1 辺 size マスの四角を右回りに回り、陣地へ戻る。線の長さで辺を数える。
class Circler:
	var p := 0
	var size := 4
	var _d0 := -1

	func _init(p_player: int, p_size: int) -> void:
		p = p_player
		size = p_size

	@warning_ignore("integer_division")
	func feed(sim: Sim) -> void:
		if sim.phase != Sim.PHASE_MOVE or not sim.queues[p].is_empty():
			return
		var tc := sim.grid.trail_count(p)
		if tc == 0:
			_d0 = sim.dirs[p]  # 陣地の中では今の向きを 1 辺目にする
			return
		var side := mini(tc / size, 3)
		var want := (_d0 + side) % 4
		if want != sim.dirs[p]:
			sim.queue_turn(p, want)


# 何もしない bot: 予約しない(真っすぐ進み、端で止まる)。
class Idle:
	func feed(_sim: Sim) -> void:
		pass


# ランダム bot: BOT_RANDOM_EVERY tick ごとに、BOT_RANDOM_TURN_PCT % で左か右へ曲がる。
# 1 マス先が自分の線になる向きは選ばない(真っすぐ先が自分の線なら必ず曲がる)。
class Randomer:
	var p := 0
	var rng: Rng

	func _init(p_player: int, p_seed: int) -> void:
		p = p_player
		var s := (p_seed ^ B.BOT_RNG_XOR) & Rng.MASK
		rng = Rng.new(s if s != 0 else 1)

	func feed(sim: Sim) -> void:
		if sim.step_no % B.BOT_RANDOM_EVERY != 0:
			return
		var d: int = sim.dirs[p]
		var blocked := _own(sim, d)
		if not blocked and rng.next_int(100) >= B.BOT_RANDOM_TURN_PCT:
			return
		var turn := (d + 1 + 2 * rng.next_int(2)) % 4
		if _own(sim, turn):
			turn = (turn + 2) % 4
		if not _own(sim, turn):
			sim.queue_turn(p, turn)

	func _own(sim: Sim, d: int) -> bool:
		var n := sim.grid.nb[sim.heads[p] * 4 + d]
		return n >= 0 and sim.grid.trail[n] == p + 1


# 記録する bot: 中の bot の予約を [step_no, 人, 向き] で残す(AC-2・AC-3)。
class Recorder:
	var inner: Array = []
	var log: Array = []

	func _init(bots: Array) -> void:
		inner = bots

	func feed(sim: Sim) -> void:
		var before: Array = [sim.queues[0].duplicate(), sim.queues[1].duplicate()]
		for b: Variant in inner:
			b.feed(sim)
		for p in 2:
			var q: Array = sim.queues[p]
			for k in range(before[p].size(), q.size()):
				log.append([sim.step_no, p, int(q[k])])


# 写し bot: 記録を流す。mirror なら P1 と P2 を入れ替え、向きを 180 度回す(上 ↔ 下、左 ↔ 右。AC-3)。
class Replayer:
	var log: Array = []
	var mirror := false
	var _at := 0

	func _init(p_log: Array, p_mirror: bool) -> void:
		log = p_log
		mirror = p_mirror

	func feed(sim: Sim) -> void:
		while _at < log.size() and int(log[_at][0]) == sim.step_no:
			var e: Array = log[_at]
			if mirror:
				sim.queue_turn(1 - int(e[1]), (int(e[2]) + 2) % 4)
			else:
				sim.queue_turn(int(e[1]), int(e[2]))
			_at += 1


# 人の p の側に CPU を付ける(仕様書は P2 だけ。テストと道具で P1 にも付ける)。
static func attach_cpu(sim: Sim, p: int, level: int, p_seed: int) -> void:
	sim.cpus[p] = Cpu.new(p, level, p_seed)


# ラウンドを終わりまで回す。bots は feed(sim) を持つ物の配列。
static func play_round(sim: Sim, bots: Array) -> Dictionary:
	while not sim.is_over():
		for b: Variant in bots:
			b.feed(sim)
		sim.step()
	return sim.result()
