class_name TestUtils
extends RefCounted

var _failures: Array[String] = []
var _checks := 0

func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func eq(actual: Variant, expected: Variant, message: String) -> void:
	_checks += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])

func finish(tree: SceneTree) -> void:
	for failure in _failures:
		printerr("FAIL: " + failure)

	if _failures.is_empty():
		print("ALL PASSED (%d checks)" % _checks)
		tree.quit(0)
	else:
		print("%d of %d checks failed" % [_failures.size(), _checks])
		tree.quit(1)
