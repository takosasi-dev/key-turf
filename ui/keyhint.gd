# キーの形と言葉を並べる(v0.3.0): 画面の下の案内「[↑][↓] 選ぶ  [Enter] 決める」、ふたりでのボタンの中の 2 人のキー、上の帯の札のキー。
# items は [[キーの名前, ...], 言葉] の並び。キーの名前の up / down / left / right は矢印の絵(字の記号を使わない)、ほかは字(W・Esc・Enter・R)。
# キーは墨の地に象牙の字なので、暗い地にも象牙の駒(選んだボタン)の上にも出せる。言葉の色は、親が選ばれたボタンなら墨、ほかは弱い字。作りは KeySwat の ui/keyhint.gd。
extends Control

const Kit := preload("res://ui/kit.gd")

const ARROWS := ["up", "right", "down", "left"]  # 向きの順(Kit.draw_arrow の 0〜3)

var items: Array = []
var align := HORIZONTAL_ALIGNMENT_CENTER
var cap_h := 30.0
var text_size := 18
var text_color := Kit.C_DIM


func _init(p_items: Array = [], p_align: int = HORIZONTAL_ALIGNMENT_CENTER, p_cap_h: float = 30.0) -> void:
	items = p_items
	align = p_align
	cap_h = p_cap_h
	text_size = maxi(14, int(round(cap_h * 0.6)))  # 字は 14 px より小さくしない
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _cap_w(k: String) -> float:
	if k in ARROWS:
		return cap_h
	return maxf(cap_h, Kit.font(700).get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + cap_h * 0.6)


func _text_w(t: String) -> float:
	return 0.0 if t == "" else Kit.font(600).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x


func _gap() -> float:
	return cap_h * 0.2


func total_width() -> float:
	var w := 0.0
	for n in items.size():
		var it: Array = items[n]
		for k: String in it[0]:
			w += _cap_w(k) + _gap()
		w += _text_w(it[1]) + (cap_h * 0.5 if n < items.size() - 1 else 0.0)
	return w


func _draw() -> void:
	var w := total_width()
	var x := (size.x - w) / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else (size.x - w if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
	var top := (size.y - cap_h) / 2.0
	var on_paper := get_parent() is Button and (get_parent() as Button).theme_type_variation == &"SelButton"
	var words := Kit.C_INK if on_paper else text_color
	for n in items.size():
		var it: Array = items[n]
		for k: String in it[0]:
			var cw := _cap_w(k)
			var r := Rect2(x, top, cw, cap_h - 3.0)
			draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color("05080F"))
			draw_rect(r, Kit.C_INK)
			draw_rect(r.grow(-0.75), Color(Kit.C_PAPER, 0.35), false, 1.5)
			var i := ARROWS.find(k)
			if i >= 0:
				Kit.draw_arrow(self, r.get_center(), i, cap_h * 0.36, Kit.C_PAPER)
			else:
				draw_string(Kit.font(700), Vector2(x, r.get_center().y + text_size * 0.36), k, HORIZONTAL_ALIGNMENT_CENTER, cw, text_size, Kit.C_PAPER)
			x += cw + _gap()
		if it[1] != "":
			draw_string(Kit.font(600), Vector2(x, top + cap_h * 0.5 + text_size * 0.36), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, words)
			x += _text_w(it[1])
		x += cap_h * 0.5
