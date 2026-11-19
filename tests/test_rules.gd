# 決まりのテスト(仕様書 §9.3〜§9.6・AC-4〜AC-11・AC-14・AC-17・E-2〜E-12・FR-16)。盤・頭・線を直接組んで移動を進める。
extends "res://tests/suite.gd"


func test_initial_layout() -> bool:
	var sim := Sim.new()
	eq(sim.grid.count(0), 25, "P1 の陣地は 5×5")
	eq(sim.grid.count(1), 25, "P2 の陣地は 5×5")
	eq(head_xy(sim, 0), Vector2i(8, 13), "P1 の頭")
	eq(head_xy(sim, 1), Vector2i(39, 12), "P2 の頭")
	eq(sim.dirs, [1, 3] as Array[int], "P1 は右、P2 は左")
	ok(sim.grid.owner[c(6, 11)] == 1 and sim.grid.owner[c(10, 15)] == 1 and sim.grid.owner[c(11, 13)] == 0, "P1 は x 6〜10・y 11〜15")
	ok(sim.grid.owner[c(37, 10)] == 2 and sim.grid.owner[c(41, 14)] == 2 and sim.grid.owner[c(36, 12)] == 0, "P2 は x 37〜41・y 10〜14")
	for i in Grid.N:
		if sim.grid.owner[i] != 0 and sim.grid.owner[Grid.N - 1 - i] != 3 - sim.grid.owner[i]:
			errors.append("180 度回すと持ち主が入れ替わる: %d" % i)
			break
	eq(Grid.N, 1248, "1,248 マス")
	return true


func test_countdown_then_go() -> bool:
	var sim := Sim.new(Sim.MODE_DUO, 3600)
	var ev := run(sim, B.COUNTDOWN_TICKS - 1)
	eq(ev, [], "数えの間は何も起きない")
	eq(sim.remaining, 3600, "数えの間は残り tick を減らさない")
	eq(sim.phase, Sim.PHASE_COUNT, "まだ数え")
	ev = run(sim, 1)
	eq(of_type(ev, "go").size(), 1, "数え終わった step に go")
	eq(sim.phase, Sim.PHASE_MOVE, "動く")
	run(sim, B.MOVE_TICKS - 1)
	eq(head_xy(sim, 0), Vector2i(8, 13), "MOVE_TICKS に届くまで動かない")
	run(sim, 1)
	eq(head_xy(sim, 0), Vector2i(9, 13), "MOVE_TICKS ごとに 1 マス")
	eq(head_xy(sim, 1), Vector2i(38, 12), "2 人は同じ step で動く")
	eq(sim.remaining, 3600 - B.MOVE_TICKS, "動く間は 1 tick ずつ減る")
	return true


func test_fr16_turn_queued_in_countdown_is_used_first() -> bool:
	var sim := Sim.new()
	run(sim, 10)
	ok(sim.queue_turn(0, 2), "数えの間も予約できる")
	run(sim, B.COUNTDOWN_TICKS - 10 + B.MOVE_TICKS)
	eq(head_xy(sim, 0), Vector2i(8, 14), "最初の移動で下へ")
	eq(sim.dirs[0], 2, "向きが下")
	return true


func test_ac4_capture_40_cells() -> bool:
	var sim := moving()
	moves(sim, 5)
	eq(head_xy(sim, 0), Vector2i(13, 13), "右へ (13, 13)")
	sim.queue_turn(0, 2)
	moves(sim, 3)
	eq(head_xy(sim, 0), Vector2i(13, 16), "下へ (13, 16)")
	sim.queue_turn(0, 3)
	moves(sim, 5)
	eq(head_xy(sim, 0), Vector2i(8, 16), "左へ (8, 16)")
	eq(sim.grid.trail_count(0), 11, "線 11 マス")
	sim.queue_turn(0, 0)
	var ev := moves(sim, 1)
	eq(head_xy(sim, 0), Vector2i(8, 15), "上へ (8, 15)")
	var cap := of_type(ev, "capture")
	eq(cap.size(), 1, "囲んだ")
	eq(int(cap[0]["count"]), 15, "線 11 マスと中の 4 マスを取る")
	eq(sim.grid.count(0), 40, "P1 の陣地が 40 マス")
	eq(sim.grid.trail_count(0), 0, "線は消える")
	for xy: Vector2i in [Vector2i(11, 14), Vector2i(12, 14), Vector2i(11, 15), Vector2i(12, 15)]:
		eq(sim.grid.owner[c(xy.x, xy.y)], 1, "中のマス %s" % xy)
	eq(sim.grid.owner[c(7, 16)], 0, "外のマスは取らない")
	ok(not sim.is_over(), "続く")
	return true


