# S4 設定(共通 §6・FR-24・FR-29)。音量(5 段)・画面の揺れ・点滅を弱める・キーの確かめ。変えたらすぐ保存し、音量はその音量で 1 回鳴らす。
# 項目は名前を左、今の値を右に絵で出す(音量は 5 つの升と数、入・切は札と印)。下にキーの案内(戻り方を画面に書く)。
# キーの確かめ: 左に W A S D、右に 矢印 の図を出し、押されているキーをその人の陣の色と模様で光らせる(E-18)。押す・離すのイベントで自分で持ち、Esc で戻る。
# ← → でも値を変えられる。Esc か「戻る」で来た画面へ。作りは KeySwat の ui/settings.gd。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const Keymap := preload("res://ui/keymap.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const ROW_X := 360.0
const ROW_W := 560.0

var menu: Menu
var store: RefCounted
var keytest := false
var held := {}  # 押されている physical_keycode
var _list: Control
var _test: Control
var _vol: Button
var _shake: Button
var _flash: Button


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list = Control.new()
	_list.size = size
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	_list.add_child(Kit.place(Kit.label(S.SETTINGS, 40, Kit.C_TEXT, 800), 0, 60, 1280, 60))
	_vol = Kit.place(Kit.button("volume", S.SET_VOLUME, 26), ROW_X, 150, ROW_W, 72)
	_shake = Kit.place(Kit.button("shake", S.SET_SHAKE, 26), ROW_X, 236, ROW_W, 72)
	_flash = Kit.place(Kit.button("reduce_flash", S.SET_FLASH, 26), ROW_X, 322, ROW_W, 72)
	var test := Kit.place(Kit.button("keytest", S.SET_KEYTEST, 26), ROW_X, 408, ROW_W, 72)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 26), 520, 516, 240, 64)
	for b: Button in [_vol, _shake, _flash, test]:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var v := Control.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(Kit.place(v, ROW_W - 250, 0, 230, 66))
		v.draw.connect(_draw_value.bind(v, String(b.name)))
	for b: Button in [_vol, _shake, _flash, test, ret]:
		_list.add_child(b)
	_vol.pressed.connect(func() -> void: _step_volume(1))
	_shake.pressed.connect(func() -> void: _toggle("shake"))
	_flash.pressed.connect(func() -> void: _toggle("reduce_flash"))
	test.pressed.connect(func() -> void: _open_test(true))
	ret.pressed.connect(func() -> void: back.emit())
	_list.add_child(Kit.place(KeyHint.new([[["up", "down"], S.HINT_SELECT], [["left", "right"], S.HINT_CHANGE], [["Enter"], S.HINT_DECIDE],
		[["Esc"], S.B_BACK]]), 0, 620, 1280, 40))
	menu = Menu.new([_vol, _shake, _flash, test, ret] as Array[Button], 0)
	_test = Control.new()
	_test.size = size
	_test.visible = false
	_test.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_test)
	_test.add_child(Kit.place(Kit.label(S.SET_KEYTEST, 40, Kit.C_TEXT, 800), 0, 60, 1280, 60))
	_test.add_child(Kit.place(Kit.label(S.KEYTEST_NOTE, 22, Kit.C_DIM, 500), 0, 130, 1280, 36))
	_test.add_child(Kit.place(KeyHint.new([[["Esc"], S.B_BACK]]), 0, 620, 1280, 40))
	_test.draw.connect(_draw_test)
	_paint()


func _paint() -> void:
	for b: Button in [_vol, _shake, _flash]:
		for c in b.get_children():
			(c as CanvasItem).queue_redraw()


