"""The small motor vehicles of the traffic with 0.125 m voxels: props/voertuigen/
gehandicaptenauto (a 45 km/h microcar, a "brommobiel" like a Canta; also _blauw) and the farm
tractor (trekker, also _rood), and the wheels klein_wiel (the microcar, the scooter) and
tractor_wiel. The two-wheelers and their riders are in two_wheelers.py (finer voxels).

Like the cars they are drawn without their wheels, which scripts/vehicles/*.gd place and
turn: x across, y along with the front at y=0, z up; the hub positions are the *_HUB(S)
constants (along, up, in voxels), which the vehicle scripts turn into metres."""
from common import tile
from vox import V

MICROCAR_HUBS = ((3.5, 2.0), (16.5, 2.0))
# the tractor: small front wheels (auto_wiel) and the big rear ones (tractor_wiel)
TRACTOR_FRONT_HUB = (5.0, 3.0)
TRACTOR_REAR_HUB = (22.0, 5.0)


def microcar_body(paint, sill):
    """A brommobiel (a Canta): 2.5 x 1.13 x 1.5 m, a short bonnet, a tall cabin with a
    steep windscreen, flat at the back, on small wheels (klein_wiel at MICROCAR_HUBS)."""
    width, length = 9, 20
    model = V(width, length, 12)
    inside = "auto_interieur"
    for along in range(length):
        for across in range(width):
            if along in (0, length - 1) and across in (0, width - 1):
                continue
            for up in range(1, 6):
                model.set(across, along, up, sill if up == 1 else paint)
    # cabin: windscreen rising over y 3..5, roof up to the back
    for along in range(3, length - 1):
        top = {3: 7, 4: 8, 5: 9}.get(along, 10)
        for across in range(1, width - 1):
            for up in range(6, top + 1):
                side = across in (1, width - 2)
                pillar = along in (3, 10, length - 2) or along == 4 and side
                if up == top and along > 5:
                    colour = paint
                elif up == top or side or along == length - 2:
                    colour = paint if pillar else "glas2"
                else:
                    colour = inside
                model.set(across, along, up, colour)
    # wheel arches round the small wheels
    for wheel_along, wheel_up in MICROCAR_HUBS:
        for along in range(int(wheel_along) - 3, int(wheel_along) + 3):
            for up in range(0, 5):
                if ((along + 0.5 - wheel_along) ** 2 + (up + 0.5 - wheel_up) ** 2) ** 0.5 < 2.8:
                    for across in (0, width - 1):
                        model.set(across, along, up, 0)
    # front lamps and a little grille; at the back the lamps and the plate
    for across in (1, width - 2):
        model.set(across, 0, 4, "lamp_wit")
        model.set(across, length - 1, 4, "signaal_rood")
        model.set(across, length - 1, 5, "signaal_rood")
    for across in range(3, 6):
        model.set(across, 0, 3, "rooster")
        model.set(across, length - 1, 3, "bord_geel")
    for across in (0, width - 1):                                       # wing mirrors
        model.set(across, 4, 7, "metaal_donker")
    return model


@tile("props/voertuigen/gehandicaptenauto")
def microcar():
    """A silver brommobiel (microcar_body)."""
    return microcar_body("lak_zilver1", "lak_zilver2")


@tile("props/voertuigen/gehandicaptenauto_blauw")
def microcar_blue():
    """A blue brommobiel (microcar_body)."""
    return microcar_body("autolak1", "autolak2")


