extends RefCounted
# Stable identities and initial-condition evidence, without engine instance IDs.
static func random_seed(home_seed: int, run_index: int) -> int:
    return 1000 * home_seed + run_index + 1

static func vector(value: Vector2) -> Array:
    return [snappedf(value.x, 0.0001), snappedf(value.y, 0.0001)]

static func snapshot(main) -> Dictionary:
    var state := {"player": vector(main.player.global_position), "dog": vector(main.dog.global_position)}
    for key in ["cops", "cats", "squirrels", "npcs", "item_pickups"]:
        var actors: Array = []
        for actor in main.get(key):
            var entry := {"position": vector(actor.global_position)}
            for prop in actor.get_property_list():
                if prop.name in ["angle", "timer", "wait", "t", "sit_t", "kind", "state", "route_i"]:
                    entry[prop.name] = actor.get(prop.name)
            actors.append(entry)
        state[key] = actors
    state["traffic_rng_state"] = str(main.traffic_director.rng.state)
    state["weather_rng_state"] = str(main.look.audit_rng.state)
    state["rain"] = main.look.rain.streaks.duplicate(true) if main.look.rain != null else []
    state["destination"] = vector(main.home_zone.get_center())
    return state

static func signature(state: Dictionary) -> String:
    return JSON.stringify(state).sha256_text()

static func source_signature() -> String:
    var hashes := {}
    for file in DirAccess.get_files_at("res://scripts"):
        if file.ends_with(".gd"):
            hashes[file] = FileAccess.get_file_as_string("res://scripts/" + file).sha256_text()
    for file in ["bot_playtest.gd", "audit_inputs.gd", "audit_route.gd", "bot_policy.gd"]:
        hashes[file] = FileAccess.get_file_as_string("res://docs/tools/" + file).sha256_text()
    return signature(hashes)
