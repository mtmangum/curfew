extends SceneTree
# Exact game drawing code, rendered to transparent PNGs for the web gallery.
# Run with Godot --path . --script docs/tools/render_rooftop_gallery.gd
const Sprites = preload("res://scripts/Sprites.gd")
const Roofs = preload("res://scripts/Roofs.gd")

class Preview extends Node2D:
    var kind := "ac"
    var variant := 0
    var phase := 0.0
    func _p(x: float, y: float, z: float) -> Vector2:
        return Sprites.proj(Vector2(x, y), z)
    func _quad(origin: Vector2, along: Vector2, u0: float, u1: float, z0: float, z1: float) -> PackedVector2Array:
        var a := origin + along * u0
        var b := origin + along * u1
        return PackedVector2Array([_p(a.x,a.y,z0),_p(b.x,b.y,z0),_p(b.x,b.y,z1),_p(a.x,a.y,z1)])
    func _roof_box(x: float,y: float,w: float,d: float,h: float,base: float,s: Color,e: Color,t: Color) -> void:
        Sprites.roof_box(self,x,y,w,d,h,base,s,e,t)
    func _draw() -> void:
        var lines := PackedVector2Array()
        var cols := PackedColorArray()
        var glows: Array = []
        var p := {"x":0.0,"y":0.0,"w":28.0,"d":18.0,"h":14.0,"v":variant,"spin":kind == "fan"}
        if kind == "tower":
            p.w = 26.0; p.d = 26.0; p.h = 50.0
            Roofs._tower(self,p,0.0,lines,cols)
        elif kind == "house":
            Roofs._house(self,Rect2(0,0,64,40),0.0,Color("725044"),lines,cols,glows)
        else:
            Roofs._unit(self,p,0.0,lines,cols,glows)
        Roofs._flush(self,lines,cols,glows)
        if kind == "fan":
            var centre: Vector2 = Roofs.fan_centre(p)
            var radius: float = Roofs.fan_radius(p)
            for k in 4:
                var a: float = phase + float(k) * PI * 0.5
                var end := centre + Vector2(cos(a),sin(a)) * radius
                draw_line(_p(centre.x,centre.y,p.h),_p(end.x,end.y,p.h),Color("6c7380"),1.0)

func _init() -> void:
    call_deferred("render_all")

func render_all() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(192,160)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var prop := Preview.new()
    prop.position = Vector2(96,100)
    viewport.add_child(prop)
    var jobs: Array = [ ["ac","cream0",0,0.0],["ac","sage0",1,0.0],["ac","grey0",2,0.0],["tower","tank0",0,0.0],["house","roof0",0,0.0] ]
    for i in 16:
        jobs.append(["fan","spin%d" % i,0,float(i)*TAU/16.0])
    for job in jobs:
        prop.kind = job[0]; prop.variant = job[2]; prop.phase = job[3]
        prop.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        var img := viewport.get_texture().get_image()
        # Common crop for all AC states keeps their placement stable in animation.
        var rect := Rect2i(64,72,72,52)
        if prop.kind == "tower": rect = Rect2i(68,57,58,66)
        if prop.kind == "house": rect = Rect2i(54,42,98,103)
        img = img.get_region(rect)
        img.save_png("res://docs/gallery/rooftops/%s.png" % job[1])
    print("Rendered 21 rooftop gallery frames from Roofs.gd")
    quit()
