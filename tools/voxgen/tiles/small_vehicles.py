"""The small road users of the traffic: props/voertuigen/fietser (a cyclist), fatbike,
brommer (a Tomos-like moped), scooter, motorfiets and gehandicaptenauto (a 45 km/h microcar,
a "brommobiel" like a Canta), and their wheels (fiets_wiel, brommer_wiel, klein_wiel; the
motorbike and the fatbike roll on auto_wiel).

The two-wheelers come with their rider: a simple voxel figure (legs, a torso, arms to the
handlebar, a head with hair or a helmet). Like the cars they are drawn without their wheels,
which scripts/vehicles/*.gd place and turn: x across (5 voxels, the frame in the middle
column x=2), y along with the front at y=0, z up; the hub positions are the *_HUBS constants
(along, up, in voxels), which the vehicle scripts turn into metres."""
from common import tile
from vox import V

SKIN = "gordijn1"
HAIR = "hout_donker2"
SHOE = "bord_zwart"
# the middle column of a two-wheeler
MIDDLE = 2

# wheel hubs (along, up) in voxels of the bodies below
BIKE_HUBS = ((3.0, 3.0), (12.0, 3.0))
MOPED_HUBS = ((2.5, 2.5), (11.5, 2.5))
SCOOTER_HUBS = ((2.0, 2.0), (12.0, 2.0))
MOTORBIKE_HUBS = ((3.0, 3.0), (14.0, 3.0))
MICROCAR_HUBS = ((3.5, 2.0), (16.5, 2.0))
# the tractor: small front wheels (auto_wiel) and the big rear ones (tractor_wiel)
TRACTOR_FRONT_HUB = (5.0, 3.0)
TRACTOR_REAR_HUB = (22.0, 5.0)


def segment(model, start, end, colour, across=MIDDLE):
    """A line of voxels in the plane x=`across` from start to end ((along, up) in voxels)."""
    model.line((across + 0.5, start[0] + 0.5, start[1] + 0.5), (across + 0.5, end[0] + 0.5, end[1] + 0.5), colour)


def rider(model, hip, knee, foot, shoulder, hand, jacket, trousers, helmet=None, other_knee=None, other_foot=None):
    """A rider: legs (x 1 and 3) from the hip over the knee to the foot (the other leg may
    differ: a pedal stroke), a torso three wide and two deep from the hip up to the
    shoulders (leaning when the shoulder lies further forward), arms to the hands on the
    handlebar and a head with hair, or a helmet of that colour. Points are (along, up)."""
    legs = ((1, knee, foot), (3, other_knee or knee, other_foot or foot))
    for across, leg_knee, leg_foot in legs:
        segment(model, hip, leg_knee, trousers, across)
        segment(model, leg_knee, leg_foot, trousers, across)
        model.set(across, leg_foot[0], leg_foot[1], SHOE)
        model.set(across, leg_foot[0] - 1, leg_foot[1], SHOE)
    rise = max(1, shoulder[1] - hip[1])
    for up in range(hip[1], shoulder[1] + 1):
        along = round(hip[0] + (shoulder[0] - hip[0]) * (up - hip[1]) / rise)
        for across in range(1, 4):
            for depth in (0, 1):
                model.set(across, along + depth, up, jacket)
    for across in (1, 3):
        segment(model, (shoulder[0], shoulder[1] - 1), hand, jacket, across)
        model.set(across, hand[0], hand[1], SKIN)
    head_along, head_up = shoulder[0], shoulder[1] + 1
    if helmet:
        for across in range(1, 4):
            for along in (head_along, head_along + 1):
                for up in (head_up, head_up + 1):
                    model.set(across, along, up, helmet)
            model.set(across, head_along, head_up + 2, helmet)
            model.set(across, head_along + 1, head_up + 2, helmet)
        model.set(MIDDLE, head_along, head_up, SKIN)
        model.set(MIDDLE, head_along, head_up + 1, "metaal_donker")   # the visor
    else:
        for along in (head_along, head_along + 1):
            for up in (head_up, head_up + 1):
                model.set(MIDDLE, along, up, SKIN)
            model.set(MIDDLE, along, head_up + 2, HAIR)
        model.set(MIDDLE, head_along + 1, head_up + 1, HAIR)


def handlebar(model, along, up, bar="rvs", grips="rubber"):
    """A handlebar across the whole width, with grips at the ends."""
    for across in range(5):
        model.set(across, along, up, grips if across in (0, 4) else bar)