func test_capture_cells_does_not_change_board() -> bool:
	var sim := moving()
	trail(sim, 0, [Vector2i(11, 13), Vector2i(12, 13)])
	var before := sim.grid.owner.duplicate()
	var cells := sim.grid.capture_cells(0)
	eq(sim.grid.owner, before, "盤は書き換えない")
	eq(cells.size(), 2, "線だけ(囲んだ所が無い)")
	return true


func test_trail_start_event_once() -> bool:
	var sim := moving()
	var ev := moves(sim, 2)
	eq(of_type(ev, "trail_start").size(), 0, "陣地の中は線にならない")
	ev = moves(sim, 1)
	var ts := of_type(ev, "trail_start").filter(func(e: Dictionary) -> bool: return int(e["p"]) == 0)
	eq(ts.size(), 1, "陣地を出た回に trail_start")
	eq(of_type(ev, "trail_start").size(), 2, "P2 も同じ回に陣地を出る(対称)")
	ok(not ts.is_empty() and int(ts[0]["p"]) == 0 and int(ts[0]["cell"]) == c(11, 13), "P1 の (11, 13)")
	eq(sim.grid.trail[c(11, 13)], 1, "線になる")
	ev = moves(sim, 1)
	eq(of_type(ev, "trail_start").size(), 0, "外にいる間は 1 回だけ")
	eq(sim.grid.trail_count(0), 2, "線が伸びる")
	return true


func test_ac5_cut_trail() -> bool:
	var sim := moving()
	put(sim, 1, 25, 5, 3)
	trail(sim, 1, [Vector2i(25, 5), Vector2i(26, 5), Vector2i(27, 5)])
	put(sim, 0, 26, 7, 0)
	sim.grid.trail[c(26, 7)] = 1
	moves(sim, 2)
	ok(sim.is_over(), "終わる")
	eq(sim.result()["winner"], 0, "踏んだ P1 の勝ち")
	eq(sim.result()["reason"], Sim.REASON_CUT, "線を切った")
	return true


func test_ac5_enter_moving_head_cell() -> bool:
	var sim := moving()
	put(sim, 1, 20, 5, 3)
	trail(sim, 1, [Vector2i(20, 5), Vector2i(21, 5)])
	put(sim, 0, 20, 6, 0)
	trail(sim, 0, [Vector2i(20, 6)])
	moves(sim, 1)
	eq(sim.result()["winner"], 0, "陣地の外にいる相手の頭のマスへ入ると相手の負け")
	eq(sim.result()["reason"], Sim.REASON_CUT, "線を切った")
	return true


func test_e6_enter_stopped_head() -> bool:
	var sim := moving()
	put(sim, 1, 0, 5, 3)  # 左の端で止まっている
	trail(sim, 1, [Vector2i(0, 5), Vector2i(1, 5)])
	put(sim, 0, 0, 6, 0)
	trail(sim, 0, [Vector2i(0, 6)])
	moves(sim, 1)
	eq([sim.result()["winner"], sim.result()["reason"]], [0, Sim.REASON_CUT], "止まった頭のマスが線なら、止まっている人の負け")
	sim = moving()
	put(sim, 1, 47, 3, 1)  # 右の端で止まっている。頭のマスは線でない
	land(sim, 1, [Vector2i(47, 3)])
	put(sim, 0, 46, 3, 1)
	trail(sim, 0, [Vector2i(46, 3)])
	moves(sim, 1)
	eq([sim.result()["winner"], sim.result()["reason"]], [-1, Sim.REASON_HEADON], "線でなければ正面衝突")
	return true


