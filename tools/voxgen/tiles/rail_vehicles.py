"""The cars of the rail vehicles: props/voertuigen/randstadrail_* and ns_* (placed and moved
by scripts/vehicles/randstadrail.gd and ns_train.gd). x across, y along with the front
at y=0, z up. A cab car has a driver's cab at the front: a narrowing nose with a windscreen
that leans back, a sign above it, lamps and a bumper under it and a side window for the
driver; every car has bogies under it, a band of windows, doors on both sides and something
on its roof, some cars a pantograph whose contact strip reaches up to the contact wire of
scripts/world/overhead_lines.gd (`pantograph_top`: the voxel of the strip, counted from
the wheels; the car stands `model_lift` above the rails). The last car of a train is a cab
car turned round, so that end looks the same.
The door leaves are models of their own (props/voertuigen/*_deur): the car has an opening
for them, scripts/vehicles/rail_vehicle.gd slides them open at a platform."""
from common import tile
from vox import V

# Cars of the cab: how far back the nose goes, and where the driver's side window is.
NOSE_LENGTH = 6
CAB_WINDOW = range(8, 14)
CAB_LENGTH = 16
# Voxels of the floor under a car, and of one door leaf along the car (a door has two).
FLOOR_HEIGHT = 4
DOOR_LEAF_LENGTH = 5
# A pantograph: voxels along the car its base takes, and half the width of its head.
PANTOGRAPH_LENGTH = 14
PANTOGRAPH_HALF_WIDTH = 6
# The voxel of the contact strip: the tram's wire hangs 5.5 m above the rails, the train's
# 5.6 m (the train's model stands 0.375 m higher, model_lift in ns_train.gd).
TRAM_PANTOGRAPH_TOP = 43
TRAIN_PANTOGRAPH_TOP = 41


def nose_narrowing(along):
    """Voxels the nose is narrower on each side at this distance from the front."""
    return (NOSE_LENGTH - along) // 2 if along < NOSE_LENGTH else 0


def nose_front(up, window_low, height):
    """Where the nose starts at this height: straight below the windows, then leaning back."""
    if up < window_low:
        return 0
    return 1 + (up - window_low) * (NOSE_LENGTH - 1) // (height - 1 - window_low)


def cab_colour(along, across, up, width, front, window_low, window_high, lower, band, body):
    """The colour of the outside of the nose, or None for what lies inside it."""
    narrowing = nose_narrowing(along)
    at_side = across in (narrowing, width - 1 - narrowing)
    if along == front:
        if up < window_low - 4:
            return "metaal_donker"   # the bumper
        if up < window_low - 2:
            return lower
        if up < window_low:
            return band
        if up >= window_high:
            return "bord_zwart" if up < window_high + 3 and not at_side else body
        if at_side:
            return body              # the corner posts of the windscreen
        return "metaal_donker" if across == width // 2 else "glas2"
    if at_side:
        if up < window_low - 2:
            return lower
        if up < window_low:
            return band
        return body
    return None


def voxel_line(model, start, end, colour):
    """Voxels on the straight line from `start` to `end` ((across, along, up) each)."""
    steps = max(abs(end[index] - start[index]) for index in range(3))
    for step in range(steps + 1):
        share = step / steps if steps else 0.0
        model.set(*(round(start[index] + (end[index] - start[index]) * share) for index in range(3)), colour)


