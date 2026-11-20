# 試合・決定性・対称・CPU のテスト(仕様書 §9.7・§9.8・AC-2・AC-3・AC-12・AC-13・AC-15・AC-16・NFR-4)。
extends "res://tests/suite.gd"


static func _r(w: int, why: int = Sim.REASON_CUT) -> Dictionary:
	return {"winner": w, "reason": why, "counts": [30, 20]}


func test_ac12_three_wins_end_match() -> bool:
	var m := Match.new(Sim.MODE_DUO, false, 5)
	for w in [0, 1, 0, -1]:
		m.next_round()
		m.finish_round(_r(w, Sim.REASON_HEADON if w < 0 else Sim.REASON_CUT))
	ok(not m.is_over(), "2 − 1 ではまだ")
	m.next_round()
	m.finish_round(_r(0))
	ok(m.is_over(), "3 本先取で終わる")
	eq(m.result()["winner"], 0, "P1 の勝ち")
	eq(m.result()["wins"], [3, 1], "勝ち数")
	eq(m.result()["rounds"].size(), 5, "引き分けのラウンドも数える")
	return true


func test_ac12_nine_rounds_decided_by_wins() -> bool:
	var m := Match.new(Sim.MODE_DUO, false, 5)
	for w in [-1, -1, 1, -1, 0, -1, 0, -1]:
		m.next_round()
		m.finish_round(_r(w, Sim.REASON_BOTH))
	ok(not m.is_over(), "8 ラウンドではまだ")
	m.next_round()
	m.finish_round(_r(-1, Sim.REASON_TIE))
	ok(m.is_over(), "数えるラウンドが 9 で終わる")
	eq(m.result()["winner"], 0, "勝った数の多い方(2 − 1)")
	var d := Match.new(Sim.MODE_DUO, false, 5)
	for k in 9:
		d.next_round()
		d.finish_round(_r(-1, Sim.REASON_HEADON))
	ok(d.is_over(), "9 引き分けで終わる")
	eq(d.result()["winner"], -1, "同じなら引き分け")
	return true


func test_ac13_practice_only_when_asked() -> bool:
	var m := Match.new(Sim.MODE_EASY, true, 100)
	ok(m.is_practice(), "最初は練習")
	var sim := m.next_round()
	eq(sim.round_ticks, B.PRACTICE_TICKS, "練習は 15 秒")
	eq(B.PRACTICE_TICKS, 15 * B.TICK_HZ, "15 秒")
	m.finish_round(_r(1))
	eq(m.wins, [0, 0] as Array[int], "練習の結果は勝ち数に入らない")
	eq(m.rounds.size(), 0, "ラウンドにも入らない")
	ok(not m.is_practice(), "次は本番")
	sim = m.next_round()
	eq(sim.round_ticks, B.ROUND_TICKS, "本番は 30 秒")
	eq(m.round_number(), 1, "ラウンド 1")
	var n := Match.new(Sim.MODE_EASY, false, 100)
	ok(not n.is_practice(), "with_practice が偽なら練習は無い")
	eq(n.next_round().round_ticks, B.ROUND_TICKS, "最初から本番")
	return true


func test_cpu_seed_is_seed_plus_round() -> bool:
	# 同じ種 + ラウンドの番号なら、CPU の動きは同じ
	var m := Match.new(Sim.MODE_NORMAL, false, 41)
	var a := m.next_round()
	var b := Sim.new(Sim.MODE_NORMAL, B.ROUND_TICKS, 42)
	var ra := Bots.play_round(a, [Bots.Circler.new(0, 4)])
	var rb := Bots.play_round(b, [Bots.Circler.new(0, 4)])
	eq(ra, rb, "1 ラウンド目の種は seed + 1")
	return true


func test_mode_sets_cpu() -> bool:
	ok(Sim.new(Sim.MODE_DUO).cpus[1] == null, "ふたりでは CPU 無し")
	eq((Sim.new(Sim.MODE_EASY).cpus[1] as Cpu).level, Cpu.EASY, "やさしい")
	eq((Sim.new(Sim.MODE_NORMAL).cpus[1] as Cpu).level, Cpu.NORMAL, "ふつう")
	ok(Sim.new(Sim.MODE_NORMAL).cpus[0] == null, "CPU は P2")
	return true


