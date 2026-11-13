"""The two-wheelers of the traffic, at half the usual voxel size: one voxel
here is 0.0625 m (FINE_VOXEL), so the riders get a real head (face, hair or a helmet with a
visor), arms down to the hands on the grips, legs to the pedals or footrests, and the bikes
thin tubes, a saddle, mudguards, a carrier and lamps:
props/voertuigen/fietser (also _rood), fatbike, brommer (a Tomos-like moped), scooter (also
_zwart), motorfiets, and the thin wheels fiets_wiel and brommer_wiel.

These tiles are imported with the import option voxel_size = FINE_VOXEL (their
<name>.gox.import, see FINE_TILES); the motorbike and the fatbike roll on the ordinary
auto_wiel, the scooter on klein_wiel (both 0.125 m voxels, small_vehicles.py).

Like the cars they are drawn without their wheels, which scripts/vehicles/*.gd place and
turn. The moped, the scooters and the motorbike are drawn without their riders too: those
are townspeople built in code (scripts/world/people/townsfolk_figure.gd, the size of the player
figures), put on by scripts/vehicles/two_wheeler.gd, which takes the seat, footrests and
grips of these tiles. The bicycles of the traffic are built in code as well
(scripts/vehicles/bicycle_parts.gd, with a turning fork and cranks); the fietser and fatbike
tiles here, with their riders, are no longer driven: x across (11 voxels, the frame in the middle column x = MIDDLE), y along with the
front at y=0, z up; the hub positions are the *_HUBS constants (along, up, in fine voxels),
which the vehicle scripts turn into metres."""
from common import tile
from vox import V

# metres per voxel of these tiles (the import option voxel_size of FINE_TILES)
FINE_VOXEL = 0.0625
FINE_TILES = ["fietser", "fietser_rood", "fatbike", "brommer", "scooter", "scooter_zwart",
              "motorfiets", "fiets_wiel", "brommer_wiel"]

WIDTH = 11
MIDDLE = 5
# materials (assets/tiles/materialen.json): frames, tanks, fairings and helmets in lacquered
# colours ("painted": lak_*, bord_*), chrome and steel "metal" (rvs, metaal*), tyres, saddles,
# seats, skin, hair and clothing matte ("opaque": rubber, fiets_zadel, auto_interieur, stof*,
# gordijn*, hout*), visors "glass" (glas2), lamps and reflectors "emit" (lamp_wit, signaal_rood)
SKIN = "gordijn1"
EYES = "rubber"
MATTE_BLACK = "auto_interieur"   # black clothing and seats (bord_zwart would be lacquered)

# wheel hubs (along, up) in fine voxels
BIKE_HUBS = ((5.0, 6.0), (23.0, 6.0))
MOPED_HUBS = ((5.0, 5.0), (23.0, 5.0))
SCOOTER_HUBS = ((4.0, 4.0), (24.0, 4.0))
MOTORBIKE_HUBS = ((6.0, 6.0), (28.0, 6.0))


def block(model, x0, x1, y0, y1, z0, z1, colour):
    """Fills the box from (x0, y0, z0) to (x1, y1, z1), both corners included."""
    model.box(x0, y0, z0, x1 + 1, y1 + 1, z1 + 1, colour)


def tube(model, start, end, colour, columns=(MIDDLE,)):
    """A tube one voxel thick from start to end ((along, up)) in each of these columns."""
    for across in columns:
        model.line((across + 0.5, start[0] + 0.5, start[1] + 0.5), (across + 0.5, end[0] + 0.5, end[1] + 0.5), colour)


def limb(model, start, end, colour, columns):
    """A limb two voxels thick (along and up) from start to end, in these columns."""
    for along_offset in (0, 1):
        for up_offset in (0, 1):
            tube(model, (start[0] + along_offset, start[1] + up_offset), (end[0] + along_offset, end[1] + up_offset),
                 colour, columns)


def arc(model, hub, radius, colour, columns=(MIDDLE,), from_up=1.0, thickness=0.9):
    """A mudguard: the part of a ring of `radius` round the hub ((along, up)) higher than
    from_up above it."""
    hub_along, hub_up = hub
    reach = int(radius + 2)
    for along in range(int(hub_along) - reach, int(hub_along) + reach + 1):
        for up in range(int(hub_up), int(hub_up) + reach + 1):
            offset_along, offset_up = along + 0.5 - hub_along, up + 0.5 - hub_up
            distance = (offset_along ** 2 + offset_up ** 2) ** 0.5
            if radius <= distance < radius + thickness and offset_up > from_up:
                for across in columns:
                    model.set(across, along, up, colour)


