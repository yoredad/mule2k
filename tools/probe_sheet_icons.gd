extends SceneTree

func _init() -> void:
	var img: Image = Image.load_from_file("res://assets/mule_sheet.png")
	var bands := [
		[284, 440], [462, 620], [637, 796], [810, 971], [987, 1147],
	]
	var rows := [[97, 244], [291, 439], [485, 632], [677, 828]]
	for r in 4:
		for c in 5:
			var x0: int = bands[c][0]
			var y0: int = rows[r][0]
			var x1: int = bands[c][1]
			var y1: int = rows[r][1]
			var w: int = x1 - x0
			var h: int = y1 - y0
			var r_sum := 0.0
			var g_sum := 0.0
			var b_sum := 0.0
			var n := 0.0
			for y in range(y0, y1, 6):
				for x in range(x0, x1, 6):
					var px: Color = img.get_pixel(x, y)
					if px.a > 0.3:
						r_sum += px.r
						g_sum += px.g
						b_sum += px.b
						n += 1.0
			var avg := Color(r_sum / n, g_sum / n, b_sum / n) if n > 0 else Color.BLACK
			print("row", r, " col", c, " avg_rgb=", int(avg.r * 255), ",", int(avg.g * 255), ",", int(avg.b * 255))
	quit(0)
