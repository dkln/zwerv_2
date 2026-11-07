"""The emergency services and the ministers' car: props/voertuigen/auto_politie,
auto_politie_busje (the ME van), auto_ambulance, auto_brandweer and auto_dienstauto, on the
bodies of the sedan, the van and the truck (props.py), and the OV-chipkaart reader at the
stops (props/ov/ov_incheckpaal).

The emergency vehicles have the Dutch striping on their sides, without lettering: diagonal
bands (police: blue and orange on white, ambulance: red and blue on yellow, fire service:
yellow and white on red), and a light bar of blue glass on the roof. The blue flashing and the siren are not in
the model: scripts/vehicles/vehicle.gd lights glowing blocks over the light bar
(`beacon_positions` of the vehicle script) while the siren is on. x across, y along with
the front at y=0, z up (as the bodies they are made of)."""
from common import tile
from palette import P
from vox import V
from .props import sedan_body, van_body, truck_body

# The light bars: [first, last] across, along and the height, in voxels of the body.
SEDAN_LIGHT_BAR = ((2, 11), (17, 18), 11)
VAN_LIGHT_BAR = ((2, 13), (8, 10), 17)
TRUCK_LIGHT_BAR = ((3, 14), (3, 5), 22)


def striping(model, along, up, colours, paint):
    """Diagonal bands of the two `colours` over the `paint` of both sides of the body, in the
    rows `up` from along[0] to along[1]: windows, handles and lamps stay as they are."""
    for across in (0, model.sx - 1):
        for along_index in range(along[0], along[1] + 1):
            for height in up:
                if model.get(across, along_index, height) != P[paint]:
                    continue
                band = (along_index + height) % 8
                if band < 3:
                    model.set(across, along_index, height, colours[0])
                elif 4 <= band < 7:
                    model.set(across, along_index, height, colours[1])


def light_bar(model, bar):
    """A light bar on the roof: blue glass with a white middle, on a dark foot."""
    (first, last), (front, back), height = bar
    middle = (first + last) / 2
    for across in range(first, last + 1):
        for along in range(front, back + 1):
            near_middle = abs(across - middle) < 1
            model.set(across, along, height, "bord_wit" if near_middle else "glas_blauw")
    for across in (first, last):
        model.set(across, front, height, "metaal_donker")


@tile("props/voertuigen/auto_politie")
def police_car():
    """Police car: the white sedan with blue and orange striping and a light bar."""
    model = sedan_body("lak_wit1", "lak_wit2")
    striping(model, (1, model.sy - 2), (3, 4, 5), ("bord_blauw", "bord_oranje"), "lak_wit1")
    model.clear(model.sx - 4, 23, 11, model.sx - 3, 24, 12)   # no aerial beside the light bar
    light_bar(model, SEDAN_LIGHT_BAR)
    return model


@tile("props/voertuigen/auto_dienstauto")
def ministers_car():
    """The car of a member of the cabinet: the sedan in black, without the sunroof."""
    model = sedan_body("bord_zwart", "auto_interieur")
    for across in range(5, 9):
        for along in range(15, 19):
            model.set(across, along, 10, "bord_zwart")
    return model


@tile("props/voertuigen/auto_politie_busje")
def riot_van():
    """ME van: the van in police white with striping, a light bar and
    grilles over the windscreen and the windows."""
    model = van_body("lak_wit1", "lak_wit2", 18)
    striping(model, (1, model.sy - 2), (4, 5, 6, 7), ("bord_blauw", "bord_oranje"), "lak_wit1")
    for across in range(1, model.sx - 1):
        for along in range(5, 9):
            for up in range(10, 16):
                if model.get(across, along, up) == P["glas2"] and (across + up) % 2 == 0:
                    model.set(across, along, up, "metaal_donker")
    for along in range(10, 17):
        for up in range(11, 15):
            for across in (0, model.sx - 1):
                if model.get(across, along, up) == P["glas2"] and along % 2 == 0:
                    model.set(across, along, up, "metaal_donker")
    light_bar(model, VAN_LIGHT_BAR)
    return model


@tile("props/voertuigen/auto_ambulance")
def ambulance():
    """Ambulance: the van in yellow with red and blue striping and a light bar."""
    model = van_body("bord_geel", "lak_geel2", 18)
    striping(model, (1, model.sy - 2), (4, 5, 6, 7), ("bord_rood", "bord_blauw"), "bord_geel")
    light_bar(model, VAN_LIGHT_BAR)
    return model


@tile("props/voertuigen/auto_brandweer")
def fire_engine():
    """Fire engine: the truck in red with a closed body of lockers behind the cab (roller
    shutters in steel), yellow and white striping, a ladder on the
    roof and a light bar on the cab."""
    model = truck_body("lak_rood1", "lak_rood2")
    paint = "lak_rood1"
    width, length = model.sx, model.sy
    bed_start, floor, roof = 16, 9, 19
    # the open bed and its load make way for a closed body
    model.clear(0, bed_start, floor + 1, width, length, model.sz)
    for along in range(bed_start, length):
        for across in range(width):
            for up in range(floor + 1, roof + 1):
                outside = across in (0, width - 1) or along in (bed_start, length - 1) or up == roof
                if outside:
                    model.set(across, along, up, paint)
    # roller shutters: three a side, ribbed steel in a red frame
    for first, last in ((18, 27), (30, 40), (43, 53)):
        for along in range(first, last + 1):
            for up in range(floor + 4, roof - 1):
                for across in (0, width - 1):
                    model.set(across, along, up, "rvs" if up % 2 else "metaal1")
    for across in range(2, width - 2):
        for up in range(floor + 3, roof - 1):
            model.set(across, length - 1, up, "rvs" if up % 2 else "metaal1")
    # the striping along the bottom of the body and the cab
    for along in range(1, length - 1):
        for up in (floor + 1, floor + 2):
            for across in (0, width - 1):
                if model.get(across, along, up) == P[paint]:
                    model.set(across, along, up, "bord_geel" if (along + up) % 8 < 4 else "bord_wit")
    for along in range(1, 11):
        for up in (5, 6):
            for across in (0, width - 1):
                if model.get(across, along, up) == P[paint]:
                    model.set(across, along, up, "bord_geel" if (along + up) % 8 < 4 else "bord_wit")
    # the ladder on the roof: two rails with rungs
    for along in range(bed_start + 1, length - 1):
        for across in (5, width - 6):
            model.set(across, along, roof + 1, "rvs")
        if along % 3 == 0:
            for across in range(6, width - 6):
                model.set(across, along, roof + 1, "metaal1")
    light_bar(model, TRUCK_LIGHT_BAR)
    return model


@tile("props/ov/ov_incheckpaal")
def ov_card_reader():
    """OV-chipkaart reader on a stop: a dark post of 1.25 m with a white head, its reader
    face (the front, y=0) black with a blue screen and a yellow card mark."""
    model = V(6, 6, 10)
    for along in range(2, 4):
        for across in range(2, 4):
            for up in range(0, 7):
                model.set(across, along, up, "metaal_donker")
    for along in range(0, 5):
        for across in range(1, 5):
            for up in range(7, 10):
                model.set(across, along, up, "bord_wit")
    for across in range(1, 5):
        model.set(across, 0, 8, "bord_zwart")
        model.set(across, 0, 7, "bord_zwart")
    model.set(2, 0, 9, "bord_blauw")
    model.set(3, 0, 9, "bord_blauw")
    model.set(1, 0, 8, "bord_geel")
    return model