def handlebar(model, along, up, bar="rvs", grips="rubber", mirrors=False):
    """A handlebar across the whole width with grips at the ends (two voxels each); with
    `mirrors` a mirror on a stalk over each end."""
    for across in range(WIDTH):
        model.set(across, along, up, grips if across in (0, 1, WIDTH - 2, WIDTH - 1) else bar)
    if mirrors:
        for across in (1, WIDTH - 2):
            tube(model, (along, up + 1), (along + 1, up + 4), "metaal_donker", (across,))
            block(model, across, across, along, along + 1, up + 5, up + 6, "metaal_donker")


class Outfit:
    """What a rider wears: jacket (with a darker trim: collar, zip and cuffs), trousers,
    shoes, hair, and a helmet (None = bare head) that covers the face (`full_face`) or not."""

    def __init__(self, jacket, trim, trousers, shoes="rubber", hair="hout_donker2", helmet=None, full_face=False):
        self.jacket, self.trim, self.trousers, self.shoes = jacket, trim, trousers, shoes
        self.hair, self.helmet, self.full_face = hair, helmet, full_face


def rider(model, outfit, hip, knees, feet, shoulder, hands):
    """A rider on the middle of the model: hip, knees (left, right), feet (left, right),
    shoulder and hands are (along, up). The torso is 5 wide (x 3..7) and 3 deep from the
    hip up to the shoulder (leaning when the shoulder lies further forward), with a belt,
    a zip and a collar; the arms (x 2 and 8) run from the shoulders to the hands on the
    grips; the legs (x 3-4 and 6-7) over the knees to the feet in their shoes; the head (3
    wide, 3 deep, 4 high) on a neck, with eyes and hair, or inside a helmet."""
    hip_along, hip_up = hip
    shoulder_along, shoulder_up = shoulder
    # legs and shoes
    for columns, knee, foot in (((3, 4), knees[0], feet[0]), ((6, 7), knees[1], feet[1])):
        limb(model, hip, knee, outfit.trousers, columns)
        limb(model, knee, foot, outfit.trousers, columns)
        for across in columns:
            for along in range(foot[0] - 1, foot[0] + 3):
                model.set(across, along, foot[1], outfit.shoes)
    # torso, leaning from the hip to the shoulder
    rows = max(1, shoulder_up - hip_up)
    for up in range(hip_up, shoulder_up + 1):
        front = round(hip_along + (shoulder_along - hip_along) * (up - hip_up) / rows)
        for across in range(3, 8):
            for depth in range(3):
                colour = outfit.jacket
                if up == hip_up:
                    colour = outfit.trim          # the belt / the hem
                elif across == MIDDLE and depth == 0 and up < shoulder_up:
                    colour = outfit.trim          # the zip
                model.set(across, front + depth, up, colour)
    for across in (4, 5, 6):
        model.set(across, shoulder_along, shoulder_up, outfit.trim)   # the collar
    # arms from the shoulders to the hands, cuffs and hands
    for across in (2, 8):
        block(model, across, across, shoulder_along, shoulder_along + 2, shoulder_up - 2, shoulder_up, outfit.jacket)
        limb(model, (shoulder_along, shoulder_up - 2), hands, outfit.jacket, (across,))
        model.set(across, hands[0] + 1, hands[1], outfit.trim)
        block(model, across, across, hands[0], hands[0], hands[1], hands[1] + 1, SKIN)
    # neck and head
    head_along, neck_up = shoulder_along, shoulder_up + 1
    model.set(MIDDLE, head_along + 1, neck_up, SKIN)
    head_up = neck_up + 1
    block(model, 4, 6, head_along, head_along + 2, head_up, head_up + 3, SKIN)
    if outfit.helmet:
        # a helmet over the head: 5 wide, 5 deep, from the ears up, the face open below the
        # brim, or covered by a dark visor
        block(model, 3, 7, head_along - 1, head_along + 3, head_up + 1, head_up + 4, outfit.helmet)
        block(model, 3, 7, head_along + 1, head_along + 3, head_up, head_up, outfit.helmet)
        if outfit.full_face:
            block(model, 4, 6, head_along - 1, head_along - 1, head_up + 1, head_up + 2, "glas2")   # the visor
            block(model, 4, 6, head_along - 1, head_along - 1, head_up, head_up, outfit.helmet)
        else:
            block(model, 4, 6, head_along - 1, head_along - 1, head_up, head_up + 2, SKIN)
            model.set(4, head_along - 1, head_up + 2, EYES)
            model.set(6, head_along - 1, head_up + 2, EYES)
    else:
        model.set(4, head_along, head_up + 2, EYES)
        model.set(6, head_along, head_up + 2, EYES)
        block(model, 4, 6, head_along, head_along + 2, head_up + 4, head_up + 4, outfit.hair)   # top
        block(model, 4, 6, head_along + 2, head_along + 2, head_up + 1, head_up + 3, outfit.hair)   # back
        for across in (4, 6):
            block(model, across, across, head_along + 1, head_along + 2, head_up + 3, head_up + 3, outfit.hair)


