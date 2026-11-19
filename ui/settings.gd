# S4 設定(共通 §6・FR-24・FR-29)。音量(5 段)・画面の揺れ・点滅を弱める・キーの確かめ。変えたらすぐ保存し、音量はその音量で 1 回鳴らす。
# キーの確かめ: 左に W A S D、右に ↑ ← ↓ → の図を出し、押されているキーを光らせる(E-18)。押す・離すのイベントで自分で持ち、Esc で戻る。
# ← → でも値を変えられる。Esc か「戻る」で来た画面へ。作りは KeySwat の ui/settings.gd。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const Keymap := preload("res://ui/keymap.gd")


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
	_list = Control.new()
	_list.size = size
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_list)
	_list.add_child(Kit.place(Kit.label(S.SETTINGS, 40, Kit.C_TEXT, 700), 0, 70, 1280, 60))
	_vol = Kit.place(Kit.button("volume", "", 26), 390, 170, 500, 72)
	_shake = Kit.place(Kit.button("shake", "", 26), 390, 256, 500, 72)
	_flash = Kit.place(Kit.button("reduce_flash", "", 26), 390, 342, 500, 72)
	var test := Kit.place(Kit.button("keytest", S.SET_KEYTEST, 26), 390, 428, 500, 72)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 26), 520, 534, 240, 72)
	for b: Button in [_vol, _shake, _flash, test, ret]:
		_list.add_child(b)
	_vol.pressed.connect(func() -> void: _step_volume(1))
	_shake.pressed.connect(func() -> void: _toggle("shake"))
	_flash.pressed.connect(func() -> void: _toggle("reduce_flash"))
	test.pressed.connect(func() -> void: _open_test(true))
	ret.pressed.connect(func() -> void: back.emit())
	menu = Menu.new([_vol, _shake, _flash, test, ret] as Array[Button], 0)
	_test = Control.new()
	_test.size = size
	_test.visible = false
	add_child(_test)
	_test.add_child(Kit.place(Kit.label(S.SET_KEYTEST, 40, Kit.C_TEXT, 700), 0, 70, 1280, 60))
	_test.add_child(Kit.place(Kit.label(S.KEYTEST_NOTE, 22, Kit.C_DIM, 500), 0, 140, 1280, 36))
	_test.draw.connect(_draw_test)
	_paint()


func _paint() -> void:
	var st: Dictionary = store.settings()
	_vol.text = "%s  %d" % [S.SET_VOLUME, int(st["volume"])]
	_shake.text = "%s  %s" % [S.SET_SHAKE, S.ON if st["shake"] else S.OFF]
	_flash.text = "%s  %s" % [S.SET_FLASH, S.ON if st["reduce_flash"] else S.OFF]


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


# 2 つの十字(左 W A S D・右 ↑←↓→)。押されているキーは人の色で光る。
func _draw_test() -> void:
	var f := Kit.font(800)
	for p in 2:
		var c := Vector2(400 if p == 0 else 880, 420)
		var codes: Array = Keymap.P1_KEYS if p == 0 else Keymap.P2_KEYS
		var texts: Array = S.KEYTEST_P1 if p == 0 else S.KEYTEST_P2
		for d in 4:
			var off: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][d]
			if d == 2:
				off = Vector2(0, 0)  # 下のキーは中央の段(キーボードの並び)
			var r := Rect2(c + off * 96 - Vector2(42, 42), Vector2(84, 84))
			var on: bool = held.has(codes[d])
			_test.draw_rect(r, Kit.C_LAND[p] if on else Kit.C_GRID)
			_test.draw_rect(r, Kit.C_TRAIL[p] if on else Kit.C_EDGE, false, 3.0)
			_test.draw_string(f, Vector2(r.position.x, r.get_center().y + 14), texts[d], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 38,
				Kit.C_WHITE if on else Kit.C_DIM)
