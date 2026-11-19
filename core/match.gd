# 試合(仕様書 §9.7): 練習のラウンド・数えるラウンドの数・勝ち数。ラウンドの間の待ちは ui が数える。
# 練習(with_practice が真の時の最初の 1 つ)は数えない。WINS_TO_WIN 勝か、数えるラウンドが MAX_ROUNDS に届くと終わる。
extends RefCounted

const B := preload("res://core/balance.gd")
const Sim := preload("res://core/sim.gd")

var mode := 0
var seed_value := 1
var wins: Array[int] = [0, 0]
var rounds: Array = []  # 数えたラウンドごとの { winner, reason, counts }
var _practice_left := false
var _in_practice := false


func _init(p_mode: int, with_practice: bool, p_seed: int) -> void:
	mode = p_mode
	seed_value = p_seed
	_practice_left = with_practice


# 次のラウンドの Sim(盤は毎回初めの形)。CPU の rng の種は seed + ラウンドの番号(練習は 0)。
func next_round() -> Sim:
	_in_practice = _practice_left
	var n := 0 if _in_practice else rounds.size() + 1
	var s := (seed_value + n) & 0xFFFFFFFF
	return Sim.new(mode, B.PRACTICE_TICKS if _in_practice else B.ROUND_TICKS, s if s != 0 else 1)


func finish_round(result: Dictionary) -> void:
	if _in_practice:
		_in_practice = false
		_practice_left = false
		return
	var w: int = result["winner"]
	rounds.append({"winner": w, "reason": int(result["reason"]), "counts": (result["counts"] as Array).duplicate()})
	if w >= 0:
		wins[w] += 1


# 今のラウンド(まだ作っていなければ次のラウンド)が練習か。
func is_practice() -> bool:
	return _in_practice or _practice_left


func round_number() -> int:
	return rounds.size() + (0 if is_practice() else 1)


func is_over() -> bool:
	return wins[0] >= B.WINS_TO_WIN or wins[1] >= B.WINS_TO_WIN or rounds.size() >= B.MAX_ROUNDS


func result() -> Dictionary:
	var w := -1
	if wins[0] != wins[1]:
		w = 0 if wins[0] > wins[1] else 1
	return {"winner": w, "wins": wins.duplicate(), "rounds": rounds.duplicate(true)}