func test_ac6_own_trail() -> bool:
	var sim := moving()
	put(sim, 0, 20, 20, 1)
	trail(sim, 0, [Vector2i(19, 21), Vector2i(20, 21), Vector2i(21, 21), Vector2i(21, 20), Vector2i(20, 20)])
	sim.queue_turn(0, 2)
	moves(sim, 1)
	ok(sim.is_over(), "終わる")
	eq(sim.result()["winner"], 1, "自分の線に入ると自分の負け")
	eq(sim.result()["reason"], Sim.REASON_SELF, "自分の線")
	return true


# P1 の陣地 (6〜10, 11〜15) の右下を線で囲む。中の 5 マスは (11, 15)(12, 15)(11, 16)(12, 16)(10, 16)。
func _enclosure(sim: Sim) -> void:
	trail(sim, 0, [Vector2i(11, 14), Vector2i(12, 14), Vector2i(13, 14), Vector2i(13, 15), Vector2i(13, 16), Vector2i(13, 17),
		Vector2i(12, 17), Vector2i(11, 17), Vector2i(10, 17), Vector2i(9, 17), Vector2i(9, 16)])
	put(sim, 0, 9, 16, 0)


func test_ac7_enclose_head() -> bool:
	var sim := moving()
	_enclosure(sim)
	put(sim, 1, 12, 16, 3)
	trail(sim, 1, [Vector2i(12, 16)])
	var ev := moves(sim, 1)
	ok(sim.is_over(), "終わる")
	eq(sim.result()["winner"], 0, "取るマスに相手の頭があると相手の負け")
	eq(sim.result()["reason"], Sim.REASON_ENCLOSE, "囲んだ")
	eq(of_type(ev, "capture").size(), 1, "勝った人の取るマスは塗る")
	eq(sim.grid.owner[c(10, 16)], 1, "塗った")
	return true


func test_ac7_enclose_part_of_trail() -> bool:
	var sim := moving()
	_enclosure(sim)
	put(sim, 1, 30, 3, 3)
	trail(sim, 1, [Vector2i(30, 3), Vector2i(31, 3), Vector2i(11, 16)])
	moves(sim, 1)
	eq([sim.result()["winner"], sim.result()["reason"]], [0, Sim.REASON_ENCLOSE], "相手の線の一部があった時も同じ")
	return true


func test_ac8_headon_same_cell_and_swap() -> bool:
	var sim := moving()
	put(sim, 0, 20, 8, 1)
	put(sim, 1, 22, 8, 3)
	trail(sim, 0, [Vector2i(20, 8)])
	trail(sim, 1, [Vector2i(22, 8)])
	moves(sim, 1)
	eq([sim.result()["winner"], sim.result()["reason"]], [-1, Sim.REASON_HEADON], "同じマスへ入ると引き分け")
	eq(head_xy(sim, 0), Vector2i(20, 8), "頭は動かさない")
	sim = moving()
	put(sim, 0, 20, 8, 1)
	put(sim, 1, 21, 8, 3)
	trail(sim, 0, [Vector2i(20, 8)])
	trail(sim, 1, [Vector2i(21, 8)])
	moves(sim, 1)
	eq([sim.result()["winner"], sim.result()["reason"]], [-1, Sim.REASON_HEADON], "すれ違うと引き分け")
	return true


