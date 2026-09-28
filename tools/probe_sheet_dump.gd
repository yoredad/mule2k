extends SceneTree

func _init() -> void:
	var img: Image = Image.load_from_file("res://assets/mule_sheet.png")
	print("size=", img.get_size())
	var cw := img.get_width() / 5
	var ch := img.get_height() / 4
	for row in 4:
		for col in 5:
			var min_x := 99999
			var min_y := 99999
			var max_x := -1
			var max_y := -1
			for y in range(row * ch, (row + 1) * ch, 8):
				for x in range(col * cw, (col + 1) * cw, 8):
					if img.get_pixel(x, y).a > 0.1:
						min_x = mini(min_x, x)
						min_y = mini(min_y, y)
						max_x = maxi(max_x, x)
						max_y = maxi(max_y, y)
			var cxs: Array = [col]
			for ch_x in 16:
				var line := ""
				for ch_y in 8:
					var total := 0.0
					var count := 0
					for yy in range(ch_y * (ch / 8), (ch_y + 1) * (ch / 8), 8):
						for xx in range(ch_x * (cw / 16), (ch_x + 1) * (cw / 16), 8):
							total += img.get_pixel(xx, yy).a
							count += 1
					var a := total / count
					line += "." if a < 0.05 else ("#" if a > 0.4 else "+")
				print("r", row, "c", col, " bbox=", min_x, ",", min_y, "-", max_x, ",", max_y, " | ", line)
		quit(0)
