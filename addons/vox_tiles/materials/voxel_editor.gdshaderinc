// Editor view, shared by the voxel shaders. plugin.gd sets the global zwervr_editor to 1
// in the Godot editor (Project > Tools > "Vox Tiles: editor view" switches it): the
// shaders then skip their costly detail and animation, and draw a thin dark line on the
// borders of the 4 m tile grid so the tiles stand out. In the game it stays 0.
global uniform float zwervr_editor;

bool editor_view() {
	return zwervr_editor > 0.5;
}

// 0..1: how much of a 4 m grid line covers this pixel. wp = world position, wn = world
// normal: top and bottom faces get lines along x and z, walls the vertical lines of the
// grid along them. About 1.5 pixels wide at any distance.
float tile_border(vec3 wp, vec3 wn) {
	vec3 an = abs(wn);
	float line = 0.0;
	if (an.y > 0.5 || an.z > 0.5) {
		float d = abs(fract(wp.x / 4.0 + 0.5) - 0.5) * 4.0;
		line = max(line, 1.0 - smoothstep(0.0, fwidth(wp.x) * 1.5, d));
	}
	if (an.y > 0.5 || an.x > 0.5) {
		float d = abs(fract(wp.z / 4.0 + 0.5) - 0.5) * 4.0;
		line = max(line, 1.0 - smoothstep(0.0, fwidth(wp.z) * 1.5, d));
	}
	return line;
}
