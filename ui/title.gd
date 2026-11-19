# S1 タイトル(画面設計書 §2)。入口 3 つ(CPU と やさしい・ふつう・ふたりで。この順。FR-1・Q-4)と設定、CPU の通算の記録、
# 下に 2 色の陣地と線の小さな見本を薄く描く。一番上の「CPU と(やさしい)」を Enter で押せる。
extends Control

signal chosen(what: String)  # "easy" / "normal" / "duo" / "settings"

const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

var menu: Menu


# store は save_store。
func build(store: RefCounted) -> void:
	size = Vector2(1280, 720)
	add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 800), 0, 28, 1280, 100))
	add_child(Kit.place(Kit.label(S.TAGLINE, 28, Kit.C_DIM, 500), 0, 124, 1280, 44))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 18, Kit.C_WARN), 0, 168, 1280, 28))
	var easy := Kit.place(Kit.button("easy", S.B_EASY, 30), 360, 204, 560, 88)
	var normal := Kit.place(Kit.button("normal", S.B_NORMAL, 30), 360, 304, 560, 88)
	var duo := Kit.place(Kit.button("duo", "%s   %s" % [S.B_DUO, S.DUO_KEYS], 26), 360, 404, 560, 72)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 24), 520, 488, 240, 72)
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
		var note := Kit.label(S.REC_DRAW % [w, l, d] if d > 0 else S.REC % [w, l], 22, Kit.C_DIM, 500)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(Kit.place(note, by.position.x + by.size.x + 24, by.position.y, 300, by.size.y))
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 676, 200, 32))
	menu = Menu.new([easy, normal, duo, settings] as Array[Button], 0)


func key(ev: InputEventKey) -> void:
	menu.key(ev)


# 2 色の陣地と線の小さな見本(薄く)。
func _draw() -> void:
	var cell := 12.0
	var o := Vector2(480, 584)
	for p in 2:
		var base := o + (Vector2(0, 24) if p == 0 else Vector2(216, 12))
		var a := 0.35
		for y in 5:
			for x in 5:
				var r := Rect2(base + Vector2(x, y) * cell, Vector2(cell, cell))
				draw_rect(r, Color(Kit.C_LAND[p], a))
				if p == 0:
					draw_circle(r.get_center(), 1.5, Color(Kit.C_TRAIL[0], a), true, -1.0, true)
				else:
					draw_line(r.position + Vector2(2, 2), r.end - Vector2(2, 2), Color(Kit.C_TRAIL[1], a), 1.0, true)
		var y0 := base.y + cell * 2.5
		if p == 0:
			var pts := [Vector2(base.x + cell * 5, y0), Vector2(base.x + cell * 9, y0), Vector2(base.x + cell * 9, y0 + cell * 4)]
			draw_polyline(PackedVector2Array(pts), Color(Kit.C_TRAIL[0], a), 4.0, true)
			draw_circle(pts[2], 5.0, Color(Kit.C_HEAD[0], a + 0.1), true, -1.0, true)
		else:
			var from := Vector2(base.x, y0)
			var to := Vector2(base.x - cell * 5, y0)
			draw_dashed_line(from, to, Color(Kit.C_TRAIL[1], a), 4.0, 4.0, false)
			draw_rect(Rect2(to - Vector2(5, 5), Vector2(10, 10)), Color(Kit.C_HEAD[1], a + 0.1))