def tractor_body(paint, dark):
    """A Dutch farm tractor of 3.75 x 1.88 x 2.75 m: a long narrow bonnet with the grille and
    headlights, small front wheels (auto_wiel at TRACTOR_FRONT_HUB), a glass cab over the big
    rear wheels (tractor_wiel at TRACTOR_REAR_HUB; both placed and turned by
    scripts/vehicles/tractor.gd) with wide mudguards, an upright exhaust beside the
    bonnet, an orange beacon on the cab roof and the three-point linkage at the back. x
    across (15), y along (30, the front at y=0), z up (23)."""
    width, length = 15, 30
    model = V(width, length, 23)
    front_along = TRACTOR_FRONT_HUB[0]
    rear_along, rear_up = TRACTOR_REAR_HUB
    # chassis and gearbox under it all, the front axle across
    model.box(5, 1, 3, 10, 28, 6, "metaal_donker")
    model.box(3, int(front_along), 3, 12, int(front_along) + 1, 4, "metaal_donker")
    # bonnet with the grille in front and the headlights
    model.box(4, 0, 6, 11, 15, 10, paint)
    model.box(5, 0, 10, 10, 15, 11, paint)
    model.box(5, 0, 6, 10, 1, 10, "rooster")
    for across in (4, 10):
        model.set(across, 0, 8, "lamp_wit")
    model.box(5, 0, 2, 10, 2, 6, dark)                               # front weights
    # a mudguard over each small front wheel (auto_wiel, 2 voxels wide, in columns 2-3 and 11-12)
    for first_column in (2, 11):
        for along in range(int(front_along) - 3, int(front_along) + 3):
            for across in (first_column, first_column + 1):
                model.set(across, along, 6, dark)
    # the exhaust: an upright pipe beside the bonnet, dark at the top
    for up in range(10, 21):
        model.set(10, 12, up, "rvs" if up < 19 else "metaal_donker")
    # the cab: glass on all sides with painted corner posts, floor and roof
    cab_front, cab_back, floor, roof = 15, 27, 7, 20
    model.box(3, cab_front, floor - 1, 12, cab_back + 1, floor, dark)
    for along in range(cab_front, cab_back + 1):
        for across in range(3, 12):
            for up in range(floor, roof):
                side = across in (3, 11)
                end = along in (cab_front, cab_back)
                if not (side or end):
                    if up == floor:
                        model.set(across, along, up, "auto_interieur")   # seat and floor
                    continue
                corner = side and end
                low = up < floor + 3
                model.set(across, along, up, paint if corner or low else "glas2")
    model.box(2, cab_front - 1, roof, 13, cab_back + 2, roof + 1, paint)   # roof with an overhang
    model.box(7, 20, roof + 1, 9, 22, roof + 2, "stoplicht_oranje")        # the beacon
    model.box(6, 23, floor, 9, 25, floor + 3, "auto_interieur")            # the seat
    model.box(7, 18, floor + 3, 9, 19, floor + 5, "metaal_donker")         # the steering wheel
    # big mudguards over the rear wheels, with the tail lights at their back
    for first_column in (0, 12):
        for along in range(int(rear_along) - 6, int(rear_along) + 6):
            arch = abs(along + 0.5 - rear_along)
            up = 11 if arch < 4 else 10
            for across in range(first_column, first_column + 3):
                model.set(across, along, up, paint)
        model.set(first_column + 1, int(rear_along) + 5, 9, "signaal_rood")
    # three-point linkage and the slow-vehicle triangle
    model.box(5, 28, 3, 10, 30, 5, "metaal_donker")
    for across, up in ((7, 13), (6, 12), (7, 12), (8, 12)):
        model.set(across, cab_back + 1, up, "bord_oranje")
    return model


@tile("props/voertuigen/trekker")
def tractor():
    """A green tractor (tractor_body)."""
    return tractor_body("bord_groen", "bord_groen2")


@tile("props/voertuigen/trekker_rood")
def tractor_red():
    """A red tractor (tractor_body)."""
    return tractor_body("lak_rood1", "lak_rood2")


@tile("props/voertuigen/tractor_wiel")
def tractor_wheel():
    """The big rear wheel of a tractor: 1.25 m across, 0.38 m wide, a lugged tyre round a
    yellow rim (the wheel shader draws its own colours on the sides)."""
    model = disc_wheel(3, 10, 3.4)
    for along in range(10):
        for up in range(10):
            distance = ((along + 0.5 - 5) ** 2 + (up + 0.5 - 5) ** 2) ** 0.5
            # the lugs: every other voxel of the outer ring of the tread sticks out a little less
            if 4.3 < distance <= 5.4 and (along + up) % 2 and model.get(1, along, up):
                model.set(1, along, up, 0)
    return model


def disc_wheel(width, diameter, rim_from):
    """A wheel: a disc in the y-z plane, `width` voxels thick along the axle (x), a rubber
    tyre from `rim_from` voxels out round a steel rim with dark spokes."""
    model = V(width, diameter, diameter)
    middle = diameter / 2
    for along in range(diameter):
        for up in range(diameter):
            distance = ((along + 0.5 - middle) ** 2 + (up + 0.5 - middle) ** 2) ** 0.5
            if distance > middle + 0.4:
                continue
            if distance > rim_from:
                colour = "rubber"
            elif abs(along + 0.5 - middle) < 1 or abs(up + 0.5 - middle) < 1:
                colour = "metaal_donker"
            else:
                colour = "rvs"
            for across in range(width):
                model.set(across, along, up, colour)
    return model


@tile("props/voertuigen/klein_wiel")
def small_wheel():
    """Small wheel of 0.5 m across, 0.25 m wide (scooter, brommobiel)."""
    return disc_wheel(2, 4, 1.2)

