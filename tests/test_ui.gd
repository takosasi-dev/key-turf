# 画面の流れのテスト(AC-19〜AC-21 のヘッドレスで見られる分・FR-15・FR-17・FR-19・FR-22・FR-25〜FR-30・E-13〜E-15・E-21)。
# main.tscn を木に置き、キーのイベントを直接渡し、フレームは _process を呼んで進める。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Board := preload("res://ui/board.gd")


static func kev(pk: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = pressed
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	e.echo = echo
	return e


func _main() -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


static func kp(m: Node, pk: int) -> void:
	m._input(kev(pk))


static func frames(m: Node, n: int, dt: float = 1.0 / 60.0) -> void:
	for k in n:
		if m.play != null:
			m.play._process(dt)
		if m.current != null and m.current.has_method("_process") and m.current != m.play:
			m.current._process(dt)


# 数えを済ませる(1.5 秒 = 90 フレーム)。
static func past_countdown(m: Node) -> void:
	frames(m, B.COUNTDOWN_TICKS / 2 + 1)


# 今のラウンドを、勝者 w・理由 why で終わらせる。
static func end_round(m: Node, w: int, why: int = Sim.REASON_CUT) -> void:
	var sim: Sim = m.play.sim
	sim.phase = Sim.PHASE_OVER
	sim.winner = w
	sim.reason = why
	m.play._round_end(w, why)


# 練習を飛ばし、P1 があと 1 勝で試合に勝つ所まで進めてから勝たせ、結果画面まで進める。
static func win_match(m: Node) -> void:
	var g: Match = m.play.game
	if g.is_practice():
		end_round(m, 0)
		frames(m, B.ROUND_END_TICKS / 2 + 1)
	g.wins[0] = B.WINS_TO_WIN - 1
	end_round(m, 0)
	frames(m, B.OVER_TICKS / 2 + 1)


func test_ac19_flow_keyboard_only() -> bool:
	var m := _main()
	eq(m.screen, "gate", "S0 から始まる")
	kp(m, KEY_X)
	eq(m.screen, "title", "どれかのキーで S1")
	ok(m.play == null, "S0 のキーはゲームの操作に数えない")
	var names: Array = m.current.menu.buttons.map(func(b: Button) -> String: return String(b.name))
	eq(names, ["easy", "normal", "duo", "settings"], "入口は CPU と(やさしい)・CPU と(ふつう)・ふたりで の順(FR-1)")
	kp(m, KEY_ENTER)
	eq(m.screen, "play", "Enter で CPU と(やさしい)")
	eq(m.play.mode, Sim.MODE_EASY, "やさしい")
	ok(m.play.game.is_practice(), "その起動で最初の試合は練習から(FR-15)")
	win_match(m)
	eq(m.screen, "result", "試合が終わると S3")
	ok(m.current.headline.begins_with("あなた の勝ち"), "勝者と勝ち数: %s" % m.current.headline)
	kp(m, KEY_ENTER)
	eq(m.screen, "result", "300 ms の前は押せない")
	m.current._shown_at -= 1000
	frames(m, 1)
	kp(m, KEY_ENTER)
	eq(m.screen, "play", "もう1回(Enter)")
	eq(m.play.mode, Sim.MODE_EASY, "同じ入口(FR-22)")
	ok(not m.play.game.is_practice(), "もう1回に練習は入らない")
	win_match(m)
	m.current._shown_at -= 1000
	frames(m, 1)
	kp(m, KEY_R)
	eq(m.screen, "play", "R でももう1回")
	_done(m)
	return true


func test_records_and_title_line() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.play.mode, Sim.MODE_NORMAL, "↓ Enter で CPU と(ふつう)")
	win_match(m)
	eq(m.store.cpu_record(2), {"win": 1, "lose": 0, "draw": 0}, "ふつうの通算を保存")
	var labels := _texts(m.current)
	ok(labels.has("CPU(ふつう)の通算  1勝 0敗"), "結果に段の通算: %s" % [labels])
	m.current._shown_at -= 1000
	frames(m, 1)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.screen, "title", "タイトルへ")
	ok(_texts(m.current).has("1勝 0敗"), "タイトルに記録")
	kp(m, KEY_DOWN)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.play.mode, Sim.MODE_DUO, "ふたりで")
	ok(not m.play.game.is_practice(), "2 試合目からは練習が無い")
	m.play.game.wins[1] = 2
	end_round(m, 1)
	frames(m, B.OVER_TICKS / 2 + 1)
	eq(m.store.cpu_record(1), {"win": 0, "lose": 0, "draw": 0}, "ふたりでは数えない")
	ok(m.current.headline.begins_with("P2 の勝ち"), "ふたりでは P1・P2")
	_done(m)
	return true