# 値の絵。on_paper は選ばれたボタン(象牙の地)の上か。
func _draw_value(v: Control, what: String) -> void:
	var b := v.get_parent() as Button
	var on_paper := b.theme_type_variation == &"SelButton"
	var ink := Kit.C_INK if on_paper else Kit.C_TEXT
	var faint := Color(ink, 0.3)
	var st: Dictionary = store.settings()
	var cy := v.size.y / 2.0
	match what:
		"volume":
			var vol := int(st["volume"])
			var lv: int = B.VOLUMES.find(vol)
			for k in B.VOLUMES.size() - 1:  # 25・50・75・100 の 4 升(0 は全部空)
				var r := Rect2(v.size.x - 228 + k * 34, cy - 12, 26, 26)
				if k < lv:
					v.draw_rect(r, ink)
				else:
					v.draw_rect(r.grow(-1), faint, false, 2.0)
			v.draw_string(Kit.num_font(), Vector2(v.size.x - 84, cy + 12), str(vol), HORIZONTAL_ALIGNMENT_RIGHT, 80, 32, ink)
		"shake", "reduce_flash":
			var on: bool = st[what]
			# 札: 入は塗った札に丸、切は枠だけの札に横線(色だけで分けない)
			var r := Rect2(v.size.x - 120, cy - 18, 112, 36)
			if on:
				v.draw_rect(r, ink)
				v.draw_circle(r.position + Vector2(24, 18), 8.0, Kit.C_PAPER if not on_paper else Kit.C_PAPER, true, -1.0, true)
				v.draw_circle(r.position + Vector2(24, 18), 8.0, ink.lerp(Kit.C_INK, 0.5), false, 2.0, true)
			else:
				v.draw_rect(r.grow(-1), Color(ink, 0.6), false, 2.0)
				v.draw_line(r.position + Vector2(16, 18), r.position + Vector2(32, 18), Color(ink, 0.6), 3.0)
			var tc := (Kit.C_INK if not on_paper else Kit.C_PAPER) if on else Color(ink, 0.75)
			v.draw_string(Kit.font(800), Vector2(r.position.x + 44, cy + 9), S.ON if on else S.OFF, HORIZONTAL_ALIGNMENT_CENTER, 56, 24, tc)
		"keytest":
			Kit.draw_arrow(v, Vector2(v.size.x - 24, cy), 1, 18.0, ink)


func _step_volume(d: int) -> void:
	var i: int = B.VOLUMES.find(int(store.settings()["volume"]))
	var v: int = B.VOLUMES[(i + d + B.VOLUMES.size()) % B.VOLUMES.size()]
	store.set_setting("volume", v)
	Sfx.set_volume(v)
	Sfx.play("capture")
	_paint()


func _toggle(k: String) -> void:
	store.set_setting(k, not store.settings()[k])
	_paint()


func _open_test(on: bool) -> void:
	keytest = on
	held.clear()
	_list.visible = not on
	_test.visible = on
	_test.queue_redraw()


# フォーカスが外れた時は、全部離したものとして扱う(共通 §3 の 5)。
func release_all() -> void:
	held.clear()
	_test.queue_redraw()


func key(ev: InputEventKey) -> void:
	if keytest:
		if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
			_open_test(false)
			return
		if ev.pressed:
			held[ev.physical_keycode] = true
		else:
			held.erase(ev.physical_keycode)
		_test.queue_redraw()
		return
	if not ev.pressed or ev.echo:
		return
	if ev.physical_keycode == KEY_ESCAPE:
		back.emit()
	elif menu.sel == 0 and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_step_volume(-1 if ev.physical_keycode == KEY_LEFT else 1)
	elif menu.sel in [1, 2] and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_toggle(["", "shake", "reduce_flash"][menu.sel])
	else:
		menu.key(ev)


# 2 つの十字(左 W A S D・右 矢印)。押されているキーは人の陣の色と模様で光る。十字の上に人の印と名前。
func _draw_test() -> void:
	var f := Kit.font(800)
	for p in 2:
		var c := Vector2(400 if p == 0 else 880, 430)
		var codes: Array = Keymap.P1_KEYS if p == 0 else Keymap.P2_KEYS
		Kit.draw_mark(_test, c + Vector2(-34, -196), p, 22.0, Kit.C_TRAIL[p])
		_test.draw_string(f, c + Vector2(-14, -186), S.NAMES[0][p], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Kit.C_TEXT)
		for d in 4:
			var off: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][d]
			if d == 2:
				off = Vector2(0, 0)  # 下のキーは中央の段(キーボードの並び)
			var r := Rect2(c + off * 96 - Vector2(42, 42), Vector2(84, 84))
			var on: bool = held.has(codes[d])
			_test.draw_rect(Rect2(r.position + Vector2(0, 6), r.size), Color("05080F"))
			_test.draw_rect(r, Kit.C_LAND[p] if on else Kit.C_INK)
			if on:
				Kit.draw_pattern(_test, r, p, Color(Kit.C_TRAIL[p], 0.6), 14.0)
			_test.draw_rect(r.grow(-1.5), Kit.C_TRAIL[p] if on else Color(Kit.C_PAPER, 0.35), false, 3.0)
			var col := Kit.C_WHITE if on else Kit.C_PAPER
			if p == 0:
				_test.draw_string(f, Vector2(r.position.x, r.get_center().y + 14), S.KEYTEST_P1[d], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 38, col)
			else:
				Kit.draw_arrow(_test, r.get_center(), d, 30.0, col)
