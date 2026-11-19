# 保存のテスト(仕様書 §9.11・AC-18・E-16・NFR-9・INV-7)。テストでは user:// の別のファイルを使う。
extends "res://tests/suite.gd"

const Store := preload("res://save/save_store.gd")
const P := "user://test_save.json"


func _fresh(text: Variant = null) -> Store:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
	if text != null:
		var f := FileAccess.open(P, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	return Store.new(P)


func test_ac18_empty_broken_version2() -> bool:
	var st := _fresh()
	eq(st.data, Store.defaults(), "空")
	ok(not st.load_failed, "空は失敗ではない")
	st = _fresh("{not json")
	eq(st.data, Store.defaults(), "壊れた JSON")
	ok(st.load_failed, "壊れた時は知らせる(E-16)")
	st = _fresh('{"version": 2, "vs_cpu": {"easy": {"win": 9}}}')
	eq(st.data, Store.defaults(), "version が 2")
	ok(st.load_failed, "知らない version も知らせる")
	eq(Store.default_settings(), {"volume": 75, "shake": true, "reduce_flash": false}, "既定値: 音量 75・揺れ 入・点滅を弱める 切")
	return true


func test_records_only_cpu_matches() -> bool:
	var st := _fresh()
	st.record_match(0, 0)
	eq(st.data["vs_cpu"], Store.defaults()["vs_cpu"], "ふたりでは数えない")
	st.record_match(1, 0)
	st.record_match(1, 1)
	st.record_match(1, 1)
	st.record_match(2, -1)
	var again := Store.new(P)
	eq(again.cpu_record(1), {"win": 1, "lose": 2, "draw": 0}, "やさしい")
	eq(again.cpu_record(2), {"win": 0, "lose": 0, "draw": 1}, "ふつう")
	return true


func test_other_tab_counts_are_kept() -> bool:
	var a := _fresh()
	var b := Store.new(P)
	a.record_match(1, 0)
	b.record_match(1, 0)  # b は古い数を持っているが、書く前に読み直す
	eq(Store.new(P).cpu_record(1)["win"], 2, "別のタブの勝ちを消さない")
	b.set_setting("volume", 25)
	eq(Store.new(P).cpu_record(1)["win"], 2, "設定を書いても勝ち負けは消えない")
	return true


func test_settings_persist_and_bad_values() -> bool:
	var st := _fresh()
	st.set_setting("volume", 25)
	st.set_setting("shake", false)
	eq(Store.new(P).settings(), {"volume": 25, "shake": false, "reduce_flash": false}, "設定が残る")
	st = _fresh('{"version": 1, "settings": {"volume": 33, "shake": "yes"}, "vs_cpu": {"easy": {"win": "x", "lose": 4}}}')
	eq(st.settings(), Store.default_settings(), "おかしな値は既定値")
	eq(st.cpu_record(1), {"win": 0, "lose": 4, "draw": 0}, "読める数だけ使う")
	ok(not st.load_failed, "形は読めた")
	return true


func test_save_shape_matches_spec() -> bool:
	var st := _fresh()
	st.record_match(2, 0)
	var j := JSON.new()
	eq(j.parse(FileAccess.get_file_as_string(P)), OK, "JSON で書く")
	var keys: Array = j.data.keys()
	keys.sort()
	eq(keys, ["settings", "version", "vs_cpu"], "§9.11 の形")
	ok(FileAccess.get_file_as_string(P).length() <= 1024, "1 KB 以下")
	eq(Store.WEB_KEY, "key-turf/save", "localStorage のキー名(INV-7)")
	return true
