extends TestSuite
## Pins down how packed arrays behave when copied between GDScript variables,
## which the hot-loop guidance in CLAUDE.md depends on. Whatever the engine
## does, writing results back (as the swarm code does) must work.

var member := PackedFloat32Array([0.0, 0.0])


func test_report_local_alias_behaviour() -> void:
	var local := member
	local[0] = 1.0
	print("  packed array: write through a local alias %s the member"
			% ("CHANGES" if member[0] == 1.0 else "does NOT change"))
	member = local
	check_eq(member[0], 1.0, "assigning back always works")
