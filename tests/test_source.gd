# ソースの決まりのテスト(AC-23・INV-2・INV-6・INV-8)と、同梱の字体に画面の文字が全部あるか。
extends "res://tests/suite.gd"


static func _files(dir: String) -> Array:
	return Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".gd")).map(
		func(f: String) -> String: return dir.path_join(f))


static func _code(path: String) -> String:
	# コメントを除いた本文
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var k := line.find("#")
		out.append(line if k < 0 else line.substr(0, k))
	return "\n".join(out)


func test_ac23_core_is_pure() -> bool:
	var re := RegEx.create_from_string("\\b(sin|cos|randf|randi|randf_range|randi_range)\\s*\\(|\\bTime\\.|extends\\s+Node|Input\\.")
	for f: String in _files("res://core"):
		var code := _code(f)
		ok(code.contains("extends RefCounted"), "%s は RefCounted" % f)
		var m := re.search(code)
		ok(m == null, "%s に禁じた呼び出し: %s" % [f, m.get_string() if m != null else ""])
	return true


func test_ac23_no_japanese_literals_outside_strings() -> bool:
	# 日本語の文言は core/strings.gd だけ
	var re := RegEx.create_from_string("\"[^\"\\n]*[\\x{3000}-\\x{9FFF}\\x{FF00}-\\x{FFEF}][^\"\\n]*\"")
	var found: Array = []
	for dir: String in ["res://core", "res://ui", "res://audio", "res://save"]:
		for f: String in _files(dir):
			if f.ends_with("strings.gd"):
				continue
			for m in re.search_all(_code(f)):
				found.append("%s: %s" % [f, m.get_string()])
	eq(found, [], "strings.gd の外の文言")
	return true


func test_font_has_all_glyphs() -> bool:
	var font := load("res://assets/fonts/NotoSansJP-Subset.ttf") as FontFile
	ok(font != null, "同梱の字体を読める")
	if font == null:
		return true
	var text := FileAccess.get_file_as_string("res://core/strings.gd")
	var re := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	var chars := {}
	for m in re.search_all(text):
		for c in m.get_string(1):
			chars[c] = true
	for c in "0123456789/:.,+-%":
		chars[c] = true
	var missing := ""
	for c: String in chars.keys():
		if c != " " and not font.has_char(c.unicode_at(0)):
			missing += c
	eq(missing, "", "字体に無い文字")
	return true


func test_inv8_no_network() -> bool:
	var re := RegEx.create_from_string("HTTPRequest|HTTPClient|WebSocket|XMLHttpRequest|fetch[(]|https?://")
	for dir: String in ["res://core", "res://ui", "res://audio", "res://save"]:
		for f: String in _files(dir):
			var m := re.search(_code(f))
			ok(m == null, "%s に通信: %s" % [f, m.get_string() if m != null else ""])
	return true


func test_each_source_has_header_comment() -> bool:
	for dir: String in ["res://core", "res://ui", "res://audio", "res://save", "res://tests"]:
		for f: String in _files(dir):
			ok(FileAccess.get_file_as_string(f).begins_with("# "), "%s の冒頭に責務のコメント" % f)
	return true


# v0.3.0 の題字・数字の字体(Lilita One)に、それで出す字(題字・割合・時間・勝ち数・+n)が全部あるか。
func test_display_font_has_its_glyphs() -> bool:
	var font := load("res://assets/fonts/LilitaOne-Regular.ttf") as FontFile
	ok(font != null, "題字の字体を読める")
	if font == null:
		return true
	var missing := ""
	for c in S.NAME + "0123456789%:+− ":
		if c != " " and not font.has_char(c.unicode_at(0)):
			missing += c
	eq(missing, "", "題字の字体に無い文字")
	return true
