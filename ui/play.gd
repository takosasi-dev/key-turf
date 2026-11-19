# S2 プレイ(画面設計書 §3)。試合(core/match)のラウンドを順に作り、sim をたまった時間ぶん進め(1 フレーム 8 tick まで)、
# events で演出と音を出し、snapshot を盤に渡す。ゲームの決まりは持たない(INV-1)。押したキーは ui/keymap で人と向きにして渡すだけ。
# ラウンドの間(ROUND_END_TICKS)と試合の決着から結果まで(OVER_TICKS)は、ここで tick を数える(時刻でなく delta で数える)。
extends Control

signal finished(result: Dictionary)
signal pause_requested

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Match := preload("res://core/match.gd")
const Cpu := preload("res://core/cpu.gd")
const Bots := preload("res://core/bots.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")
const Board := preload("res://ui/board.gd")

var game: Match = null
var sim: Sim = null
var mode := 0
var paused := false
var shake_on := true
var reduce_flash := false
var auto_p1 := false  # 自動の確かめ(smoke): P1 にも CPU(やさしい)を付ける
var board: Board
var _acc := 0.0
var _wait := -1  # ラウンドが終わってからの tick(-1 は動いている)
var _match_over := false
var _shake_until := 0
var _shake_px := 0.0
var _ime_until := 0
var _last_sec := -1
var _snap: Dictionary = {}
var _practice := false  # 今のラウンドが練習か(決着の帯の間も、終わったラウンドの札を出す)
var _round_text := ""
var _hud: Dictionary = {}
var _count: Label
var _banner: Label
var _banner_bg: ColorRect
var _note: Label
var _ime: Label


func _ready() -> void:
	size = Vector2(1280, 720)
	board = Board.new()
	Kit.place(board, 0, 0, 1280, 720)
	add_child(board)
	for p in 2:
		var name_l := Kit.label("", 22, Kit.C_TEXT, 700)
		var keys_l := Kit.label("", 15, Kit.C_DIM, 500)
		var pct := Kit.label("", 32, Kit.C_TEXT, 800)
		var al := HORIZONTAL_ALIGNMENT_LEFT if p == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		name_l.horizontal_alignment = al
		keys_l.horizontal_alignment = al
		add_child(Kit.place(name_l, 64 if p == 0 else 1020, 4, 196, 32))
		add_child(Kit.place(keys_l, 64 if p == 0 else 1020, 36, 196, 24))
		add_child(Kit.place(pct, 264 if p == 0 else 936, 8, 80, 52))
		_hud["name%d" % p] = name_l
		_hud["keys%d" % p] = keys_l
		_hud["pct%d" % p] = pct
	var time_l := Kit.label("", 32, Kit.C_TEXT, 800)
	time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(Kit.place(time_l, 520, 8, 136, 52))
	_hud["time"] = time_l
	var round_l := Kit.label("", 18, Kit.C_DIM, 700)
	round_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(round_l, 668, 8, 180, 52))
	_hud["round"] = round_l
	_count = Kit.label("", 120, Kit.C_TEXT, 800)
	add_child(Kit.place(_count, 0, 300, 1280, 160))
	_banner_bg = ColorRect.new()
	_banner_bg.color = Color(Kit.C_BG, 0.86)
	_banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(_banner_bg, 64, 340, 1152, 80))
	_banner = Kit.label("", 40, Kit.C_TEXT, 800)
	add_child(Kit.place(_banner, 0, 340, 1280, 80))
	_note = Kit.label(S.PRACTICE_NOTE, 20, Kit.C_TEXT, 700)
	add_child(Kit.place(_note, 0, 660, 1280, 32))
	_ime = Kit.label(S.IME, 22, Kit.C_WARN, 700)
	add_child(Kit.place(_ime, 0, 620, 1280, 36))
	_banner_bg.visible = false


# mode: 0 = ふたりで、1 = やさしい、2 = ふつう(FR-1)。
func start(p_mode: int, with_practice: bool, p_seed: int) -> void:
	mode = p_mode
	game = Match.new(p_mode, with_practice, p_seed)
	paused = false
	_match_over = false
	board.reduce_flash = reduce_flash
	var names: Array = S.NAMES[mode]
	for p in 2:
		_hud["name%d" % p].text = names[p]
	_hud["keys0"].text = S.KEYS_P1 if mode == Sim.MODE_DUO else S.KEYS_SOLO
	_hud["keys1"].text = S.KEYS_P2 if mode == Sim.MODE_DUO else ""
	_next_round()


func _next_round() -> void:
	sim = game.next_round()
	_practice = game.is_practice()
	_round_text = S.PRACTICE if _practice else S.ROUND % game.round_number()
	if auto_p1:
		Bots.attach_cpu(sim, 0, Cpu.EASY, game.seed_value + game.rounds.size() * 7919)
	board.clear_fx()
	_wait = -1
	_acc = 0.0
	_last_sec = -1
	_banner.text = ""
	_banner_bg.visible = false
	_refresh()


func is_playing() -> bool:
	return sim != null and not _match_over


# S2 のキー。Esc は一時停止、向きのキーは sim へ。Space・Enter などは何もしない(画面設計書 §7)。
func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		pause_requested.emit()
		return
	if ev.pressed and ev.physical_keycode == KEY_NONE:
		_ime_until = Time.get_ticks_msec() + B.IME_NOTE_MS  # 共通 §3 の 9: 日本語入力で物理キーが取れない
	if sim == null or sim.is_over() or paused:
		return
	var t := Keymap.turn_of(ev, mode != Sim.MODE_DUO)
	if t.is_empty():
		return
	if sim.queue_turn(int(t[0]), int(t[1])):
		Sfx.play("turn")
		_refresh()  # 予約の矢印を、押したフレームに描く(§9.10)


