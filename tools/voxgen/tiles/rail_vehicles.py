"""The cars of the rail vehicles: props/voertuigen/randstadrail_* and ns_* (placed and moved
by scripts/vehicles/randstadrail.gd and ns_train.gd). x across, y along with the front
at y=0, z up. A cab car has a sloping nose with a windscreen at the front; every car has
bogies under it, a band of windows, doors on both sides and something on its roof."""
from common import tile
from vox import V


def rail_car(width, length, height, body, lower, band, door, cab, roof_box):
    """A car: `body` above, `lower` below the windows, a `band` under them, `door` panels."""
    model = V(width, length, height)
    floor = 4
    window_low = floor + 8
    window_high = height - 7
    doors = (length // 4, 3 * length // 4)
    for along in range(length):
        for across in range(width):
            side = across in (0, width - 1)
            for up in range(floor, height - 1):
                if cab and along < 6:
                    # the nose narrows towards the front and slopes back above the windows
                    nose_cut = (6 - along) // 2
                    if across < nose_cut or across >= width - nose_cut:
                        continue
                    if up >= height - 1 - (6 - along):
                        continue
                nearest_door = min(doors, key=lambda place: abs(along - place))
                in_door = abs(along - nearest_door) <= 5
                if not side and along not in (0, length - 1):
                    colour = "auto_interieur"
                elif up < window_low - 2:
                    colour = lower
                elif up < window_low:
                    colour = band
                elif in_door and side:
                    # double doors with a window in each leaf, a seam between them
                    colour = "glas2" if along != nearest_door and window_low <= up < window_high else door
                elif window_low <= up < window_high and side:
                    colour = "metaal_donker" if along % 12 == 0 else "glas2"
                else:
                    colour = body
                model.set(across, along, up, colour)
    # the roof, with a box of equipment and a darker edge
    for along in range(6 if cab else 0, length):
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
        # windscreen, headlights, a coupling and a dark sign above the windscreen
        for across in range(4, width - 4):
            for up in range(window_low, window_high):
                model.set(across, 3, up, "glas2")
            for up in (floor, floor + 1):
                model.set(across, 3, up, "metaal_donker")
        for across in (4, 5, width - 6, width - 5):
            model.set(across, 3, window_low - 3, "lamp_wit")
        for across in range(7, width - 7):
            model.set(across, 3, window_high, "bord_zwart")
    return model


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