# 記録: ふたりでのラウンドを bot 2 人で回し、予約を残す。kind で組み合わせを変える(0 ランダム同士、1・2 回る bot とランダム、3 回る同士)。
static func _record(s: int, kind: int = 0) -> Dictionary:
	var sim := Sim.new(Sim.MODE_DUO)
	var a: Variant = Bots.Circler.new(0, 3 + s % 5) if kind == 1 or kind == 3 else Bots.Randomer.new(0, s)
	var b: Variant = Bots.Circler.new(1, 3 + s % 4) if kind == 2 or kind == 3 else Bots.Randomer.new(1, s + 7777)
	var rec := Bots.Recorder.new([a, b])
	var r := Bots.play_round(sim, [rec])
	return {"log": rec.log, "result": r}


func test_ac2_same_inputs_same_result_100_times() -> bool:
	var recs: Array = []
	for s in [3, 11, 29]:
		recs.append(_record(s))
	for k in 100:
		for rec: Dictionary in recs:
			var r := Bots.play_round(Sim.new(Sim.MODE_DUO), [Bots.Replayer.new(rec["log"], false)])
			if r != rec["result"]:
				errors.append("ふたりで %d 回目: %s のはずが %s" % [k, rec["result"], r])
				return true
	# CPU の試合: 同じ記録と同じ種
	var rec := Bots.Recorder.new([Bots.Randomer.new(0, 5)])
	var first := Bots.play_round(Sim.new(Sim.MODE_NORMAL, B.ROUND_TICKS, 77), [rec])
	for k in 100:
		var r := Bots.play_round(Sim.new(Sim.MODE_NORMAL, B.ROUND_TICKS, 77), [Bots.Replayer.new(rec.log, false)])
		if r != first:
			errors.append("CPU %d 回目: %s のはずが %s" % [k, first, r])
			break
	return true


func test_ac3_mirror_swaps_result() -> bool:
	var reasons := {}
	for s in range(1, 21):
		var rec := _record(s * 101, s % 4)
		var r: Dictionary = rec["result"]
		var m := Bots.play_round(Sim.new(Sim.MODE_DUO), [Bots.Replayer.new(rec["log"], true)])
		var w: int = r["winner"]
		eq(m["winner"], -1 if w < 0 else 1 - w, "記録 %d: 勝者が入れ替わる" % s)
		eq(m["reason"], r["reason"], "記録 %d: 理由が同じ" % s)
		eq(m["counts"], [r["counts"][1], r["counts"][0]], "記録 %d: マス数が入れ替わる" % s)
		reasons[r["reason"]] = reasons.get(r["reason"], 0) + 1
	print("      AC-3 の 20 通りの理由(番号: 数) ", reasons)
	ok(reasons.size() >= 2, "20 通りの理由が 1 種類だけではない: %s" % [reasons.keys()])
	return true


func test_ac3_mirror_with_capture() -> bool:
	# 囲みを含む記録(回る bot)でも入れ替わる
	var sim := Sim.new(Sim.MODE_DUO)
	var rec := Bots.Recorder.new([Bots.Circler.new(0, 4), Bots.Circler.new(1, 5)])
	var ev_caps := 0
	while not sim.is_over():
		rec.feed(sim)
		sim.step()
		ev_caps += of_type(sim.events(), "capture").size()
	var r := sim.result()
	ok(ev_caps >= 2, "囲みが起きている")
	var m := Bots.play_round(Sim.new(Sim.MODE_DUO), [Bots.Replayer.new(rec.log, true)])
	eq(m["counts"], [r["counts"][1], r["counts"][0]], "マス数が入れ替わる")
	eq(m["reason"], r["reason"], "理由が同じ")
	return true


func test_ac15_cpu_never_enters_own_trail_100_rounds() -> bool:
	var selfs := 0
	for s in range(1, 101):
		var r := cpu_round([Cpu.EASY, Cpu.NORMAL], s)
		if int(r["reason"]) == Sim.REASON_SELF:
			selfs += 1
	eq(selfs, 0, "CPU 同士の 100 ラウンドで自分の線に入った回数")
	return true


func test_ac16_normal_beats_easy() -> bool:
	var won := 0
	for s in range(1, 21):
		var side := s % 2  # ふつう を P1・P2 交互に置く
		var levels := [Cpu.NORMAL, Cpu.EASY] if side == 0 else [Cpu.EASY, Cpu.NORMAL]
		if int(cpu_match(levels, s)["winner"]) == side:
			won += 1
	ok(won >= 14, "ふつう 対 やさしい の 20 試合で ふつう が 14 試合以上勝つ(%d 試合)" % won)
	return true