static func _texts(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	return out


func test_fr17_banner_then_next_round() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	end_round(m, 0)  # 練習
	frames(m, B.ROUND_END_TICKS / 2 + 1)
	ok(not m.play.game.is_practice(), "練習の後は本番")
	eq(m.play._hud["round"].text, "ラウンド 1", "ラウンド 1")
	end_round(m, 1, Sim.REASON_SELF)
	eq(m.play._banner.text, "CPU やさしい の勝ち — 自分の線に入った", "決着の帯(FR-17)")
	eq(m.play.game.wins, [0, 1] as Array[int], "勝ち数")
	frames(m, 10)
	eq(m.play._hud["round"].text, "ラウンド 1", "帯の間は次へ進まない")
	frames(m, B.ROUND_END_TICKS / 2)
	eq(m.play._hud["round"].text, "ラウンド 2", "2 秒後に次のラウンド")
	eq(m.play.sim.phase, Sim.PHASE_COUNT, "盤は初めの形から数え")
	end_round(m, -1, Sim.REASON_HEADON)
	eq(m.play._banner.text, "引き分け — 正面衝突", "引き分けの帯")
	_done(m)
	return true


func test_fr19_hud_percent_time_round() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	eq(m.play._hud["pct0"].text, "2%", "25 × 100 ÷ 1248 の切り捨て")
	eq(m.play._hud["round"].text, "練習(数えない)", "練習の間")
	eq(m.play._hud["time"].text, "0:15", "練習は 15 秒")
	eq(m.play._hud["name0"].text, "あなた", "CPU の試合では「あなた」")
	eq(m.play._hud["keys0"].text, "W A S D / 矢印", "キーの札")
	eq(m.play._hud["name1"].text, "CPU やさしい", "P2 は CPU")
	ok(m.play._note.visible, "練習の案内")
	eq(m.play._count.text, "3", "数え")
	frames(m, 30)
	eq(m.play._count.text, "2", "0.5 秒ごと")
	frames(m, 61)
	eq(m.play._count.text, "はじめ", "はじめ")
	frames(m, 40)
	eq(m.play._count.text, "", "はじめは 0.5 秒")
	_done(m)
	return true


func test_d14_solo_arrows_drive_p1_and_filters() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	var e := kev(KEY_W)
	e.ctrl_pressed = true
	m._input(e)
	e = kev(KEY_W)
	e.alt_pressed = true
	m._input(e)
	e = kev(KEY_W)
	e.meta_pressed = true
	m._input(e)
	m._input(kev(KEY_W, true, true))
	m._input(kev(KEY_SPACE))
	m._input(kev(KEY_ENTER))
	eq(m.play.sim.queues[0], [], "押しっぱなし・Ctrl・Alt・Meta 付き・Space・Enter は届かない(FR-27)")
	kp(m, KEY_UP)
	eq(m.play.sim.queues[0], [0], "CPU の試合では矢印も P1 の向き(E-15)")
	kp(m, KEY_S)
	eq(m.play.sim.queues[0], [0], "予約の最後の逆は捨てる")
	kp(m, KEY_D)
	eq(m.play.sim.queues[0], [0, 1], "続けて 2 つまで予約できる(FR-3)")
	_done(m)
	return true


func test_duo_keys_split() -> bool:
	var m := _main()
	m.first_match = false
	kp(m, KEY_X)
	kp(m, KEY_DOWN)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.play.mode, Sim.MODE_DUO, "ふたりで")
	eq(m.play._hud["keys0"].text, "W A S D", "左の人")
	eq(m.play._hud["keys1"].text, "↑←↓→", "右の人")
	kp(m, KEY_W)
	kp(m, KEY_DOWN)
	eq(m.play.sim.queues, [[0], [2]], "W は P1、↓ は P2(FR-2)")
	_done(m)
	return true


func test_fr27_ctrl_r_on_result_does_nothing() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	win_match(m)
	m.current._shown_at -= 1000
	frames(m, 1)
	var e := kev(KEY_R)
	e.ctrl_pressed = true
	m._input(e)
	eq(m.screen, "result", "結果画面の Ctrl+R では「もう1回」にしない")
	_done(m)
	return true


func test_ac20_pause_freezes_and_keeps_queue() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	past_countdown(m)
	frames(m, 20)
	kp(m, KEY_ESCAPE)
	ok(m.pause_view != null, "Esc で一時停止")
	var head: int = m.play.sim.heads[0]
	var rem: int = m.play.sim.remaining
	kp(m, KEY_W)
	frames(m, 120)
	eq(m.play.sim.heads[0], head, "頭が動かない")
	eq(m.play.sim.remaining, rem, "残り時間も減らない")
	eq(m.play.sim.queues[0], [], "一時停止の間のキーは届かない")
	kp(m, KEY_ESCAPE)
	ok(m.pause_view == null, "Esc で続ける")
	kp(m, KEY_W)
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.pause_view != null, "フォーカスが外れると一時停止(E-13)")
	eq(m.play.sim.queues[0], [0], "予約は消さない")
	var rem2: int = m.play.sim.remaining
	frames(m, 60)
	eq(m.play.sim.remaining, rem2, "戻っても自動では再開しない")
	_done(m)
	return true


