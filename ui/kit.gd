# 画面の共通部品(色・字体・ラベル・ボタン・置き場所・陣の印と模様の描き方)。画面設計書 §8 の色はここに置く。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。ボタンの見た目は ui/theme.tres(tools/make_theme.gd が作る)。
# v0.3.0 の見た目「夜の卓の陣取り盤」: 藍の卓に盤を置き、2 陣は色に加えて 印(P1 丸・P2 四角)と模様(P1 点・P2 斜線)で分ける。
extends RefCounted

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"
const NUM := "res://assets/fonts/LilitaOne-Regular.ttf"  # 題字と数字(英字・数字だけ。日本語は Noto)

const C_BG := Color("121A2A")  # 卓(藍)
const C_BOARD := Color("18223A")  # 盤の地・板
const C_GRID := Color("24304A")  # マス目
const C_EDGE := Color("3A4A6B")  # 盤の枠・板の縁
const C_INK := Color("0B1120")  # 駒の字・影
const C_PAPER := Color("F3EAD8")  # 駒(選んだボタン・題字の字)
const C_TEXT := Color("EEF0F5")
const C_DIM := Color("9AA6BF")
const C_WHITE := Color("FFFFFF")
const C_RED := Color("FF5D5D")
const C_WARN := Color("FFD166")
const C_SEL := C_PAPER  # 選んだ物の印はどちらの陣の色でもない色にする
const C_PANEL := C_BOARD
# 2 人の色(画面設計書 §8。変えない)。[P1, P2]
const C_LAND := [Color("1F6F78"), Color("8A4B1F")]
const C_TRAIL := [Color("4FD1C5"), Color("FFA552")]
const C_HEAD := [Color("E6FFFB"), Color("FFF1E0")]

static var _fonts := {}
static var _num: Font = null
static var _pattern := {}  # 模様の 1 マスの絵。p * 1000 + マスの大きさ → Texture2D


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


# 題字・数字の字体。字体に無い字(日本語)は Noto で出す。
static func num_font() -> Font:
	if _num == null:
		var f := load(NUM) as FontFile
		f.fallbacks = [font(800)]
		_num = f
	return _num


static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# 数字のラベル(Lilita One)。縁取りを付けて、どの地の上でも読めるようにする。
static func num_label(text: String, size: int, color: Color = C_TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", num_font())
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(C_INK, 0.9))
	return l


# ボタン。node_name は自動の確認が押す時の目印。見た目は theme(キーボードで選ぶと SelButton の型に替わる。ui/menu.gd)。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # Tab・矢印を Godot のフォーカスの移動に使わせない
	b.add_theme_font_size_override("font_size", size)
	return b


static func set_selected(b: Button, on: bool) -> void:
	b.theme_type_variation = &"SelButton" if on else &""


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


static func ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k)


# 少し行き過ぎて戻る(題字のはね・旗が立つ時)。
static func ease_back(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	var c := 1.7
	return 1.0 + (c + 1.0) * pow(k - 1.0, 3) + c * pow(k - 1.0, 2)


# 平らな板(駒の形): 地・縁・下に厚み。厚みは地を暗くした色。
static func draw_plate(ci: CanvasItem, r: Rect2, fill: Color, edge: Color, depth: float = 0.0, width: float = 2.0) -> void:
	if depth > 0.0:
		ci.draw_rect(Rect2(r.position + Vector2(0, depth), r.size), Color(fill.darkened(0.45), fill.a))
	ci.draw_rect(r, fill)
	if width > 0.0:
		ci.draw_rect(r.grow(-width / 2.0), edge, false, width)


# 陣の模様を矩形に敷く(P1 はマスの真ん中の点、P2 はマスの対角の斜線。盤と同じ)。cell はマスの大きさ。
# 1 マスぶんの絵を 1 回だけ作り、敷き詰めて 1 回で描く(マスごとに描くと、タイトルの背景で 1 フレームが 3 倍に重くなった)。
static func draw_pattern(ci: CanvasItem, r: Rect2, p: int, col: Color, cell: float = 12.0) -> void:
	var nx := int(r.size.x / cell)
	var ny := int(r.size.y / cell)
	if nx <= 0 or ny <= 0:
		return
	if ci.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED:
		ci.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var o := r.position + (r.size - Vector2(nx, ny) * cell) / 2.0
	ci.draw_texture_rect(pattern_tex(p, cell), Rect2(o, Vector2(nx, ny) * cell), true, col)


# 模様の 1 マス(白。濃さは縁を滑らかにした覆い率)。色は描く時の modulate で付ける。
static func pattern_tex(p: int, cell: float) -> Texture2D:
	var n := int(roundf(cell))
	var key := p * 1000 + n
	if not _pattern.has(key):
		_pattern[key] = ImageTexture.create_from_image(pattern_image(p, n))
	return _pattern[key]


static func pattern_image(p: int, n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var mid := Vector2(n, n) / 2.0
	var a := Vector2(n, n) * 0.18
	var b := Vector2(n, n) * 0.82
	for y in n:
		for x in n:
			var q := Vector2(x + 0.5, y + 0.5)
			var cover := 0.0
			if p == 0:
				cover = maxf(1.2, n * 0.1) + 0.5 - q.distance_to(mid)
			else:
				cover = maxf(1.0, n * 0.06) / 2.0 + 0.5 - q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(cover, 0.0, 1.0)))
	return img


# 陣の印(P1 は丸、P2 は四角)。s は直径・辺。filled が偽なら輪郭だけ。
static func draw_mark(ci: CanvasItem, at: Vector2, p: int, s: float, col: Color, filled: bool = true, width: float = 2.0) -> void:
	if p == 0:
		ci.draw_circle(at, s / 2.0, col, filled, -1.0 if filled else width, true)
	else:
		var r := Rect2(at - Vector2(s, s) / 2.0, Vector2(s, s))
		if filled:
			ci.draw_rect(r, col)
		else:
			ci.draw_rect(r.grow(-width / 2.0), col, false, width)


# 陣の旗: foot に立つ竿と、燕尾の布。布には陣の印を抜く。h は竿の高さ。
static func draw_flag(ci: CanvasItem, foot: Vector2, h: float, p: int, cloth: Color, pole: Color = C_PAPER) -> void:
	var w := h * 0.62
	var top := foot - Vector2(0, h)
	ci.draw_line(foot, top - Vector2(0, h * 0.04), pole, maxf(2.0, h * 0.06), true)
	var ch := h * 0.42
	var tl := top + Vector2(h * 0.03, 0)
	var notch := w * 0.28
	ci.draw_colored_polygon(PackedVector2Array([tl, tl + Vector2(w, 0), tl + Vector2(w - notch, ch / 2.0), tl + Vector2(w, ch), tl + Vector2(0, ch)]), cloth)
	draw_mark(ci, tl + Vector2((w - notch) * 0.48, ch / 2.0), p, ch * 0.42, C_INK)


# 矢印の三角(向き 0 上・1 右・2 下・3 左)。キーの形・頭の向きで使う。
static func draw_arrow(ci: CanvasItem, at: Vector2, d: int, s: float, col: Color) -> void:
	var v: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][d]
	var n := Vector2(-v.y, v.x)
	ci.draw_colored_polygon(PackedVector2Array([at + v * s * 0.55, at - v * s * 0.4 + n * s * 0.5, at - v * s * 0.4 - n * s * 0.5]), col)
