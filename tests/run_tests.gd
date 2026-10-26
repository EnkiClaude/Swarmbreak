extends SceneTree
## Headless unit test runner. Runs every test_* method of every script in
## res://tests/unit/ and exits with code 1 if any check failed.
##   godot --headless --path . -s res://tests/run_tests.gd
## A runtime script error inside a test prints "SCRIPT ERROR" rather than
## failing a check; tools/check.sh treats that as a failure too.

const TEST_DIR := "res://tests/unit/"


func _initialize() -> void:
	var total := 0
	var failed := 0
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file in files:
		if not file.ends_with(".gd"):
			continue
		var script: GDScript = load(TEST_DIR + file)
		var names: PackedStringArray = []
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if method_name.begins_with("test_") and not names.has(method_name):
				names.append(method_name)
		names.sort()
		for method_name in names:
			total += 1
			print("RUN  %s.%s" % [file.get_basename(), method_name])
			var suite: TestSuite = script.new()
			suite.call(method_name)
			if suite.failures.is_empty():
				continue
			failed += 1
			for failure in suite.failures:
				print("FAIL %s.%s: %s" % [file.get_basename(), method_name, failure])
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