def bicycle_with_rider(frame, jacket, trousers, step_through=False, fat=False):
    """A Dutch bicycle in the middle plane with its rider sitting up straight; `fat`: a
    fatbike (a thick frame with a battery on the down tube, a low seat, no carrier)."""
    model = V(5, 15, 15)
    (front_hub, hub_up), (rear_hub, _) = BIKE_HUBS
    front = (int(front_hub), int(hub_up))
    rear = (int(rear_hub), int(hub_up))
    bottom_bracket = (8, 2)
    head_bottom, head_top = (4, 6), (4, 7)
    seat_top = (10, 6)
    segment(model, front, head_bottom, "rvs")                 # the fork
    segment(model, head_bottom, head_top, frame)
    segment(model, rear, bottom_bracket, frame)               # chain stay
    segment(model, rear, seat_top, frame)                     # seat stay
    segment(model, bottom_bracket, seat_top, frame)           # seat tube
    if step_through:
        segment(model, bottom_bracket, (6, 3), frame)
        segment(model, (6, 3), head_bottom, frame)
    else:
        segment(model, bottom_bracket, head_bottom, frame)
        segment(model, seat_top, head_top, frame)
    if fat:
        # the battery on the down tube, the frame thicker there
        for along in range(5, 8):
            for up in range(3, 5):
                model.set(MIDDLE, along, up, "metaal_donker")
        model.set(1, 6, 4, frame)
        model.set(3, 6, 4, frame)
    # mudguards over the wheels (none on a fatbike) and the carrier with its reflector
    if not fat:
        for along in range(1, 5):
            model.set(MIDDLE, along, 6, frame)
        for along in range(10, 15):
            model.set(MIDDLE, along, 6, frame)
        for along in range(11, 15):
            for across in (1, 2, 3):
                model.set(across, along, 7, "rvs")
        model.set(MIDDLE, 14, 6, "signaal_rood")              # the rear lamp
    else:
        model.set(MIDDLE, 12, 6, "signaal_rood")
    # saddle, stem and handlebar, front lamp
    for along in range(9, 12):
        model.set(MIDDLE, along, 7, "fiets_zadel" if not fat else "bord_zwart")
    model.set(MIDDLE, 4, 8, "metaal3")
    handlebar(model, 5, 8)
    model.set(MIDDLE, 3, 6, "lamp_wit")
    # crank and pedals
    model.set(1, 7, 2, "metaal_donker")
    model.set(3, 9, 1, "metaal_donker")
    rider(model, hip=(10, 8), knee=(7, 7), foot=(7, 2), other_knee=(8, 6), other_foot=(9, 1),
          shoulder=(8, 11), hand=(5, 8), jacket=jacket, trousers=trousers)
    return model


@tile("props/voertuigen/fietser")
def cyclist():
    """A cyclist on a black Dutch bicycle, in a blue coat and jeans."""
    return bicycle_with_rider("fiets_zwart", "stof1", "gordijn3")


@tile("props/voertuigen/fietser_rood")
def cyclist_red():
    """A cyclist on a red step-through bicycle, in a red coat and dark trousers."""
    return bicycle_with_rider("fiets_rood", "stof2", "bord_zwart", step_through=True)


@tile("props/voertuigen/fatbike")
def fatbike():
    """A fatbike (electric, on fat tyres: auto_wiel) with a teenager in a black hoodie."""
    return bicycle_with_rider("metaal_donker", "bord_zwart", "stof1", fat=True)


@tile("props/voertuigen/brommer")
def moped():
    """A classic Dutch moped (a Tomos): a red tank over a small engine, a long black seat,
    an exhaust along the right side, chrome mudguards; the rider in a white helmet."""
    model = V(5, 14, 15)
    paint = "lak_rood1"
    (front_hub, hub_up), (rear_hub, _) = MOPED_HUBS
    segment(model, (int(front_hub), int(hub_up)), (4, 7), "rvs", 1)     # the fork legs
    segment(model, (int(front_hub), int(hub_up)), (4, 7), "rvs", 3)
    segment(model, (4, 7), (8, 4), paint)                              # the frame
    segment(model, (8, 4), (int(rear_hub), int(hub_up) + 1), paint)
    for along in range(6, 9):                                          # the engine
        for up in range(1, 4):
            for across in range(1, 4):
                model.set(across, along, up, "metaal_donker")
    segment(model, (8, 2), (13, 3), "rvs", 3)                          # the exhaust
    for along in range(4, 8):                                          # the tank
        for across in range(1, 4):
            model.set(across, along, 6, paint)
            model.set(across, along, 5, paint)
    for along in range(8, 13):                                         # the seat
        for across in range(1, 4):
            model.set(across, along, 6, "bord_zwart")
    for along in range(0, 4):                                          # mudguards
        model.set(MIDDLE, along, 5, "rvs")
    for along in range(10, 14):
        model.set(MIDDLE, along, 5, "rvs")
    model.set(MIDDLE, 13, 6, "signaal_rood")
    model.set(MIDDLE, 13, 4, "bord_geel")                              # the plate
    model.set(MIDDLE, 3, 8, "lamp_wit")
    model.set(MIDDLE, 4, 8, "metaal_donker")
    handlebar(model, 4, 9)
    rider(model, hip=(10, 7), knee=(7, 7), foot=(8, 3), shoulder=(9, 10), hand=(4, 9),
          jacket="stof1", trousers="bord_zwart", helmet="bord_wit")
    return model