def pantograph(model, width, start, roof, top):
    """A single-arm pantograph on the roof voxel layer `roof`, its base from `start` along
    the car: a frame on four insulators, a lower arm rising to the knee at the back, an
    upper arm leaning forward again to the head, whose contact strip lies in voxel `top`
    with a horn bent down at each end."""
    middle = width // 2
    base = roof + 1
    for along in range(start, start + PANTOGRAPH_LENGTH):
        for across in (middle - 3, middle + 3):
            model.set(across, along, base + 1, "metaal_donker")
    for along in (start + 1, start + PANTOGRAPH_LENGTH - 2):
        for across in (middle - 3, middle + 3):
            model.set(across, along, base, "rubber")
    hinge = (start + 2, base + 2)
    knee = (start + PANTOGRAPH_LENGTH - 1, base + 2 + (top - base - 2) * 3 // 5)
    head = (start + 3, top - 1)
    for across in (middle - 1, middle + 1):
        voxel_line(model, (across, hinge[0], hinge[1]), (across, knee[0], knee[1]), "metaal2")
    voxel_line(model, (middle, knee[0], knee[1]), (middle, head[0], head[1]), "metaal2")
    # the head: two contact strips across the car, horns bent down at the ends
    for along in (head[0] - 1, head[0] + 1):
        for across in range(middle - PANTOGRAPH_HALF_WIDTH, middle + PANTOGRAPH_HALF_WIDTH + 1):
            model.set(across, along, top, "metaal_donker")
        for across in (middle - PANTOGRAPH_HALF_WIDTH - 1, middle + PANTOGRAPH_HALF_WIDTH + 1):
            model.set(across, along, top - 1, "metaal_donker")
    for across in range(middle - 2, middle + 3):
        model.set(across, head[0], top - 1, "metaal3")


def rail_car(width, length, height, body, lower, band, door, cab, roof_box, pantograph_at=None, pantograph_top=0):
    """A car: `body` above, `lower` below the windows, a `band` under them, `door` panels;
    a pantograph from `pantograph_at` along the car, if given, its strip in voxel `pantograph_top`."""
    model = V(width, length, max(height, pantograph_top + 1))
    floor = FLOOR_HEIGHT
    window_low = floor + 8
    window_high = height - 7
    doors = (length // 4, 3 * length // 4)
    for along in range(length):
        for across in range(width):
            side = across in (0, width - 1)
            for up in range(floor, height - 1):
                if cab and along < NOSE_LENGTH:
                    narrowing = nose_narrowing(along)
                    front = nose_front(up, window_low, height)
                    if across < narrowing or across >= width - narrowing or along < front:
                        continue
                    colour = cab_colour(along, across, up, width, front, window_low, window_high, lower, band, body)
                    model.set(across, along, up, colour or "auto_interieur")
                    continue
                nearest_door = min(doors, key=lambda place: abs(along - place))
                in_door = -DOOR_LEAF_LENGTH <= along - nearest_door < DOOR_LEAF_LENGTH
                if in_door and side:
                    continue         # the opening: the leaves are models of their own
                if not side and along not in (0, length - 1):
                    colour = "auto_interieur"
                elif up < window_low - 2:
                    colour = lower
                elif up < window_low:
                    colour = band
                elif cab and along < CAB_LENGTH and side:
                    # no doors here: the driver's own side window
                    colour = "glas2" if along in CAB_WINDOW and window_low <= up < window_high else body
                elif window_low <= up < window_high and side:
                    colour = "metaal_donker" if along % 12 == 0 else "glas2"
                else:
                    colour = body
                model.set(across, along, up, colour)
    # the roof, with a box of equipment and a darker edge
    for along in range(NOSE_LENGTH if cab else 0, length):
        for across in range(1, width - 1):
            model.set(across, along, height - 1, "lak_zilver2" if along % 16 else "metaal_donker")
    for along in range(length // 2 - roof_box // 2, length // 2 + roof_box // 2):
        for across in range(4, width - 4):
            model.set(across, along, height - 1, "metaal3")
    # the bogies: dark frames and wheels on the rails, 2 m in from each end
    for centre in (16, length - 17):
        for along in range(centre - 8, centre + 9):
            for across in range(2, width - 2):
                for up in range(1, floor):
                    model.set(across, along, up, "metaal_donker")
            for across in (2, width - 3):
                if abs(along - centre) in (5, 6) or abs(along - centre) in (4, 7):
                    model.set(across, along, 0, "rubber")
    if pantograph_at is not None:
        pantograph(model, width, pantograph_at, height - 1, pantograph_top)
    if cab:
        # white headlights on the front, under the windscreen, and red tail lights between
        # them (they burn on the last car, scripts/vehicles/rail_vehicle.gd)
        for across in (4, 5, width - 6, width - 5):
            model.set(across, 0, window_low - 3, "lamp_wit")
        for across in (7, 8, width - 9, width - 8):
            model.set(across, 0, window_low - 3, "stoplicht_rood_uit")
    return model


def door_leaf(car_height, colour):
    """One leaf of a car door, from the floor to under the roof, with a window in it."""
    floor = FLOOR_HEIGHT
    height = car_height - 1 - floor
    window_low = 8
    window_high = car_height - 7 - floor
    model = V(1, DOOR_LEAF_LENGTH, height)
    for along in range(DOOR_LEAF_LENGTH):
        for up in range(height):
            in_window = 0 < along < DOOR_LEAF_LENGTH - 1 and window_low <= up < window_high
            model.set(0, along, up, "glas2" if in_window else colour)
    return model


@tile("props/voertuigen/randstadrail_deur")
def randstadrail_door():
    """Door leaf of a RandstadRail car."""
    return door_leaf(29, "lak_rood1")


@tile("props/voertuigen/ns_deur")
def ns_door():
    """Door leaf of an NS car."""
    return door_leaf(30, "bord_blauw")


@tile("props/voertuigen/randstadrail_kop")
def randstadrail_cab():
    """RandstadRail cab car, 11 x 2.625 x 3.5 m: red and grey, with a sloping nose and a
    pantograph at its rear end (the middle of the tram, the second car is turned round)."""
    return rail_car(21, 88, 29, "lak_zilver1", "lak_rood1", "lak_rood2", "lak_rood1", True, 22, 62, TRAM_PANTOGRAPH_TOP)


@tile("props/voertuigen/randstadrail_midden")
def randstadrail_middle():
    """RandstadRail middle car, its ends short of the next car's by the bellows."""
    return rail_car(21, 88, 29, "lak_zilver1", "lak_rood1", "lak_rood2", "lak_rood1", False, 30)


@tile("props/voertuigen/ns_kop")
def ns_cab():
    """NS cab car, 13 x 2.75 x 3.75 m: yellow with a blue band and doors."""
    return rail_car(22, 104, 30, "lak_geel1", "lak_geel1", "bord_blauw", "bord_blauw", True, 26)


@tile("props/voertuigen/ns_midden")
def ns_middle():
    """NS middle car, with the train's pantograph."""
    return rail_car(22, 104, 30, "lak_geel1", "lak_geel1", "bord_blauw", "bord_blauw", False, 18, 66, TRAIN_PANTOGRAPH_TOP)
