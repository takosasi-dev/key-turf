# 押したキーを人と向きに直す(仕様書 §9.2・FR-2・FR-27・D-14)。physical_keycode で取るので、配列の印字が違っても位置で決まる。
# 押しっぱなしの繰り返しと、Ctrl・Alt・Meta と一緒のキーは捨てる。CPU の試合(solo)では 8 キーがどれも P1 の向き。
extends RefCounted

# 向き 0 上・1 右・2 下・3 左
const P1_KEYS := [KEY_W, KEY_D, KEY_S, KEY_A]
const P2_KEYS := [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]


# [人, 向き]。向きのキーでなければ空。
static func turn_of(ev: InputEventKey, solo: bool) -> Array:
	if not ev.pressed or ev.echo or ev.ctrl_pressed or ev.alt_pressed or ev.meta_pressed:
		return []
	var d := P1_KEYS.find(ev.physical_keycode)
	if d >= 0:
		return [0, d]
	d = P2_KEYS.find(ev.physical_keycode)
	if d >= 0:
		return [0 if solo else 1, d]
	return []
