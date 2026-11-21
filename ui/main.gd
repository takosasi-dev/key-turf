# 画面の切り替え(S0〜S5)・入力の振り分け・保存・自動の一時停止を受け持つ。ゲームの決まりは持たない(INV-1)。
# ?keys=1(または --keys)でキーの確かめの画面(共通 §3 の 22)。--auto=easy|normal|duo は窓なしの smoke 用で、
# S0 → 入口 → 試合(P1 にも CPU を付ける)→ 結果まで進め、画面が変わるたびに「SMOKE screen=...」を印字する。作りは KeySwat の ui/main.gd。
extends Node

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Store := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Play := preload("res://ui/play.gd")
const Title := preload("res://ui/title.gd")
const Result := preload("res://ui/result.gd")
const Settings := preload("res://ui/settings.gd")
const Pause := preload("res://ui/pause.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const Wipe := preload("res://ui/wipe.gd")
const Logo := preload("res://ui/logo.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const MODES := {"duo": Sim.MODE_DUO, "easy": Sim.MODE_EASY, "normal": Sim.MODE_NORMAL}

var stage: Control
var store: Store
var screen := "gate"  # gate / title / play / result / settings / keys
var current: Control = null  # 今の画面(play の時は play)
var play: Play = null
var pause_view: Pause = null
var settings_from := "title"
var run_mode := 0  # 今の試合の入口
var first_match := true  # その起動で最初の試合だけ練習を入れる(FR-15)
var keys_mode := false
var auto := ""  # smoke の入口(easy / normal / duo)。空なら人が遊ぶ
var key_log: Array = []  # 届いたキーの中身(直近 40 個。キーの確かめが読む)
var _touch_note: Label = null
var _gate_start: Label = null
var backdrop: Backdrop
var wipe: Wipe
var view := Rect2(0, 0, 1280, 720)  # 舞台の座標で、窓に見えている範囲
var entering: Array = []  # [画面, 始めた時刻(ms), 長さ(ms), 上がる幅(px)]。_process が濃さと位置を進める
var _keys_label: Label = null
var _visibility_cb: Variant = null
var _settings_overlay: Control = null
var _esc_count := 0
var debug := false  # ?debug=1: window.ktState に状態を出す(Web の自動の確かめが読むだけ。作りは KeySwat)
var frame_ms: Array = []
var _last_frame := 0


func _ready() -> void:
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	add_child(stage)
	backdrop = Backdrop.new()
	stage.add_child(Kit.place(backdrop, 0, 0, 1280, 720))
	wipe = Wipe.new()
	stage.add_child(Kit.place(wipe, 0, 0, 1280, 720))
	store = Store.new()
	get_viewport().size_changed.connect(_layout)  # 縦横比が 16:9 でない窓では、余りにも卓の背景を敷いて舞台を真ん中へ(共通 §3 の 1)
	_layout()
	_apply_settings()
	keys_mode = _flag("keys")
	debug = _flag("debug")
	if debug:
		RenderingServer.frame_post_draw.connect(_after_draw)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--auto="):
			auto = a.substr(7)
	_watch_visibility()
	_show_gate()


# 舞台を見えている範囲の真ん中に置き、背景と切り替わりにその範囲を渡す(project.godot の aspect=expand)。
func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	stage.position = ((vs - stage.size) / 2.0).floor()
	view = Rect2(-stage.position, vs)
	backdrop.view = view
	wipe.view = view
	backdrop.queue_redraw()
	for c in stage.get_children():
		if c.has_method("set_view"):
			c.set_view(view)
	if pause_view != null:
		pause_view.set_view(view)


# 点滅を弱める 入は、画面の切り替わり・題字・背景・はね などの動きも止める(動きを減らす設定を兼ねる)。
func reduce_motion() -> bool:
	return bool(store.settings()["reduce_flash"])


# 新しい画面を舞台に置き、current にする。motion: "wipe"(マスが縮んで消え、薄く→濃く)/ "fade"(薄く→濃くだけ)/ "none"。
# 切り替えはその場で済ませ、動きは上に重ねるだけ(動いている間のキーも新しい画面に届く)。
func _show(node: Control, motion: String) -> void:
	stage.add_child(node)
	stage.move_child(wipe, -1)
	if node.has_method("set_view"):
		node.set_view(view)
	current = node
	if motion != "none" and not reduce_motion():
		_animate_in(node, B.ENTER_MS, B.ENTER_RISE_PX if motion == "wipe" else 0.0)
		if motion == "wipe":
			wipe.run()


func _animate_in(node: Control, ms: int, rise: float) -> void:
	node.modulate.a = 0.0
	entering.append([node, Time.get_ticks_msec(), ms, rise])


# 入りの動きの濃さ(0→1)。時刻だけで決まる。
static func enter_alpha(since_ms: int, ms: int) -> float:
	return Kit.ease_out(float(since_ms) / ms)


func _step_entering() -> void:
	var now := Time.get_ticks_msec()
	var keep: Array = []
	for e: Array in entering:
		var node: Variant = e[0]
		if not is_instance_valid(node) or not (node as Control).is_inside_tree():
			continue
		var c := node as Control
		var k := enter_alpha(now - int(e[1]), int(e[2]))
		c.modulate.a = k
		if c != play:  # play は揺れで自分の位置を毎フレーム決める
			c.position.y = float(e[3]) * (1.0 - k)
		if k < 1.0:
			keep.append(e)
	entering = keep


static func _flag(flag: String) -> bool:
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("location.search", true)
		return q is String and q.contains(flag + "=1")
	return OS.get_cmdline_user_args().has("--" + flag)


func _apply_settings() -> void:
	Sfx.set_volume(int(store.settings()["volume"]))


func _clear() -> void:
	if pause_view != null:
		pause_view.queue_free()
		pause_view = null
	for c in stage.get_children():
		if c == backdrop or c == wipe:
			continue
		c.queue_free()
	entering.clear()
	_gate_start = null
	current = null
	play = null
	_settings_overlay = null


func _set_screen(s: String) -> void:
	screen = s
	backdrop.demo = s in ["gate", "title"]
	backdrop.animate = not reduce_motion()
	backdrop.queue_redraw()
	if auto != "":
		var extra := ""
		if s == "result" and current != null:
			extra = " " + (current as Result).headline
		print("SMOKE screen=%s%s" % [s, extra])


# --- S0 始める ---

func _show_gate() -> void:
	_clear()
	var g := Control.new()
	g.size = Vector2(1280, 720)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := Logo.new()
	logo.animate = not reduce_motion()
	g.add_child(Kit.place(logo, 0, 170, 1280, 200))
	_gate_start = Kit.label(S.S0_START, 30, Kit.C_PAPER, 700)
	g.add_child(Kit.place(_gate_start, 0, 412, 1280, 48))
	g.add_child(Kit.place(Kit.label(S.S0_KEYBOARD, 18, Kit.C_DIM, 500), 0, 462, 1280, 30))
	_touch_note = Kit.label(S.TOUCH, 22, Kit.C_WARN, 700)
	_touch_note.visible = false
	_touch_note.add_theme_stylebox_override("normal", note_box(Kit.C_WARN))
	g.add_child(Kit.place(_touch_note, 290, 520, 700, 48))
	_show(g, "fade")
	_set_screen("gate")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_log_key(event)
	if screen == "gate":
		if event is InputEventScreenTouch and event.pressed:
			_touch_note.visible = true  # FR-30: タッチで開いた人に伝える
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
			return  # タッチから作られたマウスのイベント(FR-30 の案内を出したまま止まる)
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			Sfx.unlock()  # FR-26: この入力は数えない
			get_viewport().set_input_as_handled()
			if keys_mode:
				_show_keys()
			else:
				_show_title()
		return
	if not (event is InputEventKey):
		return
	if screen != "play" and event.pressed and (event.ctrl_pressed or event.meta_pressed or event.alt_pressed):
		return  # S2 以外の Ctrl・Alt・Meta 付きのキーは操作に数えない(FR-27・共通 §3 の 4。Ctrl+R で「もう1回」にしない)
	get_viewport().set_input_as_handled()  # Tab・矢印を Godot のフォーカスの移動に使わせない
	if screen == "keys":
		_keys_input(event)
	elif screen == "settings":
		current.key(event)
	elif pause_view != null:
		pause_view.key(event)
	elif current != null and current.has_method("key"):
		current.key(event)


# 案内の札の地(墨の板に、色の縁を左に)。
static func note_box(edge: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(Kit.C_INK, 0.9)
	b.border_color = edge
	b.border_width_left = 6
	b.set_corner_radius_all(4)
	b.content_margin_left = 18
	b.content_margin_right = 18
	return b


# 動きを進め、smoke では S0 → 入口 → 結果まで自動で進める。
func _process(_delta: float) -> void:
	if not entering.is_empty():
		_step_entering()
	if _gate_start != null and is_instance_valid(_gate_start):
		var k := float(Time.get_ticks_msec() % B.GATE_PULSE_MS) / B.GATE_PULSE_MS
		_gate_start.modulate.a = 1.0 if reduce_motion() else 0.78 + 0.22 * cos(k * TAU)
	if auto == "":
		return
	if screen == "gate":
		var k := InputEventKey.new()
		k.pressed = true
		k.physical_keycode = KEY_X
		_input(k)
	elif screen == "title":
		_on_title(auto)
	elif screen == "result":
		get_tree().quit()


# --- S1 タイトル ---

func _show_title() -> void:
	_clear()
	var t := Title.new()
	t.animate = not reduce_motion()
	t.build(store)
	t.chosen.connect(_on_title)
	_show(t, "wipe")
	_set_screen("title")


func _on_title(what: String) -> void:
	if what == "settings":
		_show_settings("title")
	elif MODES.has(what):
		_start(MODES[what], first_match, "wipe")
		first_match = false


static func _new_seed() -> int:
	var s := Time.get_ticks_usec() & 0xFFFFFFFF
	return s if s != 0 else 1


# --- S2 プレイ ---

# motion: タイトルからは "wipe"。もう1回・やり直すは "none"(押してすぐ遊べるように動きを付けない)。
func _start(mode: int, with_practice: bool, motion: String = "none") -> void:
	_clear()
	run_mode = mode
	play = Play.new()
	var st: Dictionary = store.settings()
	play.shake_on = st["shake"]
	play.reduce_flash = st["reduce_flash"]
	play.auto_p1 = auto != ""
	_show(play, motion)
	play.start(mode, with_practice, _new_seed())
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_pause)
	_set_screen("play")


func _pause() -> void:
	if play == null or pause_view != null or not play.is_playing():
		return
	play.paused = true
	pause_view = Pause.new()
	pause_view.build()
	pause_view.picked.connect(_on_pause)
	pause_view.set_view(view)
	stage.add_child(pause_view)
	stage.move_child(wipe, -1)
	if not reduce_motion():
		_animate_in(pause_view, B.PAUSE_IN_MS, 0.0)


func _on_pause(what: String) -> void:
	match what:
		"resume":
			pause_view.queue_free()
			pause_view = null
			play.paused = false  # 押した tick から再開(待ち時間なし)
		"restart":
			_start(run_mode, false)  # 今の試合を初めから(練習は入れない)
		"settings":
			_show_settings("pause")
		"title":
			_show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focus_lost()


# E-13: 一時停止にし、押されているキーは全部離したものとする。予約は消さない。戻っても自動では再開しない。
func _focus_lost() -> void:
	_pause()
	if current != null and current.has_method("release_all"):
		current.release_all()


# タブが裏に回ったら一時停止にする。Web では通知が来ないことがあるので、ブラウザにも聞く(ParryDuel と同じ)。
func _watch_visibility() -> void:
	if not OS.has_feature("web"):
		return
	_visibility_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void: _focus_lost())
	var doc: Variant = JavaScriptBridge.get_interface("document")
	if doc != null:
		doc.addEventListener("visibilitychange", _visibility_cb)


# --- S3 結果 ---

func _on_finished(result: Dictionary) -> void:
	var mode := run_mode
	if auto != "" and play != null:
		print("SMOKE board_draws=%d rounds=%d" % [play.board.draws, (result["rounds"] as Array).size()])
	var saved := store.record_match(mode, int(result["winner"]))
	var record: Dictionary = store.cpu_record(mode) if mode != Sim.MODE_DUO else {}
	_clear()
	var v := Result.new()
	v.build(mode, result, record, saved)
	v.retry.connect(func() -> void: _start(mode, false))  # FR-22: 同じ入口、練習は入らない
	v.to_title.connect(_show_title)
	_show(v, "wipe")
	_set_screen("result")


# --- S4 設定 ---

func _show_settings(from: String) -> void:
	settings_from = from
	var s := Settings.new()
	s.build(store)
	s.back.connect(_settings_back.bind(s))
	if from == "pause":
		pause_view.visible = false
		pause_view.process_mode = Node.PROCESS_MODE_DISABLED
		var dim := ColorRect.new()
		dim.color = Color(Kit.C_BG, 0.97)
		s.add_child(Kit.place(dim, -2000, -2000, 5280, 4720))
		s.move_child(dim, 0)
		_settings_overlay = s
		_show(s, "fade")
	else:
		_clear()
		_show(s, "wipe")
	_set_screen("settings")


func _settings_back(s: Control) -> void:
	_apply_settings()
	if settings_from == "pause" and play != null:
		var st: Dictionary = store.settings()
		play.shake_on = st["shake"]
		play.reduce_flash = st["reduce_flash"]
		play.board.reduce_flash = st["reduce_flash"]
		s.queue_free()
		_settings_overlay = null
		pause_view.visible = true
		pause_view.process_mode = Node.PROCESS_MODE_INHERIT
		current = play
		_set_screen("play")
	else:
		_show_title()


# --- キーの確かめ(共通 §3 の 22) ---

func _show_keys() -> void:
	_clear()
	var g := Control.new()
	g.size = Vector2(1280, 720)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(Kit.place(Kit.label(S.KEYS_TITLE, 24, Kit.C_TEXT, 700), 0, 18, 1280, 44))
	_keys_label = Kit.label("", 16, Kit.C_TEXT, 500)
	_keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_keys_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var sheet := StyleBoxFlat.new()
	sheet.bg_color = Color(Kit.C_INK, 0.92)
	sheet.border_color = Kit.C_EDGE
	sheet.set_border_width_all(2)
	sheet.set_corner_radius_all(6)
	sheet.set_content_margin_all(16)
	_keys_label.add_theme_stylebox_override("normal", sheet)
	g.add_child(Kit.place(_keys_label, 60, 72, 1160, 600))
	_show(g, "fade")
	_set_screen("keys")


func _keys_input(ev: InputEventKey) -> void:
	if not ev.pressed:
		return
	_keys_label.text = "\n".join(key_log.slice(maxi(key_log.size() - 22, 0)).map(func(k: Dictionary) -> String: return JSON.stringify(k)))
	_esc_count = _esc_count + 1 if ev.physical_keycode == KEY_ESCAPE else 0
	if _esc_count >= 2:
		keys_mode = false
		_show_title()


func _log_key(ev: InputEventKey) -> void:
	key_log.append({"pk": ev.physical_keycode, "pk_name": OS.get_keycode_string(ev.physical_keycode), "label": OS.get_keycode_string(ev.key_label),
		"unicode": ev.unicode, "echo": ev.echo, "shift": ev.shift_pressed, "ctrl": ev.ctrl_pressed, "alt": ev.alt_pressed, "meta": ev.meta_pressed})
	if key_log.size() > 40:
		key_log.pop_front()


# --- デバッグ用の窓口(?debug=1 の時だけ。読むだけ。作りは KeySwat) ---

func _after_draw() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame > 0 and frame_ms.size() < 20000:
		frame_ms.append((now - _last_frame) / 1000.0)
	_last_frame = now
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ktState=" + JSON.stringify(JSON.stringify(state())), true)
		if frame_ms.size() % 60 == 0:
			JavaScriptBridge.eval("window.ktStats=" + JSON.stringify(JSON.stringify(stats())), true)


func state() -> Dictionary:
	var out := {"screen": screen, "paused": pause_view != null, "version": S.VERSION, "keys": key_log.slice(maxi(key_log.size() - 20, 0)),
		"buttons": {}, "sfx": Sfx.played, "sfx_last": Sfx.last, "unlocked": Sfx.unlocked, "save_failed": store.write_failed,
		"load_failed": store.load_failed}
	var root: Control = pause_view if pause_view != null and pause_view.visible else current
	if root != null:
		for b in root.find_children("*", "Button", true, false):
			var btn := b as Button
			if btn.is_visible_in_tree() and not btn.disabled:
				var c := btn.global_position - stage.global_position + btn.size / 2  # 舞台の座標(1280×720)
				out["buttons"][String(btn.name)] = [c.x, c.y]
	if play != null and play.sim != null:
		var sn: Dictionary = play.sim.snapshot()
		sn["owner"] = Array(sn["owner"])
		sn["trail"] = Array(sn["trail"])
		sn["pos"] = [play.position.x, play.position.y]
		sn["wins"] = Array(play.game.wins)
		sn["practice"] = play.game.is_practice()
		sn["wait"] = play._wait
		sn["over"] = play._match_over
		sn["banner"] = play._banner.text
		out["play"] = sn
	if screen == "result" and current is Result:
		out["headline"] = (current as Result).headline
	return out


func stats() -> Dictionary:
	return {"frame": _pct(frame_ms)}


@warning_ignore("integer_division")
static func _pct(list: Array) -> Dictionary:
	if list.is_empty():
		return {"n": 0}
	var s := list.duplicate()
	s.sort()
	return {"n": s.size(), "p50": s[s.size() / 2], "p95": s[mini(int(ceil(s.size() * 0.95)) - 1, s.size() - 1)], "max": s[-1]}