func test_e8_both_cut_is_draw() -> bool:
	var sim := moving()
	put(sim, 0, 20, 8, 0)
	trail(sim, 0, [Vector2i(20, 8), Vector2i(21, 8)])
	put(sim, 1, 21, 7, 2)
	trail(sim, 1, [Vector2i(21, 7), Vector2i(20, 7)])
	moves(sim, 1)
	eq([sim.result()["winner"], sim.result()["reason"]], [-1, Sim.REASON_BOTH], "同じ移動で 2 人とも踏まれたら相打ち")
	return true


func test_two_reasons_take_upper_one() -> bool:
	var sim := moving()
	put(sim, 0, 20, 10, 0)
	trail(sim, 0, [Vector2i(20, 9), Vector2i(20, 10), Vector2i(21, 10)])
	put(sim, 1, 22, 10, 3)
	trail(sim, 1, [Vector2i(22, 10), Vector2i(23, 10)])
	moves(sim, 1)
	eq([sim.result()["winner"], sim.result()["reason"]], [1, Sim.REASON_CUT], "自分の線と線を切られたが重なると、表で上の「線を切った」")
	return true


func test_ac9_edge_stops_without_trail() -> bool:
	var sim := moving()
	put(sim, 0, 45, 20, 1)
	trail(sim, 0, [Vector2i(45, 20)])
	put(sim, 1, 30, 2, 0)
	moves(sim, 2)
	eq(head_xy(sim, 0), Vector2i(47, 20), "端まで進む")
	var tc := sim.grid.trail_count(0)
	moves(sim, 3)
	eq(head_xy(sim, 0), Vector2i(47, 20), "端で止まる")
	eq(sim.grid.trail_count(0), tc, "止まっている間、線は伸びない")
	ok(not sim.is_over() or sim.result()["reason"] != Sim.REASON_SELF, "端で負けない")
	sim.queue_turn(0, 2)
	moves(sim, 1)
	eq(head_xy(sim, 0), Vector2i(47, 21), "曲がると動き出す")
	return true


func test_ac10_queue_rules() -> bool:
	var sim := moving()
	ok(not sim.queue_turn(0, 3), "逆の向き(左)は捨てる")
	ok(not sim.queue_turn(0, 1), "同じ向きは捨てる")
	ok(sim.queue_turn(0, 0), "上")
	ok(not sim.queue_turn(0, 2), "予約の最後の逆(下)は捨てる")
	ok(sim.queue_turn(0, 1), "右")
	ok(not sim.queue_turn(0, 0), "3 つ目は捨てる")
	eq(sim.queues[0], [0, 1], "予約は 2 つ")
	moves(sim, 1)
	eq(head_xy(sim, 0), Vector2i(8, 12), "1 回目の移動で上")
	moves(sim, 1)
	eq(head_xy(sim, 0), Vector2i(9, 12), "2 回目の移動で右")
	eq(sim.queues[0], [], "使い切る")
	return true


func test_ac11_time_up_bigger_wins_or_tie() -> bool:
	var sim := Sim.new(Sim.MODE_DUO, 10)
	sim.phase = Sim.PHASE_MOVE
	run(sim, 10)
	ok(sim.is_over(), "残り tick が 0 で終わる")
	eq([sim.result()["winner"], sim.result()["reason"]], [-1, Sim.REASON_TIE], "同じ広さは引き分け")
	sim = Sim.new(Sim.MODE_DUO, 10)
	sim.phase = Sim.PHASE_MOVE
	land(sim, 1, [Vector2i(30, 20)])
	run(sim, 10)
	eq([sim.result()["winner"], sim.result()["reason"]], [1, Sim.REASON_TIME], "陣地の多い方が勝ち")
	eq(sim.result()["counts"], [25, 26], "2 人のマス数")
	return true


func test_ac11_e12_capture_on_last_step_counts() -> bool:
	var sim := moving(Sim.MODE_DUO, B.MOVE_TICKS)  # 最後の step が移動の step
	land(sim, 1, [Vector2i(30, 20), Vector2i(31, 20)])
	put(sim, 0, 11, 13, 3)
	trail(sim, 0, [Vector2i(11, 13), Vector2i(11, 12)])
	put(sim, 1, 30, 2, 0)
	moves(sim, 1)
	ok(sim.is_over(), "時間切れ")
	eq(sim.result()["counts"], [27, 27], "囲んでから比べる(25 + 2 対 27)")
	eq(sim.result()["reason"], Sim.REASON_TIE, "同じ広さ")
	return true


