"""Reading and writing Goxel (.gox) files, the tile format of Zwervr.

The format (Goxel src/formats/gox.c, version 2) is a list of PNG-like chunks after
the header ``b"GOX "`` + int32 version:

    4 bytes type, int32 length, <length> bytes data, int32 CRC (Goxel writes 0)

Chunks used here:
  IMG   dict; "box": the image box, a float[4][4] (column-major: columns 0..2 hold
        the half sizes on the diagonal, column 3 the centre). It is the model size
        of a tile: the importer measures voxel positions from its minimum corner.
  BL16  a 16 x 16 x 16 block of RGBA voxels as a 64 x 64 RGBA PNG; voxel (x, y, z)
        of the block is pixel x + 16 * y + 256 * z. Alpha < 127 counts as empty.
  MATE  dict: "name", "color" float[4], "metallic", "roughness", "emission" float[3].
  LAYR  int32 block count, per block: int32 BL16 index, x, y, z (voxel position of
        the block corner, multiples of 16), 0; then a dict: "name", "mat" float[4][4],
        "id", "base_id" (clone of another layer), "material" (MATE index), "mode",
        "visible" (1 byte), "box", "shape".
A dict is a list of (int32 key length, key, int32 value length, raw value bytes),
ended by a key length of 0 or the end of the chunk. Values are at most 255 bytes.

Coordinates are Goxel's: x = left->right, y = front->back, z = up, the same as the
V model (vox.py). write_gox puts the model with its x/y centre on Goxel's origin and
its bottom on z = 0, and stores the model size as the image box.

Materials: a voxel has only a colour. Its material in Godot comes from the colour
(assets/tiles/materialen.json, written by write_material_table in vox.py); a layer
whose name (or MATE name) is a material name forces that material for its voxels
(see addons/vox_tiles/importer/gox_parser.gd).
"""
import struct
import zlib

MAGIC = b"GOX "
VERSION = 2
BLOCK = 16
# Goxel counts a voxel with alpha below this as empty (formats/vox.c export)
ALPHA_MIN = 127

_IDENTITY = struct.pack("<16f", 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)


# ---------------------------------------------------------------- PNG

