extends RefCounted
## Unit tests of the blocks of a prop's collider (addons/vox_tiles/library/library_builder.gd,
## _block_shapes): they follow the model coarsely, a post stays a thin post.

const Builder = preload("res://addons/vox_tiles/library/library_builder.gd")


## A mesh of boxes (centre, size), as a voxel model is: square to the axes.
func _boxes(boxes: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box: Array in boxes:
		var cube := BoxMesh.new()
		cube.size = box[1]
		tool.append_from(cube, 0, Transform3D(Basis(), box[0]))
	return tool.commit()


func test_a_box_is_one_block(test) -> void:
	var shapes := Builder._block_shapes(_boxes([[Vector3(0, 0.5, 0), Vector3(1, 1, 1)]]))
	test.check(shapes.size() == 2, "een blok (%d)" % (shapes.size() / 2))
	if shapes.size() == 2:
		test.check(((shapes[0] as BoxShape3D).size - Vector3(1, 1, 1)).length() < 0.01, "zo groot als het model")


func test_a_lamppost_is_a_thin_post_with_a_head(test) -> void:
	var post := _boxes([[Vector3(0, 2.0, 0), Vector3(0.2, 4.0, 0.2)], [Vector3(0.5, 4.25, 0), Vector3(1.2, 0.5, 0.3)]])
	var shapes := Builder._block_shapes(post)
	var thinnest := INF
	var widest := 0.0
	for index in range(0, shapes.size(), 2):
		var size := (shapes[index] as BoxShape3D).size
		thinnest = minf(thinnest, size.x)
		widest = maxf(widest, size.x)
	test.check(shapes.size() / 2 >= 2, "paal en kop apart (%d blokken)" % (shapes.size() / 2))
	test.check(thinnest < 0.3, "de paal blijft dun (%.2f m)" % thinnest)
	test.check(widest > 1.0, "de kop is breed (%.2f m)" % widest)


func test_never_more_than_the_most_blocks(test) -> void:
	var steps := []
	for level in 20:
		steps.append([Vector3(0, level * 0.25 + 0.125, 0), Vector3(0.2 + (level % 2) * 1.0, 0.25, 0.2)])
	var shapes := Builder._block_shapes(_boxes(steps))
	test.check(shapes.size() / 2 <= Builder.MOST_BLOCKS, "hooguit %d blokken (%d)" % [Builder.MOST_BLOCKS, shapes.size() / 2])