func _process(delta: float) -> void:
	if sim == null:
		return
	var now := Time.get_ticks_msec()
	position = Vector2.ZERO
	if shake_on and now < _shake_until:
		position = Vector2(randf_range(-_shake_px, _shake_px), randf_range(-_shake_px, _shake_px))
	_ime.visible = now < _ime_until
	board.queue_redraw()
	if paused:
		return  # 一時停止の間は step を呼ばず、たまった時間も持たない(AC-20)
	_acc += delta * B.TICK_HZ
	var n := int(_acc)
	_acc -= n
	if n > B.MAX_STEPS_PER_FRAME:
		n = B.MAX_STEPS_PER_FRAME  # E-21: 超えた分は捨てる
		_acc = 0.0
	var heard := {}
	for k in n:
		if _wait >= 0:
			_wait += 1
			if _match_over and _wait >= B.OVER_TICKS:
				finished.emit(game.result())
				sim = null
				return
			if not _match_over and _wait >= B.ROUND_END_TICKS:
				_next_round()
				return
			continue
		sim.step()
		for e: Dictionary in sim.events():
			_on_event(e, heard)
	_refresh()


# 演出の表(§9.10)。同じ音は 1 フレーム 1 回。
func _on_event(e: Dictionary, heard: Dictionary) -> void:
	var t: String = e["type"]
	var sound := ""
	var semis := 0
	match t:
		"go":
			sound = "go"
		"trail_start":
			board.on_trail_start(int(e["cell"]))
			sound = "trail"
		"capture":
			var big: bool = int(e["count"]) >= B.BIG_CAPTURE
			board.on_capture(e, int(sim.heads[int(e["p"])]), big)
			if big:
				_shake(B.SHAKE_BIG_PX, B.SHAKE_BIG_MS)
				if not heard.has("chord"):
					for s: int in B.CHORD:
						Sfx.play("capture", s)
					heard["chord"] = true
			sound = "capture"
		"round_end":
			_round_end(int(e["winner"]), int(e["reason"]))
	if sound != "" and not heard.has(sound) and not heard.has("chord"):
		Sfx.play(sound, semis)
	heard[sound] = true


func _round_end(w: int, why: int) -> void:
	board.on_round_end(w, why)
	game.finish_round(sim.result())
	_match_over = game.is_over()
	_wait = 0
	var reason_text: String = S.REASONS[why]
	_banner.text = S.DRAW % reason_text if w < 0 else S.WIN % [S.NAMES[mode][w], reason_text]
	_banner_bg.visible = true
	if why != Sim.REASON_TIME and why != Sim.REASON_TIE:
		_shake(B.SHAKE_END_PX, B.SHAKE_END_MS)
	match why:
		Sim.REASON_CUT:
			Sfx.play("cut")
		Sim.REASON_SELF, Sim.REASON_ZERO:
			Sfx.play("self")
		Sim.REASON_ENCLOSE:
			Sfx.play("enclose")
		Sim.REASON_HEADON, Sim.REASON_BOTH:
			Sfx.play("clash")
		Sim.REASON_TIME:
			Sfx.play("time")
		Sim.REASON_TIE:
			Sfx.play("time", B.TIE_PITCH)
	if _match_over:
		Sfx.play("over")


func _shake(px: float, ms: int) -> void:
	if not shake_on:
		return
	_shake_px = maxf(_shake_px if Time.get_ticks_msec() < _shake_until else 0.0, px)
	_shake_until = maxi(_shake_until, Time.get_ticks_msec() + ms)


@warning_ignore("integer_division")
func _refresh() -> void:
	_snap = sim.snapshot()
	board.snap = _snap
	var counts: Array = _snap["counts"]
	for p in 2:
		_hud["pct%d" % p].text = S.PERCENT % (int(counts[p]) * 100 / 1248)  # FR-19: マス数 × 100 ÷ 1248 の切り捨て
	_hud["round"].text = _round_text
	var rem: int = _snap["remaining"]
	var secs := (rem + B.TICK_HZ - 1) / B.TICK_HZ
	_hud["time"].text = "%d:%02d" % [secs / 60, secs % 60]
	var last := secs <= B.LAST_SECONDS and int(_snap["phase"]) == Sim.PHASE_MOVE
	_hud["time"].add_theme_color_override("font_color", Kit.C_WARN if last else Kit.C_TEXT)
	if last and secs != _last_sec and secs > 0:
		Sfx.play("go", B.COUNT_PITCH)  # 残り 5 秒からは 1 秒ごとに短い音
	_last_sec = secs
	# 数え 3・2・1(各 0.5 秒)、その後「はじめ」0.5 秒
	var phase: int = _snap["phase"]
	if phase == Sim.PHASE_COUNT:
		_count.text = str(3 - int(_snap["count_tick"]) / B.COUNT_STEP_TICKS)
	elif phase == Sim.PHASE_MOVE and int(_snap["round_ticks"]) - rem < B.GO_TICKS:
		_count.text = S.GO
	else:
		_count.text = ""
	_note.visible = _practice and _wait < 0
	queue_redraw()


# 上の帯の勝ち数: ● が取ったラウンド、○ が残り(練習の間は出さない)。
func _draw() -> void:
	if game == null or _practice:
		return
	for p in 2:
		for k in B.WINS_TO_WIN:
			var x := 368 + k * 22 if p == 0 else 912 - k * 22
			var c := Vector2(x, 34)
			if k < game.wins[p]:
				draw_circle(c, 7.0, Kit.C_TRAIL[p], true, -1.0, true)
			else:
				draw_circle(c, 7.0, Kit.C_DIM, false, 2.0, true)