func test_pause_settings_back_and_restart() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	kp(m, KEY_ESCAPE)
	kp(m, KEY_DOWN)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.screen, "settings", "一時停止から設定")
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)  # 上から 音量・揺れ
	eq(m.store.settings()["shake"], false, "揺れを切って保存")
	kp(m, KEY_ESCAPE)
	eq(m.screen, "play", "戻ると一時停止へ")
	ok(m.pause_view != null and m.pause_view.visible, "一時停止の画面")
	eq(m.play.shake_on, false, "設定がプレイに届く")
	kp(m, KEY_R)
	eq(m.screen, "play", "R でやり直す")
	ok(m.pause_view == null and m.play.sim.step_no == 0, "新しい試合")
	ok(not m.play.game.is_practice(), "やり直しに練習は入らない")
	_done(m)
	return true


func test_ac21_no_shake_when_off() -> bool:
	var m := _main()
	m.store.set_setting("shake", false)
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	end_round(m, 0)
	frames(m, 3)
	eq(m.play.position, Vector2.ZERO, "揺れを切ると決着でも動かない")
	m.play.shake_on = true
	m.play._shake(B.SHAKE_END_PX, B.SHAKE_END_MS)
	var moved := false
	for k in 5:
		frames(m, 1, 0.0)
		moved = moved or m.play.position != Vector2.ZERO
	ok(moved, "入なら揺れる")
	_done(m)
	return true


func test_e21_at_most_8_ticks_per_frame() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	frames(m, 1)
	var n: int = m.play.sim.step_no
	frames(m, 1, 1.0)
	eq(m.play.sim.step_no - n, B.MAX_STEPS_PER_FRAME, "1 フレーム 8 tick まで")
	_done(m)
	return true


func test_gate_touch_note() -> bool:
	var m := _main()
	var t := InputEventScreenTouch.new()
	t.pressed = true
	m._input(t)
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.device = InputEvent.DEVICE_ID_EMULATION
	m._input(mb)
	eq(m.screen, "gate", "タッチと、そこから作られたマウスでは進まない(FR-30)")
	ok(m._touch_note.visible, "キーボードで遊ぶ案内が出る")
	_done(m)
	return true


func test_ime_note_on_zero_keycode() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	m._input(kev(KEY_NONE))
	frames(m, 1)
	ok(m.play._ime.visible, "physical_keycode が 0 のキーで日本語入力の案内(共通 §3 の 9)")
	_done(m)
	return true


func test_fr29_keytest_lights_both_players() -> bool:
	var m := _main()
	kp(m, KEY_X)
	for k in 3:
		kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.screen, "settings", "タイトルから設定")
	for k in 3:
		kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	ok(m.current.keytest, "キーの確かめ")
	kp(m, KEY_W)
	kp(m, KEY_UP)
	ok(m.current.held.has(KEY_W) and m.current.held.has(KEY_UP), "2 人のキーが同時に光る")
	m._input(kev(KEY_W, false))
	ok(not m.current.held.has(KEY_W) and m.current.held.has(KEY_UP), "離すと消える")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.current.held.is_empty(), "フォーカスが外れたら全部離す(共通 §3 の 5)")
	kp(m, KEY_ESCAPE)
	ok(not m.current.keytest and m.screen == "settings", "Esc で設定へ")
	kp(m, KEY_ESCAPE)
	eq(m.screen, "title", "Esc でタイトルへ")
	_done(m)
	return true


func test_nfr12_reduce_flash_alpha() -> bool:
	var b := Board.new()
	b.reduce_flash = true
	ok(b._flash(0.9) <= 0.2, "点滅を弱めると不透明度 20% 以下")
	b.reduce_flash = false
	eq(b._flash(0.9), 0.9, "切なら そのまま")
	b.free()
	return true


func test_capture_fx_and_draw_runs() -> bool:
	var m := _main()
	m.first_match = false
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	var sim: Sim = m.play.sim
	sim.phase = Sim.PHASE_MOVE
	sim.count_tick = B.COUNTDOWN_TICKS
	m.play._refresh()
	put(sim, 0, 11, 13, 3)
	trail(sim, 0, [Vector2i(11, 13), Vector2i(11, 12)])
	m.play._refresh()
	frames(m, 8)
	var b: Board = m.play.board
	ok(not b.floats.is_empty(), "囲むと「+n」が浮かぶ")
	ok(not b.reveal.is_empty(), "取ったマスを順に塗る")
	_done(m)
	return true