def bicycle_with_rider(frame, outfit, step_through=False, fat=False):
    """A Dutch bicycle in the middle plane (thin tubes, a brown saddle, swept-back bars,
    mudguards, a chain guard, a steel carrier with its rear lamp, a front lamp) with its
    rider sitting up straight; `fat`: a fatbike (thick tubes, a battery on the down tube, a
    black saddle, no mudguards or carrier)."""
    model = V(WIDTH, 28, 30)
    (front_along, hub_up), (rear_along, _) = BIKE_HUBS
    front_hub = (int(front_along), int(hub_up))
    rear_hub = (int(rear_along), int(hub_up))
    bottom_bracket = (15, 4)
    seat_top = (19, 12)
    head_bottom, head_top = (8, 11), (8, 14)
    columns = (MIDDLE, MIDDLE + 1) if fat else (MIDDLE,)
    tube(model, front_hub, head_bottom, "rvs" if not fat else frame, columns)   # the fork
    tube(model, head_bottom, head_top, frame, columns)
    tube(model, rear_hub, bottom_bracket, frame, columns)   # chain stay
    tube(model, rear_hub, seat_top, frame, columns)          # seat stay
    tube(model, bottom_bracket, seat_top, frame, columns)    # seat tube
    if step_through:
        tube(model, bottom_bracket, (11, 6), frame, columns)
        tube(model, (11, 6), head_bottom, frame, columns)
    else:
        tube(model, bottom_bracket, head_bottom, frame, columns)
        tube(model, seat_top, head_top, frame, columns)
    if fat:
        limb(model, bottom_bracket, head_bottom, frame, columns)
        # the battery along the down tube
        for along, up in ((10, 9), (11, 8), (12, 7), (13, 6)):
            block(model, 4, 6, along, along + 1, up, up + 1, "metaal_donker")
        model.set(MIDDLE, 22, 11, "signaal_rood")   # the rear lamp under the saddle
    else:
        arc(model, front_hub, 6.6, frame)
        arc(model, rear_hub, 6.6, frame)
        # carrier over the rear wheel on two stays, the rear lamp at its end
        block(model, 3, 7, 21, 27, 14, 14, "rvs")
        tube(model, (27, 14), rear_hub, "rvs", (3, 7))
        model.set(MIDDLE, 27, 13, "signaal_rood")
        # chain guard on the right side
        block(model, 6, 6, 15, 23, 4, 6, frame)
    # saddle on its post, stem and handlebar, front lamp on the fork
    tube(model, seat_top, (seat_top[0], seat_top[1] + 1), "metaal3")
    block(model, 4, 6, 17, 21, 13, 13, "rubber" if fat else "fiets_zadel")
    model.set(MIDDLE, 21, 12, "rubber" if fat else "fiets_zadel")
    tube(model, head_top, (9, 16), "metaal3")
    handlebar(model, 10, 16)
    block(model, MIDDLE, MIDDLE, 6, 6, 10, 11, "lamp_wit")
    model.set(MIDDLE, 7, 10, "metaal_donker")
    # crank and pedals
    tube(model, bottom_bracket, (13, 2), "metaal_donker", (4,))
    tube(model, bottom_bracket, (17, 6), "metaal_donker", (6,))
    block(model, 2, 3, 12, 14, 2, 2, "rubber")
    block(model, 7, 8, 16, 18, 6, 6, "rubber")
    rider(model, outfit, hip=(19, 14), knees=((12, 15), (14, 13)), feet=((13, 3), (17, 7)),
          shoulder=(16, 22), hands=(10, 17))
    return model


@tile("props/voertuigen/fietser")
def cyclist():
    """A cyclist on a black Dutch bicycle, in a blue coat and grey-blue trousers."""
    return bicycle_with_rider("bord_zwart", Outfit("stof1", "gordijn3", "gordijn3", hair="hout_donker2"))


@tile("props/voertuigen/fietser_rood")
def cyclist_red():
    """A cyclist on a red step-through bicycle, in a red coat and black trousers, fair hair."""
    return bicycle_with_rider("lak_rood1", Outfit("stof2", "gordijn2", MATTE_BLACK, hair="herfst3"), step_through=True)


