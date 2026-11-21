# 描画の道を窓なしで 1 回ずつ通す確かめ(Web のリリース版はスクリプトエラーで黙って止まるため)。
# 大きな囲み(和音・揺れ・浮かぶ数字)、決着の演出 8 種(点滅を弱める 入・切)、設定のキーの確かめの十字を描かせ、描いた回数を印字する。
# v0.3.0 で、一時停止の板・タイトル(題字・背景・切り替わり)・結果(旗・行の帯)・キーの確かめの画面も通す。
# 実行: python tools/gd.py run res://tools/draw_check.gd(出力に SCRIPT ERROR が無ければよい)
extends SceneTree

const B := preload("res://core/balance.gd")
const Sim := preload("res://core/sim.gd")
const Grid := preload("res://core/grid.gd")

var main: Node
var frame := 0
var keys: Node


# 画面のスクリプトは自動読み込み(Sfx)を使うので、preload せず、木が動き出してから読む(tests/run_tests.gd と同じ)。
func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	main = (load("res://ui/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	if main == null:
		return false
	frame += 1
	if frame == 2:
		_key(KEY_X)
		main.first_match = false
		main._on_title("duo")
		_big_loop(main.play.sim)
	elif frame == 40:
		var caps: int = main.play.board.reveal.size()
		print("DRAW big_capture reveal=%d floats=%d shake_until=%d" % [caps, main.play.board.floats.size(), main.play._shake_until])
	elif frame >= 50 and frame < 50 + 8 * 6:
		var k := (frame - 50) / 6
		if (frame - 50) % 6 == 0:
			var b = main.play.board
			b.reduce_flash = k % 2 == 1
			var sim: Sim = main.play.sim
			sim.grid.trail[Grid.idx(20, 5)] = 1
			sim.grid.trail[Grid.idx(21, 5)] = 1
			sim.grid.trail[Grid.idx(30, 8)] = 2
			b.snap = sim.snapshot()
			b.on_round_end(k % 2, k % 8, Array(sim.heads))
	elif frame == 110:
		print("DRAW board_draws=%d" % main.play.board.draws)
		keys = (load("res://ui/settings.gd") as GDScript).new()
		keys.build(main.store)
		root.add_child(keys)
		keys._open_test(true)
		keys.key(_ev(KEY_W))
		keys.key(_ev(KEY_UP))
	elif frame == 120:
		print("DRAW keytest held=%d" % keys.held.size())
		keys.queue_free()
		main._pause()  # v0.3.0: 一時停止の板
	elif frame == 130:
		print("DRAW pause=%s" % (main.pause_view != null))
		main._on_pause("title")  # 題字・背景の陣取り・切り替わりのマス
	elif frame == 150:
		print("DRAW title logo wipe=%.2f" % main.wipe.progress())
		main.run_mode = Sim.MODE_EASY
		main.play = null
		main._on_finished({"winner": 0, "wins": [3, 1], "rounds": [{"winner": 0, "reason": 0, "counts": [300, 200]},
			{"winner": 1, "reason": 2, "counts": [100, 400]}, {"winner": -1, "reason": 4, "counts": [250, 250]},
			{"winner": 0, "reason": 6, "counts": [500, 480]}]})  # 旗・散る印・行の帯
	elif frame == 200:
		print("DRAW result screen=%s score=%s" % [main.screen, main.current._score.text])
		main._show_keys()
	elif frame == 210:
		print("DRAW keys screen=%s" % main.screen)
		quit()
	return false


static func _ev(pk: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = pk as Key
	return e


func _key(pk: int) -> void:
	main._input(_ev(pk))


# P1 が大きな四角を回って陣地へ戻る直前の盤(次の移動で 60 マス以上を囲む)。
func _big_loop(sim: Sim) -> void:
	sim.phase = Sim.PHASE_MOVE
	sim.count_tick = B.COUNTDOWN_TICKS
	var path: Array = []
	for x in range(11, 26):
		path.append(Vector2i(x, 13))
	for y in range(14, 21):
		path.append(Vector2i(25, y))
	for x in range(24, 7, -1):
		path.append(Vector2i(x, 20))
	for y in range(19, 15, -1):
		path.append(Vector2i(8, y))
	for c: Vector2i in path:
		sim.grid.trail[Grid.idx(c.x, c.y)] = 1
	sim.heads[0] = Grid.idx(8, 16)
	sim.dirs[0] = 0
	sim.heads[1] = Grid.idx(40, 2)
	sim.dirs[1] = 0