func test_normal_beats_straight_bot() -> bool:
	# 2026-11-20 の直し: ふつう は、直進するだけの bot(何もしない bot)に 20 試合で勝ち越す
	var w := [0, 0, 0]
	for s in range(1, 21):
		var m := Match.new(Sim.MODE_NORMAL, false, s)
		while not m.is_over():
			m.finish_round(Bots.play_round(m.next_round(), [Bots.Idle.new()]))
		var r: int = m.result()["winner"]
		w[0 if r == 1 else (1 if r == 0 else 2)] += 1
	print("      ふつう 対 何もしない bot(勝-負-分) ", w)
	ok(w[0] > w[1], "ふつう が勝ち越す: %s" % [w])
	return true


func test_attack_skips_head_and_next_cells() -> bool:
	# 的は相手の頭のマスと、頭の前・左右のマスを外す。相手の線がそれだけなら攻めない
	var sim := moving(Sim.MODE_NORMAL)
	var cpu: Cpu = sim.cpus[1]
	put(sim, 0, 20, 10, 1)
	trail(sim, 0, [Vector2i(20, 10), Vector2i(20, 9), Vector2i(20, 11)])
	ok(cpu._attack(sim.grid, sim, c(22, 10), 2, 0) < 0, "頭と、頭の前・左右の線だけなら攻めない")
	trail(sim, 0, [Vector2i(19, 10)])
	put(sim, 1, 19, 12, 0)
	ok(cpu._attack(sim.grid, sim, c(19, 12), 2, 0) >= 0, "頭の後ろの線は攻める")
	return true


func test_cpu_returns_home_and_captures() -> bool:
	var sim := Sim.new(Sim.MODE_EASY, B.ROUND_TICKS, 9)
	var caps := 0
	while not sim.is_over():
		sim.step()
		for e: Dictionary in of_type(sim.events(), "capture"):
			if int(e["p"]) == 1:
				caps += 1
	ok(caps >= 3, "やさしい は 1 ラウンドに何度も囲む(%d 回)" % caps)
	ok(sim.grid.count(1) > 25, "CPU の陣地が広がる")
	return true


func test_cpu_never_reverses() -> bool:
	var sim := Sim.new(Sim.MODE_NORMAL, B.ROUND_TICKS, 3)
	var bot := Bots.Randomer.new(0, 3)
	while not sim.is_over():
		bot.feed(sim)
		var before: int = sim.dirs[1]
		var is_move := sim.phase == Sim.PHASE_MOVE and sim.move_tick == B.MOVE_TICKS - 1
		sim.step()
		if is_move and sim.dirs[1] == (before + 2) % 4:
			errors.append("CPU が逆を向いた")
			break
	return true


func test_cpu_runs_home_when_threatened() -> bool:
	# 線を引いて外にいる CPU のすぐ横に相手の頭があれば、計画をやめて戻る(§9.8 の 1)
	var sim := moving(Sim.MODE_EASY)
	var cpu: Cpu = sim.cpus[1]
	cpu.plan = {"d1": 3, "d2": 0, "a": 30, "b": 30, "home": false}
	put(sim, 1, 33, 12, 3)
	trail(sim, 1, [Vector2i(36, 12), Vector2i(35, 12), Vector2i(34, 12), Vector2i(33, 12)])
	put(sim, 0, 33, 15, 0)
	var d := cpu.decide(sim)
	ok(cpu.plan["home"], "戻るに切り替える")
	ok(d == 0 or d == 2, "逆(右)へは向けないので、直角に曲がる: %d" % d)
	return true


func test_golden_cpu_match() -> bool:
	# 決まった種の CPU 同士の試合の結果(NFR-4: Windows と CI で同じ値になることを見る)
	var r := cpu_match([Cpu.EASY, Cpu.NORMAL], 12345)
	var sig := [r["winner"], r["wins"]]
	for row: Dictionary in r["rounds"]:
		sig.append([row["winner"], row["reason"], row["counts"]])
	print("      GOLDEN ", JSON.stringify(sig))
	eq(JSON.stringify(sig), GOLDEN, "固定の結果")
	return true


const GOLDEN := "[1,[0,3],[-1,4,[251,345]],[1,6,[281,338]],[1,6,[291,387]],[1,6,[295,493]]]"
