"""Ground tiles, extension 5: motorway junction ramps (Dutch "aansluiting").

An exit (afrit) and an on-ramp (toerit) on the right-hand side of a motorway
carriageway, each one design of AFRIT_LEN x 4 tiles cut into tiles, plus the single
ramp lane that continues from them. Dutch layout:

* exit: the hard shoulder ends and becomes the exit lane (uitvoegstrook), separated from
  the right lane by a block marking (blokmarkering); the exit lane then bends away; the
  gore (puntstuk) between the solid lines is hatched up to the nose, where a crash
  cushion (obstakelbeveiliger) stands at the start of the verge guardrail; then the
  hard shoulder starts again. The guardrail on the outside follows the ramp.
* on-ramp: the same, the other way round (the exit mirrored along the road): the ramp
  joins over a hatched gore, runs as acceleration lane (invoegstrook) beside the right
  lane with a block marking and ends in the hard shoulder.

PLACEMENT (tools/build_example_city.gd): tile (i, j) of ``grond/snelweg/afrit_<i>_<j>``
/ ``toerit_<i>_<j>`` goes to cell (x0 + i, z0 - j) with rotation "S" for a carriageway
whose traffic drives west (towards -x) with its hard shoulder in row z0 (north side):
j = 0 is the shoulder row, j = 1 the verge (``snelweg_berm_vangrail`` "E" outside the
design), j = 2 the ramp lane row, j = 3 the ramp's verge. The exit starts at the east end
(i = AFRIT_LEN - 1: shoulder becomes exit lane) and leaves at the west end in row j = 2,
continuing with ``snelweg_aansluiting`` "E" (and ``snelweg_berm_vangrail`` "E" in row
j = 3). The on-ramp starts at its east end in row j = 2 and ends at its west end in the
shoulder. For other directions rotate the whole design (and its cell offsets) together.

Voxel frame of a design: gx along the road (east), gv across it, 0 at the edge between
the right lane and the shoulder, growing away from the road (north = tile y).
"""
from common import T, ROAD, WALK, register, slopes
from vox import V
from ground import ASPHALT, GRASS, MARK, column, paint, BLOCK_DASH

AFRIT_LEN = 8        # tiles along the road
ROWS = 4             # tiles across: shoulder, verge, ramp lane, ramp verge
TAPER = 1            # tiles where the shoulder turns into the exit lane
PARALLEL = 2         # tiles of exit lane beside the right lane
DIVERGE = 4          # tiles over which the ramp moves out by RAMP_SHIFT
RAMP_SHIFT = 2 * T   # the ramp ends up two rows further out
PAVED = 38           # paved width of shoulder + verge strip (as snelweg_vluchtstrook + _berm_vangrail)
NOSE = PAVED + 6     # ramp offset where the gore ends (the nose)


def _ramp_offset(u):
    """Lateral offset (voxels) of the ramp at distance u (voxels) from the start of the exit."""
    u0 = (TAPER + PARALLEL) * T
    t = min(max((u - u0) / (DIVERGE * T), 0.0), 1.0)
    return RAMP_SHIFT * t * t * (3 - 2 * t)


def _rail(m, gx, gv, base, post):
    """Guardrail slice at (gx, gv) like ground.guardrail: rail at z base+3..4, a post every 16."""
    m.set(gx, gv, base + 3, "gegalvaniseerd")
    m.set(gx, gv, base + 4, "gegalvaniseerd")
    if post:
        for z in range(base, base + 5):
            m.set(gx, gv + 1, z, "metaal2")


def _exit_design():
    """The whole exit design (AFRIT_LEN * T by ROWS * T voxels), traffic towards -gx."""
    L = AFRIT_LEN * T
    m = V(L, ROWS * T, 12)
    nose_u = None
    for gx in range(L):
        u = L - 1 - gx                    # distance from the start of the exit
        c = _ramp_offset(u)
        gore = c > 0 and c < NOSE
        if c >= NOSE and nose_u is None:
            nose_u = u
        for gv in range(ROWS * T):
            ramp = c <= gv < c + PAVED
            main = gv < PAVED and (c >= NOSE or c == 0)
            if gore and gv < c + PAVED or ramp or main:
                column(m, gx, gv, ROAD, ASPHALT)
            else:
                column(m, gx, gv, WALK, GRASS)
        # markings
        taper = u < TAPER * T // 2
        for gv in (0, 1):
            if taper or c > 0:
                paint(m, gx, gv, MARK)                       # solid edge line of the right lane
        if not taper and c == 0:
            if (gx + BLOCK_DASH[2]) % BLOCK_DASH[1] < BLOCK_DASH[0]:
                for gv in (0, 1, 2):
                    paint(m, gx, gv, MARK)                   # block marking
        if c > 0:
            for k in (1, 2):
                paint(m, gx, int(c) + k, MARK)               # ramp's left line
        if not taper:
            for k in (29, 30):
                paint(m, gx, int(c) + k, MARK)               # ramp's right edge line
        if gore:
            for gv in range(3, int(c)):
                if (gx + gv) % 8 < 2:
                    paint(m, gx, gv, MARK)                   # hatched gore
        if (taper or c >= NOSE) and gx % 2 == 1:
            paint(m, gx, 3, "asfalt4")                       # rumble strip of the hard shoulder
        # guardrails: outside the ramp (follows it), and the verge again after the nose
        post = gx % 16 == 11
        _rail(m, gx, int(c) + PAVED, WALK, post)
        if c >= NOSE:
            _rail(m, gx, PAVED, WALK, post)
    # crash cushion in front of the verge guardrail at the nose: yellow/black striped block
    if nose_u is not None:
        gx_nose = L - 1 - nose_u
        for gx in range(gx_nose, min(gx_nose + 8, L)):
            for gv in range(PAVED - 1, PAVED + 3):
                for z in range(ROAD, ROAD + 5):
                    m.set(gx, gv, z, "bord_geel" if (gx - gx_nose) % 4 < 2 else "bord_zwart")
    return m


_cache = {}


def _design(kind):
    """The exit design, or the on-ramp design (the exit mirrored along the road); cached."""
    if kind not in _cache:
        m = _exit_design()
        _cache[kind] = m if kind == "afrit" else m.mirror_x()
    return _cache[kind]


def design_tile(kind, i, j):
    """Tile (i, j) of the exit (kind "afrit") or on-ramp ("toerit") design."""
    d = _design(kind)
    m = V(T, T, d.sz)
    for y in range(T):
        for x in range(T):
            for z in range(d.sz):
                c = d.get(i * T + x, j * T + y, z)
                if c:
                    m.set(x, y, z, c)
    return m


def ramp_lane():
    """Single ramp lane (toe-/afrit) between two solid edge lines (x=1..2 and 29..30);
    beside it on both sides the verge (snelweg_berm_vangrail facing it)."""
    m = V(T, T, 12)
    for y in range(T):
        for x in range(T):
            column(m, x, y, ROAD, ASPHALT)
        for x in (1, 2, 29, 30):
            paint(m, x, y, MARK)
    return m


for _kind in ("afrit", "toerit"):
    for _i in range(AFRIT_LEN):
        for _j in range(ROWS):
            register(f"grond/snelweg/{_kind}_{_i}_{_j}", (lambda k, i, j: lambda: design_tile(k, i, j))(_kind, _i, _j))

register("grond/snelweg/snelweg_aansluiting", ramp_lane)
slopes("grond/snelweg/snelweg_aansluiting", "steil", "brug", "brug_rand")
