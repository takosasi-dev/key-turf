# 画面の切り替わり(v0.3.0): 見えている範囲を大きなマスで覆い、左上から右下へ斜めにマスが縮んで消えて、新しい画面が出る(陣が明け渡される形)。
# 覆うマスは左が P1 の陣地の色・右が P2 の陣地の色で、境は階段。WIPE_MS で終わる。
# 見た目だけで入力は飲まない(新しい画面は最初から押せる。マウスも通す)。点滅を弱める 入なら main が呼ばない。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

var view := Rect2(0, 0, 1280, 720)
var start_ms := -100000
var now_ms := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func run() -> void:
	start_ms = Time.get_ticks_msec()
	queue_redraw()


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


# 走り終わるまでの割合(0→1)。走っていなければ 1。
func progress() -> float:
	return clampf(float(_now() - start_ms) / B.WIPE_MS, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _now() - start_ms <= B.WIPE_MS + 50:
		queue_redraw()


func _draw() -> void:
	var k := progress()
	if k >= 1.0:
		return
	var c := float(B.WIPE_CELL)
	var nx := int(ceilf(view.size.x / c))
	var ny := int(ceilf(view.size.y / c))
	var cols := [Kit.C_LAND[0].darkened(0.55), Kit.C_LAND[1].darkened(0.55)]
	for y in ny:
		var split := int(nx / 2.0) + (y % 4) - 2  # 階段の境
		for x in nx:
			var u := (float(x) / maxf(nx - 1, 1) + float(y) / maxf(ny - 1, 1)) / 2.0
			var local := clampf((k - u * 0.6) / 0.4, 0.0, 1.0)
			var s := c * (1.0 - Kit.ease_out(local))
			if s <= 0.5:
				continue
			var center := view.position + Vector2(x + 0.5, y + 0.5) * c
			draw_rect(Rect2(center - Vector2(s, s) / 2.0, Vector2(s, s)), cols[0 if x < split else 1])