@tile("props/voertuigen/fatbike")
def fatbike():
    """A fatbike (electric, on fat tyres: auto_wiel) with a teenager in a black hoodie and jeans."""
    return bicycle_with_rider("bord_zwart", Outfit(MATTE_BLACK, "gordijn3", "stof1", shoes="stof3"), fat=True)


@tile("props/voertuigen/brommer")
def moped():
    """A classic Dutch moped (a Tomos): a red tank with a chrome stripe, a small engine with
    cooling fins, a long black seat, a chrome exhaust along the right side, chrome
    mudguards, a round headlight and mirrors (its rider: scripts/vehicles/moped.gd)."""
    model = V(WIDTH, 28, 30)
    paint = "lak_rood1"
    (front_along, hub_up), (rear_along, _) = MOPED_HUBS
    front_hub, rear_hub = (int(front_along), int(hub_up)), (int(rear_along), int(hub_up))
    tube(model, front_hub, (9, 15), "rvs", (3, 7))                    # the fork legs
    block(model, 3, 7, 9, 10, 15, 15, "metaal_donker")                # the fork crown
    block(model, 4, 6, 7, 8, 15, 17, "metaal_donker")                 # the headlight
    model.set(MIDDLE, 7, 16, "lamp_wit")
    tube(model, (9, 15), (10, 17), "metaal3")
    handlebar(model, 10, 18, mirrors=True)
    tube(model, (10, 14), (16, 7), paint)                             # the frame
    tube(model, (16, 7), rear_hub, paint, (3, 7))
    block(model, 3, 7, 10, 15, 11, 13, paint)                         # the tank
    block(model, 3, 7, 12, 13, 12, 12, "rvs")
    block(model, 3, 7, 13, 18, 2, 7, "metaal_donker")                 # the engine
    for up in range(6, 11):
        block(model, 4, 6, 12, 13, up, up, "rvs" if up % 2 else "metaal_donker")   # cylinder fins
    tube(model, (17, 3), (22, 5), "rvs", (8,))                        # the exhaust
    block(model, 8, 8, 22, 26, 5, 6, "rvs")
    block(model, 3, 7, 16, 25, 12, 13, MATTE_BLACK)                   # the seat
    tube(model, (25, 12), rear_hub, "rvs", (3, 7))                    # the rear shocks
    arc(model, front_hub, 5.6, "rvs", (4, 5, 6))
    arc(model, rear_hub, 5.6, "rvs", (4, 5, 6))
    block(model, 4, 6, 27, 27, 9, 10, "bord_geel")                    # the plate
    model.set(MIDDLE, 27, 12, "signaal_rood")
    block(model, 1, 2, 16, 17, 3, 3, "metaal_donker")                 # footrests
    block(model, 8, 9, 16, 17, 3, 3, "metaal_donker")
    return model


def scooter_body(paint):
    """A 45 km/h scooter on small wheels (klein_wiel): a leg shield and a floor at the
    front, a handlebar cover with the headlight and mirrors, a fat rear body over the
    engine with the seat on it, the exhaust under the right side (its rider:
    scripts/vehicles/scooter.gd)."""
    model = V(WIDTH, 28, 30)
    (front_along, hub_up), _ = SCOOTER_HUBS
    front_hub = (int(front_along), int(hub_up))
    block(model, 2, 8, 4, 6, 5, 14, paint)                            # the leg shield
    block(model, 3, 7, 4, 6, 15, 15, paint)
    arc(model, front_hub, 4.6, paint, (3, 4, 5, 6, 7))                # the front fender
    tube(model, (6, 14), (7, 16), "metaal_donker")                    # steering column
    block(model, 2, 8, 6, 9, 16, 18, paint)                           # handlebar cover
    block(model, 4, 6, 6, 6, 17, 17, "lamp_wit")
    block(model, 0, 1, 8, 8, 17, 17, "rubber")
    block(model, 9, 10, 8, 8, 17, 17, "rubber")
    for across in (1, 9):
        tube(model, (8, 18), (9, 21), "metaal_donker", (across,))
        block(model, across, across, 9, 10, 22, 23, "metaal_donker")
    block(model, 2, 8, 7, 15, 3, 4, paint)                            # the floor
    block(model, 3, 7, 8, 14, 5, 5, "metaal_donker")                  # the mat
    block(model, 2, 8, 15, 25, 3, 10, paint)                          # the rear body
    block(model, 3, 7, 26, 27, 5, 10, paint)
    block(model, 3, 7, 15, 25, 11, 12, MATTE_BLACK)                   # the seat
    block(model, 4, 6, 27, 27, 8, 9, "signaal_rood")
    block(model, 4, 6, 27, 27, 5, 6, "bord_geel")
    block(model, 8, 9, 20, 26, 2, 3, "rvs")                           # the exhaust
    return model


