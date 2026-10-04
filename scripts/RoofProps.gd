extends Node2D
# What stands on a roof (the air-conditioning units and the water tank), as a piece of its own on top
# of the building. It is drawn once and kept, like the roof, but being separate it can fade on its own:
# with the building see-through, the things on the roof go much fainter than the roof (the building's
# alpha, squared), or, for a piece that would show outside the building's outline (Roofs.overhangs),
# not show at all (DepthSorter.fade_buildings), so none of it looks like clutter standing in the street.
# A building has up to two: `roof_props` for the pieces that stay over it and `roof_over` for the rest.
# The turning fans are its children, so they fade with it. (Roofs.paint_props does the drawing; it needs
# the same few helpers a Building has, so they are here too.)

const Sprites := preload("res://scripts/Sprites.gd")
const RoofsScript := preload("res://scripts/Roofs.gd")

var building  # the Building this stands on (its height)
var props: Array = []  # the pieces of its roof plan this one draws

func _draw() -> void:
    draw_set_transform_matrix(Sprites.UP)
    RoofsScript.paint_props(self)

func _p(x: float, y: float, z: float) -> Vector2:
    return Sprites.proj(Vector2(x, y), z)

func _quad(origin: Vector2, along: Vector2, u0: float, u1: float, z0: float, z1: float) -> PackedVector2Array:
    return building._quad(origin, along, u0, u1, z0, z1)

func _roof_box(x: float, y: float, w: float, d: float, h: float, base_z: float, wall_s: Color, wall_e: Color, top: Color) -> void:
    Sprites.roof_box(self, x, y, w, d, h, base_z, wall_s, wall_e, top)