def _png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def png_rgba(width, height, pixels):
    """Encode RGBA bytes (width * height * 4, row by row) as a PNG (no filtering)."""
    stride = width * 4
    raw = b"".join(b"\x00" + pixels[y * stride:(y + 1) * stride] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" + _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + _png_chunk(b"IDAT", zlib.compress(raw, 9)) + _png_chunk(b"IEND", b""))


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def read_png_rgba(data):
    """Decode an 8-bit, non-interlaced PNG (RGBA, RGB, grey or grey+alpha) to
    (width, height, RGBA bytes). Enough for the blocks Goxel writes (stb_image_write)."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat = 8, b""
    width = height = depth = ctype = interlace = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
        pos += 12 + length
    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(ctype)
    if depth != 8 or channels is None or interlace:
        raise ValueError(f"unsupported PNG (depth {depth}, colour type {ctype}, interlace {interlace})")
    raw = zlib.decompress(idat)
    stride = width * channels
    out = bytearray(height * stride)
    prev = bytearray(stride)
    pos = 0
    for y in range(height):
        f = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        if f == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                up_left = prev[i - channels] if i >= channels else 0
                line[i] = (line[i] + _paeth(left, prev[i], up_left)) & 0xFF
        out[y * stride:(y + 1) * stride] = line
        prev = line
    if channels == 4:
        return width, height, bytes(out)
    rgba = bytearray(width * height * 4)
    for i in range(width * height):
        px = out[i * channels:(i + 1) * channels]
        if channels == 3:
            rgba[i * 4:i * 4 + 4] = bytes((px[0], px[1], px[2], 255))
        elif channels == 1:
            rgba[i * 4:i * 4 + 4] = bytes((px[0], px[0], px[0], 255))
        else:
            rgba[i * 4:i * 4 + 4] = bytes((px[0], px[0], px[0], px[1]))
    return width, height, bytes(rgba)


# ---------------------------------------------------------------- chunks

def _chunk(kind, data):
    return kind + struct.pack("<i", len(data)) + data + struct.pack("<i", 0)


def _dict(entries):
    out = b""
    for key, value in entries:
        k = key.encode()
        assert len(value) < 256, (key, len(value))
        out += struct.pack("<i", len(k)) + k + struct.pack("<i", len(value)) + value
    return out


def _read_dict(body, pos):
    out = {}
    while pos + 4 <= len(body):
        (n,) = struct.unpack("<i", body[pos:pos + 4])
        if n == 0:
            break
        key = body[pos + 4:pos + 4 + n].decode("utf-8", "replace")
        pos += 4 + n
        (m,) = struct.unpack("<i", body[pos:pos + 4])
        out[key] = body[pos + 4:pos + 4 + m]
        pos += 4 + m
    return out


def _box(lo, size):
    """Goxel box (float[4][4] bytes) of the voxel range [lo, lo + size)."""
    half = [s / 2 for s in size]
    centre = [lo[k] + half[k] for k in range(3)]
    return struct.pack("<16f", half[0], 0, 0, 0, 0, half[1], 0, 0, 0, 0, half[2], 0,
                       centre[0], centre[1], centre[2], 1)


def box_range(raw):
    """(minimum corner, size) in whole voxels of a Goxel box, or None for a null box."""
    m = struct.unpack("<16f", raw)
    if m[15] == 0:
        return None
    lo = [round(m[12 + k] - abs(m[k * 5])) for k in range(3)]
    hi = [round(m[12 + k] + abs(m[k * 5])) for k in range(3)]
    return lo, [hi[k] - lo[k] for k in range(3)]


# Goxel material settings that show a material roughly like Godot does
_MATE = {
    None: ((1, 1, 1, 1), 0.0, 1.0, (0, 0, 0)),
    "metal": ((1, 1, 1, 1), 1.0, 0.3, (0, 0, 0)),
    "panel": ((1, 1, 1, 1), 1.0, 0.1, (0, 0, 0)),
    "painted": ((1, 1, 1, 1), 0.3, 0.5, (0, 0, 0)),
    "glass": ((1, 1, 1, 0.5), 0.0, 0.1, (0, 0, 0)),
    "water": ((1, 1, 1, 0.6), 0.0, 0.1, (0, 0, 0)),
    "emit": ((1, 1, 1, 1), 0.0, 1.0, (1, 1, 1)),
}


def _mate(name, material):
    colour, metallic, rough, emission = _MATE.get(material, _MATE[None])
    return _chunk(b"MATE", _dict([
        ("name", name.encode()),
        ("color", struct.pack("<4f", *colour)),
        ("metallic", struct.pack("<f", metallic)),
        ("roughness", struct.pack("<f", rough)),
        ("emission", struct.pack("<3f", *emission)),
    ]))


# ---------------------------------------------------------------- writing

def write_layers(path, size, layers):
    """Write a .gox with the model size ``size`` (sx, sy, sz) and ``layers``: a list of
    (name, material, voxels) where voxels maps model (x, y, z) -> (r, g, b) and
    material is None (the colour decides) or a Godot material name, which becomes
    the layer name and its MATE. Model (x, y, z) is stored at Goxel position
    (x - sx // 2, y - sy // 2, z). Returns the number of voxels written."""
    sx, sy, sz = size
    ox, oy = sx // 2, sy // 2
    blocks, index = [], {}   # PNG bytes per BL16 chunk, PNG -> its index
    mates = [("model", None)]
    layer_chunks = []
    count = 0
    for lid, (name, material, voxels) in enumerate(layers, 1):
        if material is not None and (material, material) not in mates:
            mates.append((material, material))
        mate_index = mates.index((material, material)) if material is not None else 0
        per_block = {}
        for (x, y, z), rgb in voxels.items():
            gx, gy, gz = x - ox, y - oy, z
            b = (gx // BLOCK * BLOCK, gy // BLOCK * BLOCK, gz // BLOCK * BLOCK)
            data = per_block.get(b)
            if data is None:
                data = per_block[b] = bytearray(BLOCK ** 3 * 4)
            i = ((gx - b[0]) + BLOCK * (gy - b[1]) + BLOCK * BLOCK * (gz - b[2])) * 4
            data[i:i + 4] = bytes((rgb[0], rgb[1], rgb[2], 255))
            count += 1
        refs = b""
        for b in sorted(per_block, key=lambda p: (p[2], p[1], p[0])):
            png = png_rgba(64, 64, bytes(per_block[b]))
            if png not in index:
                index[png] = len(blocks)
                blocks.append(png)
            refs += struct.pack("<5i", index[png], b[0], b[1], b[2], 0)
        layer_chunks.append(_chunk(b"LAYR", struct.pack("<i", len(per_block)) + refs + _dict([
            ("name", name.encode()),
            ("mat", _IDENTITY),
            ("id", struct.pack("<i", lid)),
            ("base_id", struct.pack("<i", 0)),
            ("material", struct.pack("<i", mate_index)),
            ("mode", struct.pack("<i", 0)),
            ("visible", b"\x01"),
        ])))
    out = MAGIC + struct.pack("<i", VERSION)
    out += _chunk(b"IMG ", _dict([("box", _box((-ox, -oy, 0), size))]))
    out += b"".join(_chunk(b"BL16", png) for png in blocks)
    out += b"".join(_mate(name, material) for name, material in mates)
    out += b"".join(layer_chunks)
    with open(path, "wb") as fh:
        fh.write(out)
    return count


# ---------------------------------------------------------------- reading

class GoxModel:
    """A .gox read back: ``size`` (sx, sy, sz) and ``voxels``: model (x, y, z) ->
    ((r, g, b), forced material or None), merged over the visible layers like Goxel
    does (later layers on top). ``warnings`` lists what could not be read."""

    def __init__(self):
        self.size = (0, 0, 0)
        self.voxels = {}
        self.warnings = []


def read_gox(path, material_names=()):
    """Read a .gox (see the module docstring). ``material_names``: names that force a
    material when a layer (or its MATE) carries one; other layers force nothing."""
    data = open(path, "rb").read()
    if data[:4] != MAGIC:
        raise ValueError(f"{path}: not a Goxel file")
    (version,) = struct.unpack("<i", data[4:8])
    pos = 8
    blocks, mates, layers, box = [], [], [], None
    while pos + 8 <= len(data):
        kind = data[pos:pos + 4]
        (length,) = struct.unpack("<i", data[pos + 4:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"BL16":
            blocks.append(read_png_rgba(body)[2])
        elif kind == b"MATE":
            mates.append(_read_dict(body, 0).get("name", b"").decode("utf-8", "replace"))
        elif kind == b"IMG ":
            raw = _read_dict(body, 0).get("box")
            if raw is not None and len(raw) == 64:
                box = box_range(raw)
        elif kind == b"LAYR":
            (n,) = struct.unpack("<i", body[:4])
            refs = [struct.unpack("<5i", body[4 + k * 20:24 + k * 20])[:4] for k in range(n)]
            if version == 1:
                refs = [(i, x - 8, y - 8, z - 8) for i, x, y, z in refs]
            d = _read_dict(body, 4 + n * 20)
            layers.append((refs, d))
    out = GoxModel()

    def _int(d, key, default):
        return struct.unpack("<i", d[key])[0] if len(d.get(key, b"")) == 4 else default

    own, by_id = [], {}
    for refs, d in layers:
        vox = {}
        for i, bx, by, bz in refs:
            block = blocks[i]
            alpha = block[3::4]
            for k in (k for k in range(BLOCK ** 3) if alpha[k] >= ALPHA_MIN):
                vox[(bx + k % 16, by + k // 16 % 16, bz + k // 256)] = tuple(block[k * 4:k * 4 + 3])
        own.append(vox)
        if _int(d, "id", 0) and not _int(d, "base_id", 0):
            by_id[_int(d, "id", 0)] = vox
    merged = {}   # Goxel (x, y, z) -> (rgb, forced material)
    for (refs, d), vox in zip(layers, own):
        name = d.get("name", b"").decode("utf-8", "replace")
        mi = _int(d, "material", -1)
        mate = mates[mi] if 0 <= mi < len(mates) else ""
        forced = name if name in material_names else (mate if mate in material_names else None)
        if _int(d, "base_id", 0):
            vox = _clone(by_id.get(_int(d, "base_id", 0), {}), d.get("mat"))
        if "shape" in d:
            out.warnings.append(f"layer '{name}' is a shape layer; not supported, skipped")
            continue
        if d.get("visible", b"\x01")[:1] == b"\x00":
            continue
        for p, rgb in vox.items():
            merged[p] = (rgb, forced)
    if box is None:
        if not merged:
            return out
        lo = [min(p[k] for p in merged) for k in range(3)]
        hi = [max(p[k] for p in merged) + 1 for k in range(3)]
        box = (lo, [hi[k] - lo[k] for k in range(3)])
        out.warnings.append("no image box; using the bounds of the voxels")
    lo, size = box
    out.size = tuple(size)
    outside = 0
    for (x, y, z), v in merged.items():
        p = (x - lo[0], y - lo[1], z - lo[2])
        if all(0 <= p[k] < size[k] for k in range(3)):
            out.voxels[p] = v
        else:
            outside += 1
    if outside:
        out.warnings.append(f"{outside} voxels outside the image box, skipped")
    return out


def _clone(src, mat):
    """Voxels of a clone layer: its base layer moved by the layer matrix. Only whole
    voxel moves (and 90 degree turns) are exact; voxel centres are transformed."""
    if mat is None or len(mat) != 64:
        return dict(src)
    m = struct.unpack("<16f", mat)
    res = {}
    for (x, y, z), rgb in src.items():
        c = (x + 0.5, y + 0.5, z + 0.5)
        p = tuple(int((m[r] * c[0] + m[4 + r] * c[1] + m[8 + r] * c[2] + m[12 + r]) // 1) for r in range(3))
        res[p] = rgb
    return res
