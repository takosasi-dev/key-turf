# S1 タイトル(画面設計書 §2・「UI の見た目(v0.3.0)」)。題字(陣地の題字)・一言・入口 3 つ(CPU と やさしい・ふつう・ふたりで。この順。FR-1・Q-4)と設定、
# CPU の通算の記録、下にキーの案内。背景(2 陣が盤の外で陣を取り合う)は main の backdrop が描く。一番上の「CPU と(やさしい)」を Enter で押せる。
extends Control

signal chosen(what: String)  # "easy" / "normal" / "duo" / "settings"

const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const Logo := preload("res://ui/logo.gd")
const KeyHint := preload("res://ui/keyhint.gd")

var menu: Menu
var animate := true
var _records: Array = []  # 記録を出したボタン(その右に旗を描く)


# store は save_store。
func build(store: RefCounted) -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := Logo.new()
	logo.animate = animate
	add_child(Kit.place(logo, 0, 52, 1280, 200))
	add_child(Kit.place(Kit.label(S.TAGLINE, 24, Kit.C_DIM, 500), 0, 234, 1280, 36))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 16, Kit.C_WARN, 700), 0, 266, 1280, 22))
	var easy := Kit.place(Kit.button("easy", S.B_EASY, 28), 380, 294, 520, 76)
	var normal := Kit.place(Kit.button("normal", S.B_NORMAL, 28), 380, 380, 520, 76)
	var duo := Kit.place(Kit.button("duo", S.B_DUO, 28), 380, 466, 520, 76)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 24), 520, 556, 240, 60)
	for b: Button in [easy, normal, duo]:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# ふたりでのボタンの右に、2 人のキー(左 W A S D・右 矢印)を絵で
	var keys := KeyHint.new([[[], S.HINT_LEFT], [["W", "A", "S", "D"], ""], [[], S.HINT_RIGHT], [["up", "left", "down", "right"], ""]],
		HORIZONTAL_ALIGNMENT_RIGHT, 26.0)
	duo.add_child(Kit.place(keys, 150, 0, 352, 70))
	for b: Button in [easy, normal, duo, settings]:
		add_child(b)
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
	for pair: Array in [[1, easy], [2, normal]]:
		var r: Dictionary = store.cpu_record(pair[0])
		var w := int(r["win"])
		var l := int(r["lose"])
		var d := int(r["draw"])
		if w + l + d == 0:
			continue  # 記録が無ければ出さない
		var by: Button = pair[1]
		var note := Kit.label(S.REC_DRAW % [w, l, d] if d > 0 else S.REC % [w, l], 20, Kit.C_TEXT, 600)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(Kit.place(note, by.position.x + by.size.x + 52, by.position.y, 260, by.size.y - 6))
		_records.append(by)
	var ver := Kit.label(S.VERSION, 16, Kit.C_DIM, 500)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 680, 200, 28))
	add_child(Kit.place(KeyHint.new([[["up", "down"], S.HINT_SELECT], [["Enter"], S.HINT_DECIDE]], HORIZONTAL_ALIGNMENT_RIGHT), 680, 676, 576, 36))
	menu = Menu.new([easy, normal, duo, settings] as Array[Button], 0)


func key(ev: InputEventKey) -> void:
	menu.key(ev)


# 記録の印: 記録の左に P1 の旗(CPU との試合の「あなた」は P1)。
func _draw() -> void:
	for by: Button in _records:
		Kit.draw_flag(self, Vector2(by.position.x + by.size.x + 22, by.position.y + by.size.y / 2.0 + 16), 34.0, 0, Kit.C_TRAIL[0])