@tile("props/voertuigen/scooter")
def scooter():
    """A yellow scooter."""
    return scooter_body("lak_geel1")


@tile("props/voertuigen/scooter_zwart")
def scooter_black():
    """A black scooter."""
    return scooter_body("bord_zwart")


@tile("props/voertuigen/motorfiets")
def motorbike():
    """A naked motorbike on car-sized wheels (auto_wiel): a red tank with knee recesses, an
    engine with steel cooling fins and covers, a chrome exhaust and silencer, a short tail
    with the tail light and plate, four indicators, mirrors (its rider:
    scripts/vehicles/motorbike.gd)."""
    model = V(WIDTH, 34, 32)
    paint = "lak_rood1"
    (front_along, hub_up), (rear_along, _) = MOTORBIKE_HUBS
    front_hub, rear_hub = (int(front_along), int(hub_up)), (int(rear_along), int(hub_up))
    tube(model, front_hub, (10, 18), "rvs", (3, 7))                   # fork legs
    block(model, 3, 7, 10, 11, 18, 18, "metaal_donker")               # triple clamp
    block(model, 4, 6, 8, 9, 15, 17, "metaal_donker")                 # the headlight
    block(model, 4, 6, 8, 8, 16, 16, "lamp_wit")
    tube(model, (10, 18), (12, 20), "metaal_donker")
    handlebar(model, 12, 20, bar="metaal_donker", mirrors=True)
    model.set(1, 9, 16, "bord_oranje")                                # indicators
    model.set(9, 9, 16, "bord_oranje")
    model.set(2, 32, 14, "bord_oranje")
    model.set(8, 32, 14, "bord_oranje")
    arc(model, front_hub, 7.0, paint, (4, 5, 6), from_up=2.0)
    tube(model, (11, 16), (19, 8), paint)                             # frame
    tube(model, (19, 8), rear_hub, "metaal_donker", (3, 7))           # swing arm
    block(model, 3, 7, 12, 19, 13, 15, paint)                         # the tank
    block(model, 4, 6, 12, 19, 16, 16, paint)
    block(model, 3, 3, 17, 19, 13, 14, 0)                             # knee recesses
    block(model, 7, 7, 17, 19, 13, 14, 0)
    block(model, 3, 7, 14, 21, 4, 11, "metaal_donker")                # the engine
    for up in range(6, 13):
        block(model, 4, 6, 13, 15, up, up, "rvs" if up % 2 else "metaal_donker")   # cooling fins
    block(model, 2, 2, 17, 19, 5, 7, "rvs")                           # engine covers
    block(model, 8, 8, 17, 19, 5, 7, "rvs")
    tube(model, (20, 4), (27, 7), "rvs", (8,))                        # exhaust
    block(model, 8, 9, 27, 31, 8, 10, "rvs")                          # silencer
    block(model, 3, 7, 19, 27, 15, 16, MATTE_BLACK)                   # the seat
    block(model, 4, 6, 27, 32, 14, 16, paint)                         # the tail
    model.set(MIDDLE, 33, 15, "signaal_rood")
    block(model, 4, 6, 33, 33, 11, 12, "bord_geel")                   # the plate
    tube(model, (32, 14), (33, 12), "metaal_donker")
    tube(model, (27, 15), (26, 7), "rvs", (3, 7))                     # rear shocks
    block(model, 1, 2, 22, 23, 6, 6, "metaal_donker")                 # footpegs
    block(model, 8, 9, 22, 23, 6, 6, "metaal_donker")
    return model


def thin_wheel(diameter, rim_from):
    """A wheel one fine voxel thin: a disc in the y-z plane, a rubber tyre from `rim_from`
    voxels out round a steel rim (the wheel shader draws the spokes)."""
    model = V(1, diameter, diameter)
    middle = diameter / 2
    for along in range(diameter):
        for up in range(diameter):
            distance = ((along + 0.5 - middle) ** 2 + (up + 0.5 - middle) ** 2) ** 0.5
            if distance <= middle:
                model.set(0, along, up, "rubber" if distance > rim_from else "rvs")
    return model


@tile("props/voertuigen/fiets_wiel")
def bicycle_wheel():
    """Bicycle wheel of 0.75 m across, 6 cm thin (fietser; the fatbike rolls on auto_wiel)."""
    return thin_wheel(12, 4.9)


@tile("props/voertuigen/brommer_wiel")
def moped_wheel():
    """Moped wheel of 0.63 m across, 6 cm thin."""
    return thin_wheel(10, 3.8)
