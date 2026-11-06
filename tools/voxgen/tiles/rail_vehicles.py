"""The cars of the rail vehicles: props/voertuigen/randstadrail_* and ns_* (placed and moved
by scripts/vehicles/randstadrail.gd and ns_train.gd). x across, y along with the front
at y=0, z up. A cab car has a driver's cab at the front: a narrowing nose with a windscreen
that leans back, a sign above it, lamps and a bumper under it and a side window for the
driver; every car has bogies under it, a band of windows, doors on both sides and something
on its roof. The last car of a train is a cab car turned round, so that end looks the same.
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


def rail_car(width, length, height, body, lower, band, door, cab, roof_box):
    """A car: `body` above, `lower` below the windows, a `band` under them, `door` panels."""
    model = V(width, length, height)
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
    """RandstadRail cab car, 11 x 2.625 x 3.5 m: red and grey, with a sloping nose."""
    return rail_car(21, 88, 29, "lak_zilver1", "lak_rood1", "lak_rood2", "lak_rood1", True, 22)


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
    """NS middle car."""
    return rail_car(22, 104, 30, "lak_geel1", "lak_geel1", "bord_blauw", "bord_blauw", False, 18)