func test_ac14_overlap_keeps_owner() -> bool:
	var sim := moving()
	var x := Vector2i(20, 6)
	var ring1: Array = []
	var ring2: Array = []
	for yy in range(3, 10):
		for xx in range(17, 24):
			var p := Vector2i(xx, yy)
			if p == x:
				continue
			if absi(xx - x.x) <= 1 and absi(yy - x.y) <= 1:
				ring1.append(p)
			elif maxi(absi(xx - x.x), absi(yy - x.y)) == 2:
				ring2.append(p)
	land(sim, 0, ring1)
	land(sim, 1, ring2)
	put(sim, 0, 11, 13, 3)
	trail(sim, 0, [Vector2i(11, 13)])
	put(sim, 1, 36, 12, 1)
	trail(sim, 1, [Vector2i(36, 12)])
	var a := sim.grid.capture_cells(0)
	var b := sim.grid.capture_cells(1)
	ok(a.has(c(x.x, x.y)) and b.has(c(x.x, x.y)), "真ん中のマスは 2 人とも取るマスに入る")
	var ev := moves(sim, 1)
	ok(not sim.is_over(), "負けは出ない")
	eq(of_type(ev, "capture").size(), 2, "2 人とも塗る")
	eq(sim.grid.owner[c(x.x, x.y)], 0, "重なったマスの持ち主は変わらない")
	eq(sim.grid.owner[c(19, 5)], 2, "P2 だけが取るマス(P1 の輪)は P2 の物")
	eq(sim.grid.owner[c(11, 13)], 1, "P1 の線は P1 の物")
	eq(sim.grid.trail_count(0) + sim.grid.trail_count(1), 0, "2 人の線は消える")
	return true


func test_ac17_zero_land_loses() -> bool:
	var sim := moving()
	for i in Grid.N:
		if sim.grid.owner[i] == 1:
			sim.grid.owner[i] = 0
	land(sim, 0, [Vector2i(30, 5)])
	var ring: Array = []
	for yy in range(4, 7):
		for xx in range(29, 32):
			if Vector2i(xx, yy) != Vector2i(30, 5):
				ring.append(Vector2i(xx, yy))
	land(sim, 1, ring)
	put(sim, 0, 5, 20, 2)
	put(sim, 1, 36, 12, 1)
	trail(sim, 1, [Vector2i(36, 12)])
	moves(sim, 1)
	ok(sim.is_over(), "終わる")
	eq([sim.result()["winner"], sim.result()["reason"]], [1, Sim.REASON_ZERO], "陣地が 0 になった人が負ける")
	return true


func test_e9_trail_over_opponent_land() -> bool:
	var sim := moving()
	put(sim, 0, 35, 12, 1)
	trail(sim, 0, [Vector2i(35, 12)])
	put(sim, 1, 39, 2, 0)
	moves(sim, 2)
	eq(sim.grid.trail[c(37, 12)], 1, "相手の陣地の上も自分の線になる")
	eq(sim.grid.owner[c(37, 12)], 2, "持ち主はそのまま")
	return true


func test_events_are_per_step() -> bool:
	var sim := moving()
	moves(sim, 3)
	ok(not sim.events().is_empty(), "陣地を出た step には trail_start")
	run(sim, 1)
	eq(sim.events(), [], "直前の step の出来事だけ")
	var snap := sim.snapshot()
	for k: String in ["owner", "trail", "heads", "dirs", "queues", "counts", "remaining", "phase"]:
		ok(snap.has(k), "snapshot に %s" % k)
	snap["owner"][0] = 9
	ok(sim.grid.owner[0] != 9, "snapshot は写し")
	return true
