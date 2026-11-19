# 保存の読み書き(仕様書 §9.11・FR-23・E-16・E-17)。CPU との段ごとの通算の勝ち負けと設定を持つ。
# 置き場: Web はブラウザの localStorage の key-turf/save(共通 §3 の 10。user:// は同じサイトのゲーム全部で 1 つなので使わない)、
# それ以外は user://save.json。読めない・壊れている・version が違う時は既定値で始め、書けなくても止めない。作りは RootCall・ParryDuel・KeySwat の save_store。
extends RefCounted

const B := preload("res://core/balance.gd")

const PATH := "user://save.json"
const VERSION := 1
const WEB_KEY := "key-turf/save"
const LEVEL_KEYS := ["", "easy", "normal"]  # mode 1 = やさしい、2 = ふつう
# 使えない時は投げずに null / "no" を返す。書けたかは文字の 'ok' で返す(JS の true は 4.7.2 の Web で bool として届かない。ParryDuel v0.1.2)
const JS_READ := "(() => { try { return localStorage.getItem('%s'); } catch (e) { return null; } })()"
const JS_WRITE := "(() => { try { localStorage.setItem('%s', %s); return 'ok'; } catch (e) { return 'no'; } })()"

var path: String
var data: Dictionary = {}
var load_failed := false  # 保存があったのに読めなかった(E-16)
var write_failed := false  # 直前の書き込みが失敗した(E-17)
var _web := OS.has_feature("web")


func _init(p_path: String = PATH) -> void:
	path = p_path
	load_data()


static func default_settings() -> Dictionary:
	return {"volume": B.DEFAULT_VOLUME, "shake": true, "reduce_flash": false}


static func empty_record() -> Dictionary:
	return {"win": 0, "lose": 0, "draw": 0}


static func defaults() -> Dictionary:
	return {"version": VERSION, "vs_cpu": {"easy": empty_record(), "normal": empty_record()}, "settings": default_settings()}


func load_data() -> void:
	data = defaults()
	load_failed = false
	var text: Variant = _read_text()
	if text == null:
		return
	var read: Variant = parse(text)
	if read == null:
		load_failed = true
	else:
		data = read


func _read_text() -> Variant:
	if _web:
		var v: Variant = JavaScriptBridge.eval(JS_READ % WEB_KEY, true)
		return v if v is String else null
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)


func _write_text(text: String) -> bool:
	if _web:
		var ok: Variant = JavaScriptBridge.eval(JS_WRITE % [WEB_KEY, JSON.stringify(text)], true)
		return ok is String and ok == "ok"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


# 保存の文字を決まった形に直す。読めない・辞書でない・version が 1 でない時は null(既定値で始める)。
static func parse(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK or not (j.data is Dictionary):
		return null
	var v: Dictionary = j.data
	if not _is_num(v.get("version")) or float(v["version"]) != float(VERSION):
		return null
	var out := defaults()
	var vs: Variant = v.get("vs_cpu")
	if vs is Dictionary:
		for level: String in ["easy", "normal"]:
			var r: Variant = vs.get(level)
			if r is Dictionary:
				for k: String in ["win", "lose", "draw"]:
					if _is_num(r.get(k)):
						out["vs_cpu"][level][k] = maxi(int(r[k]), 0)
	var st: Variant = v.get("settings")
	if st is Dictionary:
		if _is_num(st.get("volume")) and int(st["volume"]) in B.VOLUMES:
			out["settings"]["volume"] = int(st["volume"])
		for k: String in ["shake", "reduce_flash"]:
			if st.get(k) is bool:
				out["settings"][k] = st[k]
	return out


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


# 書く直前に、今ある保存の勝ち負けを読み直して使う(同じブラウザの別のタブが先に足した数を消さない)。
func _merge_from_disk() -> void:
	var text: Variant = _read_text()
	var disk: Variant = parse(text) if text != null else null
	if disk != null:
		data["vs_cpu"] = disk["vs_cpu"]


func save_data() -> bool:
	write_failed = not _write_text(JSON.stringify(data, "", false))
	return not write_failed


# CPU との試合が終わった時に呼ぶ(FR-23)。mode 1・2 だけ数える(ふたりでは数えない)。winner は試合の勝者(0 = あなた)。
# 書けたかを返す。
func record_match(mode: int, winner: int) -> bool:
	if mode != 1 and mode != 2:
		return true
	_merge_from_disk()
	var r: Dictionary = data["vs_cpu"][LEVEL_KEYS[mode]]
	var k := "draw" if winner < 0 else ("win" if winner == 0 else "lose")
	r[k] = int(r[k]) + 1
	return save_data()


func cpu_record(mode: int) -> Dictionary:
	return data["vs_cpu"][LEVEL_KEYS[mode]]


func settings() -> Dictionary:
	return data["settings"]


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	_merge_from_disk()
	save_data()
