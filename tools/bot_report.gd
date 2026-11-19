# CPU と bot の数字を出す道具(仕様書 AC-15・AC-16・撤退基準 R-4 の参考・NFR-3 の参考)。
# CPU 2 段それぞれの、ランダム bot・何もしない bot・回る bot との試合の勝ち負け、ふつう 対 やさしい、
# CPU 同士で自分の線に入った回数、1 回の移動の計算時間(この PC のネイティブ。Web ではない)を印字する。
# 実行: python tools/gd.py run res://tools/bot_report.gd [試合の数(既定 20)]
extends SceneTree

const B := preload("res://core/balance.gd")
const Sim := preload("res://core/sim.gd")
const Match := preload("res://core/match.gd")
const Cpu := preload("res://core/cpu.gd")
const Bots := preload("res://core/bots.gd")

const LEVEL_NAMES := ["", "やさしい", "ふつう"]
const REASON_NAMES := ["線を切った", "自分の線", "囲んだ", "陣地が0", "正面衝突", "相打ち", "広さ", "同じ広さ"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if not args.is_empty() else 20
	print("試合の数 %d(種 1〜%d)。勝ち-負け-引き分けは CPU から見た数" % [n, n])
	for level in [Cpu.EASY, Cpu.NORMAL]:
		for opp: String in ["ランダム", "何もしない", "回る(4)"]:
			var w := [0, 0, 0]
			var reasons := {}
			for s in range(1, n + 1):
				var r := _match_vs_bot(level, opp, s, reasons)
				w[0 if r == 1 else (1 if r == 0 else 2)] += 1
			print("CPU %s 対 %s bot: %d-%d-%d  ラウンドの理由 %s" % [LEVEL_NAMES[level], opp, w[0], w[1], w[2], _fmt(reasons)])
	var nw := [0, 0, 0]
	var reasons2 := {}
	for s in range(1, n + 1):
		var normal_side := s % 2  # 交互に P1・P2
		var levels := [Cpu.NORMAL, Cpu.EASY] if normal_side == 0 else [Cpu.EASY, Cpu.NORMAL]
		var r := _cpu_match(levels, s, reasons2)
		nw[0 if r == normal_side else (1 if r == 1 - normal_side else 2)] += 1
	print("ふつう 対 やさしい(左右を交互): ふつう %d 勝・%d 敗・%d 分  ラウンドの理由 %s" % [nw[0], nw[1], nw[2], _fmt(reasons2)])
	var selfs := 0
	var max_us := 0
	var total_us := 0
	var count := 0
	for s in range(1, 101):
		var sim := Sim.new(Sim.MODE_DUO, B.ROUND_TICKS, 1)
		Bots.attach_cpu(sim, 0, Cpu.EASY, s * 2)
		Bots.attach_cpu(sim, 1, Cpu.NORMAL, s * 2 + 1)
		while not sim.is_over():
			var t0 := Time.get_ticks_usec()
			var is_move := sim.phase == Sim.PHASE_MOVE and sim.move_tick == B.MOVE_TICKS - 1
			sim.step()
			if is_move:
				var dt := Time.get_ticks_usec() - t0
				max_us = maxi(max_us, dt)
				total_us += dt
				count += 1
		if int(sim.result()["reason"]) == Sim.REASON_SELF:
			selfs += 1
	print("やさしい 対 ふつう の 100 ラウンド: 自分の線に入った回数 %d" % selfs)
	print("1 回の移動(CPU 2 人ぶん)の計算: 平均 %.2f ms・最大 %.2f ms(%d 回)" % [total_us / 1000.0 / maxi(count, 1), max_us / 1000.0, count])
	quit()


func _bot(kind: String, s: int) -> Variant:
	match kind:
		"ランダム":
			return Bots.Randomer.new(0, s)
		"何もしない":
			return Bots.Idle.new()
	return Bots.Circler.new(0, 4)


# P1 は bot、P2 は CPU。試合の勝者(0・1・−1)を返す。
func _match_vs_bot(level: int, kind: String, s: int, reasons: Dictionary) -> int:
	var m := Match.new(level, false, s)
	while not m.is_over():
		var sim := m.next_round()
		var r := Bots.play_round(sim, [_bot(kind, s * 31 + m.rounds.size())])
		m.finish_round(r)
		reasons[REASON_NAMES[int(r["reason"])]] = reasons.get(REASON_NAMES[int(r["reason"])], 0) + 1
	return int(m.result()["winner"])


func _cpu_match(levels: Array, s: int, reasons: Dictionary) -> int:
	var m := Match.new(Sim.MODE_DUO, false, s)
	while not m.is_over():
		var sim := m.next_round()
		for p in 2:
			Bots.attach_cpu(sim, p, levels[p], (s + m.rounds.size() * 7919) * 2 + p)
		var r := Bots.play_round(sim, [])
		m.finish_round(r)
		reasons[REASON_NAMES[int(r["reason"])]] = reasons.get(REASON_NAMES[int(r["reason"])], 0) + 1
	return int(m.result()["winner"])


func _fmt(d: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: String in d.keys():
		parts.append("%s %d" % [k, d[k]])
	return " ".join(parts)
