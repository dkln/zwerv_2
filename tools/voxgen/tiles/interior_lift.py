"""The lift cabin (category binnen, binnen/lift/): the ride from floor to floor of any building
with floors is a scene of its own in it (scenes/binnen/lift.tscn, scripts/world/lift_ride.gd).

Voxels of 0.125 m; the pivot is the middle of the bottom of the frame, the front the side with
the lowest y (Godot +z).
"""
from common import tile, register
from vox import V

# The lift cabin (scenes/binnen/lift.tscn, scripts/world/lift_ride.gd): any building with floors
# uses it for the ride from floor to floor (the city hall first). 3 m wide, 2 m deep, 2.6 m high, brushed steel,
# a mirror at the back, a handrail, the button panel on the left wall; low at the front and
# the right like every interior (the iso view looks in), its doors low too. Separate pieces,
# so the player can stand inside (the colliders are the blocks of each piece).

CABIN_WIDTH = 24       # 3 m
CABIN_DEPTH = 16       # 2 m
CABIN_HIGH = 21        # 2.6 m
CABIN_LOW = 8          # 1 m


@tile("binnen/lift/cabine_vloer")
def cabin_floor():
    """The floor of the cabin: black rubber with raised studs."""
    model = V(CABIN_WIDTH, CABIN_DEPTH, 1)
    for x in range(CABIN_WIDTH):
        for y in range(CABIN_DEPTH):
            model.set(x, y, 0, "rubber" if (x + y) % 3 else "metaal_donker")
    return model


def _cabin_wall(width, height, mirror=False):
    """A wall of the cabin, one deep: brushed steel panels, a handrail at 0.9 m on a high one,
    a mirror in the middle of the back one."""
    model = V(width, 1, height)
    for x in range(width):
        for z in range(height):
            model.set(x, 0, z, "lak_zilver2" if x % 5 == 0 else ("rvs" if z % 4 else "lak_zilver1"))
    if height > CABIN_LOW:
        model.box(1, 0, 7, width - 1, 1, 8, "messing")
        model.box(0, 0, height - 1, width, 1, height, "lamp_wit")
    if mirror:
        model.box(4, 0, 9, width - 4, 1, height - 3, "glas_kantoor")
    return model


register("binnen/lift/cabine_achterwand", lambda: _cabin_wall(CABIN_WIDTH, CABIN_HIGH, mirror=True))
register("binnen/lift/cabine_zijwand", lambda: _cabin_wall(CABIN_DEPTH, CABIN_HIGH))
register("binnen/lift/cabine_zijwand_laag", lambda: _cabin_wall(CABIN_DEPTH, CABIN_LOW))
# beside the doors at the front: 1 m each side (the doors 1 m between them)
register("binnen/lift/cabine_voorwand_laag", lambda: _cabin_wall(8, CABIN_LOW))


@tile("binnen/lift/cabine_deur")
def cabin_door():
    """One leaf of the cabin doors, low as the front (0.5 m wide): steel, a dark edge."""
    model = V(4, 1, CABIN_LOW)
    model.box(0, 0, 0, 4, 1, CABIN_LOW, "rvs")
    model.box(0, 0, 0, 1, 1, CABIN_LOW, "lak_zilver2")
    return model


@tile("binnen/lift/cabine_paneel")
def cabin_panel():
    """The button panel on the wall (0.375 m wide, 1 m high, from 0.75 m up): steel with a
    column of round lit buttons, a little screen over them and the alarm bell in yellow."""
    model = V(3, 1, 14)
    model.box(0, 0, 6, 3, 1, 14, "metaal3")
    for row in range(5):
        model.set(1, 0, 7 + row * 1, "lamp_warm")
    model.box(0, 0, 12, 3, 1, 13, "scherm")
    model.set(1, 0, 13, "lak_geel1")
    return model
