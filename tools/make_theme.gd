# ui/theme.tres を作る(v0.3.0 の見た目「夜の卓の陣取り盤」。project の gui/theme/custom で全部の Control に付く)。
# 色を変えたら回し直してコミットする(作りは KeySwat の tools/make_theme.gd)。
#     python tools/gd.py run res://tools/make_theme.gd
# ボタンは平らな駒の形(下に厚み)。normal / hover / focus / pressed / disabled と、キーボードで選んだ時の型の変種 SelButton(象牙の駒)。
# 入力欄・メニュー・ツールチップ・スクロールバー・つまみ・チェックも作る(今の画面では使っていないが、後から足しても既定の見た目に戻らない)。
extends SceneTree

const Kit := preload("res://ui/kit.gd")
const OUT := "res://ui/theme.tres"


func _initialize() -> void:
	var err := ResourceSaver.save(build(), OUT)
	print("theme: %s -> %s" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


# 駒の形: 角を少し丸め、下の縁を太くして厚みに見せる。押すと上が太く下が細くなり、字が沈む。
static func _tile(bg: Color, edge: Color, top: int = 2, bottom: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = top
	s.border_width_bottom = bottom
	s.set_corner_radius_all(6)
	s.anti_aliasing = true
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 4 + top
	s.content_margin_bottom = 4 + bottom
	return s


static func _box(bg: Color, edge: Color, w: int, r: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(w)
	s.set_corner_radius_all(r)
	s.anti_aliasing = true
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# 陣の印の小さな絵(チェックとつまみ用)。丸の型(P1 の印と同じ形)。
static func _dot(size: int, fill: Color, edge: Color, inner: Color = Color(0, 0, 0, 0)) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			if d > c + 0.5:
				continue
			var col := edge if d > c - 2.0 else fill
			if inner.a > 0.0 and d < c - 4.5:
				col = inner
			img.set_pixel(x, y, col)
	# 圧縮の形にすると Web の書き出しだけでエラーになる(KeySwat)。生の画素の ImageTexture で持つ
	return ImageTexture.create_from_image(img)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = Kit.font(500)
	t.default_font_size = 22
	var tile := Color("1E2A45")
	var tile_edge := Color("3A4A6B")
	var hover := Color("26355A")
	var paper := Kit.C_PAPER
	var paper_edge := Color("C9B78E")

	# ボタン
	t.set_font("font", "Button", Kit.font(700))
	t.set_font_size("font_size", "Button", 26)
	t.set_stylebox("normal", "Button", _tile(tile, tile_edge))
	t.set_stylebox("hover", "Button", _tile(hover, Color("5B6E96")))
	t.set_stylebox("pressed", "Button", _tile(paper.darkened(0.12), paper_edge.darkened(0.2), 6, 2))
	t.set_stylebox("hover_pressed", "Button", _tile(paper.darkened(0.12), paper_edge.darkened(0.2), 6, 2))
	var focus := _box(Color(0, 0, 0, 0), paper, 3, 8)
	focus.draw_center = false
	focus.set_expand_margin_all(4)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", _tile(Kit.C_BG, Color(tile_edge, 0.6)))
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "Button", Kit.C_TEXT)
	t.set_color("font_pressed_color", "Button", Kit.C_INK)
	t.set_color("font_hover_pressed_color", "Button", Kit.C_INK)
	t.set_color("font_disabled_color", "Button", Color(Kit.C_DIM, 0.6))
	t.set_constant("outline_size", "Button", 0)
	# キーボード・マウスで選んでいるボタン: 象牙の駒に墨の字
	t.set_type_variation("SelButton", "Button")
	t.set_stylebox("normal", "SelButton", _tile(paper, paper_edge))
	t.set_stylebox("hover", "SelButton", _tile(paper, paper_edge))
	t.set_stylebox("disabled", "SelButton", _tile(paper.lerp(Kit.C_BG, 0.45), paper_edge.lerp(Kit.C_BG, 0.45)))  # 選んであるがまだ押せない
	for c: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "SelButton", Kit.C_INK)
	t.set_color("font_disabled_color", "SelButton", Color(Kit.C_INK, 0.75))

	# 字
	t.set_color("font_color", "Label", Kit.C_TEXT)

	# 板
	t.set_stylebox("panel", "Panel", _box(Kit.C_BOARD, tile_edge, 2))
	t.set_stylebox("panel", "PanelContainer", _box(Kit.C_BOARD, tile_edge, 2))

	# 入力欄
	for type: String in ["TextEdit", "LineEdit"]:
		var n := _box(Kit.C_INK, tile_edge, 2)
		var f := n.duplicate() as StyleBoxFlat
		f.border_color = paper
		t.set_stylebox("normal", type, n)
		t.set_stylebox("read_only", type, n)
		t.set_stylebox("focus", type, f)
		t.set_font("font", type, Kit.font(500))
		t.set_font_size("font_size", type, 18)
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_readonly_color", type, Kit.C_DIM)
		t.set_color("font_selected_color", type, Kit.C_INK)
		t.set_color("selection_color", type, Color(paper, 0.8))
		t.set_color("caret_color", type, paper)
		t.set_color("font_placeholder_color", type, Kit.C_DIM)

	# 右クリックのメニュー・ツールチップ
	var pop := _box(Kit.C_BOARD, tile_edge, 2)
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", _box(paper, paper, 0, 4))
	t.set_font("font", "PopupMenu", Kit.font(500))
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_color("font_color", "PopupMenu", Kit.C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Kit.C_INK)
	t.set_color("font_disabled_color", "PopupMenu", Kit.C_DIM)
	t.set_color("font_separator_color", "PopupMenu", Kit.C_DIM)
	var line := StyleBoxLine.new()
	line.color = tile_edge
	line.thickness = 2
	t.set_stylebox("separator", "PopupMenu", line)
	t.set_stylebox("panel", "TooltipPanel", _box(Kit.C_BOARD, paper, 2, 4))
	t.set_color("font_color", "TooltipLabel", Kit.C_TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	# スクロールバー
	for type: String in ["VScrollBar", "HScrollBar"]:
		var track := _box(Kit.C_INK, Kit.C_INK, 0, 4)
		var grab := _box(tile_edge, tile_edge, 0, 4)
		var grab_hi := _box(paper.darkened(0.25), paper, 0, 4)
		var grab_on := _box(paper, paper, 0, 4)
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, grab)
		t.set_stylebox("grabber_highlight", type, grab_hi)
		t.set_stylebox("grabber_pressed", type, grab_on)

	# つまみ
	var rail := _box(tile_edge, tile_edge, 0, 3)
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	var rail_on := _box(paper.darkened(0.2), paper, 0, 3)
	rail_on.content_margin_top = 3
	rail_on.content_margin_bottom = 3
	var grab_n := _dot(20, paper, paper_edge)  # 絵は 1 枚ずつ作って使い回す(書き出しを重くしない)
	var grab_h := _dot(20, Kit.C_WHITE, paper)
	var grab_d := _dot(20, Kit.C_DIM, Kit.C_DIM)
	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, rail)
		t.set_stylebox("grabber_area", type, rail_on)
		t.set_stylebox("grabber_area_highlight", type, rail_on)
		t.set_icon("grabber", type, grab_n)
		t.set_icon("grabber_highlight", type, grab_h)
		t.set_icon("grabber_disabled", type, grab_d)

	# チェック
	var off := _dot(22, Color(0, 0, 0, 0), Kit.C_DIM)
	var on := _dot(22, Color(0, 0, 0, 0), paper, paper)
	for type: String in ["CheckBox", "CheckButton"]:
		t.set_icon("unchecked", type, off)
		t.set_icon("checked", type, on)
		t.set_icon("unchecked_disabled", type, off)
		t.set_icon("checked_disabled", type, on)
		t.set_font("font", type, Kit.font(700))
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_hover_color", type, Kit.C_WHITE)
		t.set_color("font_pressed_color", type, Kit.C_TEXT)
		t.set_color("font_focus_color", type, Kit.C_TEXT)
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, StyleBoxEmpty.new())
		t.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), paper, 2, 6))
	return t
