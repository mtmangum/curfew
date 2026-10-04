extends SceneTree
func _init() -> void:
    call_deferred("run")
func run() -> void:
    root.add_child(load("res://docs/tools/audit_soak.gd").new())
