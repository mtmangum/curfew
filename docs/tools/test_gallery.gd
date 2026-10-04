extends SceneTree
# The sprite gallery's manifest (web/sprite-gallery-data.js, made by docs/tools/build_sprite_gallery.py)
# lists every frame that is on disk and nothing that is not, and has the code-drawn groups that
# render_gallery_extras.gd and render_rooftop_gallery.gd make (grates, shop windows, signs, signals).
#   godot --headless --fixed-fps 60 --path . --script docs/tools/test_gallery.gd
const EXPECTED := {
    "treegrate": ["kerb", "plaza", "planted"],
    "shopwindow": ["shoes", "hats", "electronics", "boutique", "grocer", "bakery", "books"],
    "neonsign": ["pink", "cyan", "red"],
    "copmark": ["question", "alert"],
    "thought": ["bubble"],
    "clueicon": ["question", "alert", "house", "bin", "paw", "zombie"],
    "rooftopac": ["cream", "sage", "grey", "spin"],
}

func _init() -> void:
    var text := FileAccess.get_file_as_string("res://web/sprite-gallery-data.js")
    var json := JSON.new()
    var parsed: bool = json.parse(text.substr(text.find("{"), text.rfind("}") - text.find("{") + 1)) == OK
    var groups: Dictionary = json.data if parsed and json.data is Dictionary else {}
    var frames := 0
    var missing := 0
    var listed := {}
    for group in groups:
        for state in groups[group]:
            for f in groups[group][state]:
                frames += 1
                var src: String = str(f.src).split("?")[0]
                listed[src] = true
                if not FileAccess.file_exists("res://" + src) or int(f.width) <= 0 or int(f.height) <= 0:
                    missing += 1
    # every PNG the gallery shows is listed (the sprites, and the rendered frames under docs/gallery)
    var unlisted := 0
    for root_dir in ["res://assets/sprites", "res://docs/gallery"]:
        for folder in DirAccess.get_directories_at(root_dir):
            for file in DirAccess.get_files_at("%s/%s" % [root_dir, folder]):
                if file.ends_with(".png") and not listed.has(("%s/%s/%s" % [root_dir, folder, file]).trim_prefix("res://")):
                    unlisted += 1
    var absent: Array = []
    for group in EXPECTED:
        for state in EXPECTED[group]:
            if not groups.has(group) or not groups[group].has(state):
                absent.append("%s/%s" % [group, state])
    print("1. manifest parsed: ", parsed, ", ", groups.size(), " groups, ", frames, " frames; listed but not on disk ", missing, ", on disk but not listed ", unlisted,
        "; expected states missing: ", absent, "  ok: ", parsed and missing == 0 and unlisted == 0 and absent.is_empty() and groups.size() >= 21)
    quit()
