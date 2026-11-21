# S5 一時停止(共通 §6)。プレイ画面を暗くした上に盤の色の板を重ねる。続ける・やり直す・設定・タイトルへ。Esc で続ける、R でやり直す。
# 板の下にキーの案内。暗幕は見えている範囲(view)全体を覆う。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const PANEL := Rect2(440, 120, 400, 444)

var menu: Menu
var view := Rect2(0, 0, 1280, 720)


func build() -> void:
	size = Vector2(1280, 720)
	add_child(Kit.place(Kit.label(S.PAUSE, 36, Kit.C_TEXT, 800), PANEL.position.x, PANEL.position.y + 24, PANEL.size.x, 56))
	var list: Array[Button] = []
	var y := PANEL.position.y + 104
	for pair: Array in [["resume", S.B_RESUME], ["restart", S.B_RESTART], ["settings", S.B_SETTINGS], ["title", S.B_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 26), PANEL.position.x + 50, y, PANEL.size.x - 100, 66)
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		list.append(b)
		y += 80
	add_child(Kit.place(KeyHint.new([[["Esc"], S.B_RESUME], [["R"], S.B_RESTART]]), PANEL.position.x, PANEL.end.y + 16, PANEL.size.x, 36))
	menu = Menu.new(list, 0)


func set_view(v: Rect2) -> void:
	view = v
	queue_redraw()


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		picked.emit("resume")
	elif ev.pressed and not ev.echo and ev.physical_keycode == KEY_R:
		picked.emit("restart")
	else:
		menu.key(ev)


func _draw() -> void:
	draw_rect(view, Color(Kit.C_INK, 0.78))
	Kit.draw_plate(self, PANEL, Kit.C_BOARD, Kit.C_EDGE, 8.0, 2.0)
	# 板の上の縁に 2 陣の帯(左 P1 の点・右 P2 の斜線)
	var band := Rect2(PANEL.position, Vector2(PANEL.size.x, 10))
	for p in 2:
		var r := Rect2(band.position + Vector2(band.size.x / 2.0 * p, 0), Vector2(band.size.x / 2.0, band.size.y))
		draw_rect(r, Kit.C_LAND[p])
		Kit.draw_pattern(self, r, p, Color(Kit.C_TRAIL[p], 0.7), 10.0)