def scooter_body(paint, helmet, jacket):
    """A 45 km/h scooter on small wheels (klein_wiel): a leg shield and a floor at the
    front, a fat body over the engine at the back with the seat on it; its rider."""
    model = V(5, 14, 15)
    for along in range(2, 5):                                          # the leg shield
        for up in range(2, 8):
            for across in range(1, 4):
                if along == 2 or up <= 3:
                    model.set(across, along, up, paint)
    for along in range(4, 9):                                          # the floor
        for across in range(1, 4):
            model.set(across, along, 2, paint)
    for along in range(8, 14):                                         # the rear body
        for up in range(2, 6):
            for across in range(1, 4):
                if (along, up) in ((13, 2), (8, 5)):
                    continue
                model.set(across, along, up, paint)
    for along in range(8, 13):                                         # the seat
        for across in range(1, 4):
            model.set(across, along, 6, "bord_zwart")
    for along in range(0, 3):                                          # front mudguard
        model.set(MIDDLE, along, 4, paint)
    model.set(MIDDLE, 3, 8, "metaal_donker")                           # the steering column
    model.set(MIDDLE, 2, 8, "lamp_wit")
    handlebar(model, 3, 9, bar=paint)
    model.set(MIDDLE, 13, 5, "signaal_rood")
    model.set(MIDDLE, 13, 3, "bord_geel")
    model.set(3, 10, 1, "rvs")                                         # the exhaust
    model.set(3, 11, 1, "rvs")
    rider(model, hip=(10, 7), knee=(6, 6), foot=(6, 3), shoulder=(9, 10), hand=(4, 9),
          jacket=jacket, trousers="stof1", helmet=helmet)
    return model


@tile("props/voertuigen/scooter")
def scooter():
    """A mint-green scooter with a rider in a black helmet."""
    return scooter_body("fiets_mint", "bord_zwart", "stof3")


@tile("props/voertuigen/scooter_zwart")
def scooter_black():
    """A black scooter with a rider in a white helmet."""
    return scooter_body("bord_zwart", "bord_wit", "stof2")


@tile("props/voertuigen/motorfiets")
def motorbike():
    """A naked motorbike on car-sized wheels (auto_wiel): a black tank, an engine with
    steel fins, a high exhaust, a short tail; the rider leans forward in black leather and a
    red full-face helmet."""
    model = V(5, 17, 16)
    paint = "lak_rood1"
    (front_hub, hub_up), (rear_hub, _) = MOTORBIKE_HUBS
    for across in (1, 3):
        segment(model, (int(front_hub), int(hub_up)), (5, 8), "rvs", across)   # fork legs
    segment(model, (5, 8), (9, 5), paint)                               # frame
    segment(model, (9, 5), (int(rear_hub), int(hub_up)), "metaal_donker")   # swing arm
    for along in range(7, 11):                                          # the engine
        for up in range(2, 6):
            for across in range(1, 4):
                model.set(across, along, up, "rvs" if up % 2 and along in (8, 9) else "metaal_donker")
    segment(model, (10, 3), (15, 5), "rvs", 3)                          # the exhaust
    for along in range(6, 10):                                          # the tank
        for across in range(1, 4):
            for up in (6, 7):
                model.set(across, along, up, paint)
    for along in range(10, 14):                                         # seat and tail
        for across in range(1, 4):
            model.set(across, along, 7, "bord_zwart")
    for along in range(14, 17):
        model.set(MIDDLE, along, 7, paint)
        model.set(1, along, 7, paint)
        model.set(3, along, 7, paint)
    model.set(MIDDLE, 16, 6, "signaal_rood")
    model.set(MIDDLE, 16, 5, "bord_geel")
    for along in range(1, 5):                                           # front mudguard
        model.set(MIDDLE, along, 6, paint)
    model.set(MIDDLE, 4, 9, "lamp_wit")
    model.set(MIDDLE, 5, 9, "metaal_donker")
    handlebar(model, 6, 10, bar="metaal_donker")
    model.set(0, 4, 9, "bord_oranje")                                   # indicators
    model.set(4, 4, 9, "bord_oranje")
    model.set(0, 16, 7, "bord_oranje")
    model.set(4, 16, 7, "bord_oranje")
    rider(model, hip=(12, 8), knee=(8, 7), foot=(10, 4), shoulder=(9, 12), hand=(6, 10),
          jacket="bord_zwart", trousers="bord_zwart", helmet="bord_rood")
    return model


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


@tile("props/voertuigen/fiets_wiel")
def bicycle_wheel():
    """Bicycle wheel of 0.75 m across, one voxel thin (fietser, fatbike: auto_wiel)."""
    return disc_wheel(1, 6, 2.3)


@tile("props/voertuigen/brommer_wiel")
def moped_wheel():
    """Moped wheel of 0.63 m across, one voxel thin."""
    return disc_wheel(1, 5, 1.6)


@tile("props/voertuigen/klein_wiel")
def small_wheel():
    """Small wheel of 0.5 m across, 0.25 m wide (scooter, brommobiel)."""
    return disc_wheel(2, 4, 1.2)

