class_name TestSuite
extends RefCounted
## Base class for unit tests. The runner makes a fresh instance for every
## test_* method, calls it, then reads failures.

var failures: PackedStringArray = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %.4f +/- %.4f, got %.4f" % [message, expected, tolerance, actual])
