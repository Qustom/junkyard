#!/usr/bin/env python3
"""Preview composer for the re-dressed hub. Mirrors the vertex-map Wang paint that
hub_ground.gd will implement, then pastes props at the planned scene positions."""
import json
from PIL import Image

S = '/tmp/claude-1000/-mnt-c-source-junkyard/2a6a8766-65dd-4e89-beef-770613f88bc9/scratchpad'
GAME = '/mnt/c/source/junkyard/Game'

DIRT, ASPHALT, LITTER, SCRAP = 0, 1, 2, 3
CX_MIN, CX_MAX, CY_MIN, CY_MAX = -18, 17, -10, 9   # 36x20 cells = 1152x640 px

def h32(vx, vy):
    h = ((vx * 73856093) ^ (vy * 19349663)) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) & 0x7fffffff
    return h

def vertex_mat(vx, vy):
    if vy >= 16:                                        # street band, world y >= 192
        return ASPHALT
    if (vx <= 7 or vx >= 29 or vy <= 3) and vy <= 14:   # border walls (x<=-352, x>=352, y<=-224)
        return SCRAP
    if 9 <= vx <= 27 and 5 <= vy <= 7 and abs(vx - 18) > 4:  # north litter fringe, lane kept clean
        h = h32(vx, vy)
        if (vy == 7 and h % 2 == 0) or (vy < 7 and h % 4 != 0):
            return LITTER
    return DIRT

def load_sheet(prefix):
    meta = json.load(open(f'{S}/{prefix}_metadata.json'))
    sheet = Image.open(f'{S}/{prefix}_retoned.png').convert('RGBA')
    tiles = {}
    for t in meta['tileset_data']['tiles']:
        c = t['corners']
        idx = (8 if c['NW'] == 'upper' else 0) | (4 if c['NE'] == 'upper' else 0) \
            | (2 if c['SW'] == 'upper' else 0) | (1 if c['SE'] == 'upper' else 0)
        b = t['bounding_box']
        tiles[idx] = sheet.crop((b['x'], b['y'], b['x'] + b['width'], b['y'] + b['height']))
    return tiles

def cell_pick(vx, vy):
    """Return (sheet_key, wang_idx) for cell whose NW vertex is (vx,vy)."""
    m = [vertex_mat(vx, vy), vertex_mat(vx + 1, vy),
         vertex_mat(vx, vy + 1), vertex_mat(vx + 1, vy + 1)]  # NW NE SW SE
    if ASPHALT in m:
        return 't1', sum(b for b, mm in zip((8, 4, 2, 1), m) if mm == DIRT)
    if SCRAP in m:
        return 't3', sum(b for b, mm in zip((8, 4, 2, 1), m) if mm == SCRAP)
    if LITTER in m:
        return 't2', sum(b for b, mm in zip((8, 4, 2, 1), m) if mm == LITTER)
    return 't1', 15  # pure dirt (all-dirt tile is identical across sheets)

def paint_ground():
    sheets = {'t1': load_sheet('t1_asphalt_dirt'),
              't2': load_sheet('t2_dirt_litter'),
              't3': load_sheet('t3_dirt_scrap')}
    W, H = (CX_MAX - CX_MIN + 1) * 32, (CY_MAX - CY_MIN + 1) * 32
    img = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    for cy in range(CY_MIN, CY_MAX + 1):
        for cx in range(CX_MIN, CX_MAX + 1):
            key, idx = cell_pick(cx - CX_MIN, cy - CY_MIN)
            img.paste(sheets[key][idx], ((cx - CX_MIN) * 32, (cy - CY_MIN) * 32))
    return img

# (x, y, path, anchor) — anchor 'base' means (x,y) is bottom-center
NEW = f'{S}/objects_new'
OLD = f'{GAME}/art/hub/objects'
PROPS = [
    # structures
    (0,    -160, f'{NEW}/dive_gate.png',   'base'),
    (0,    -215, f'{OLD}/portal_glow.png', 'center'),
    (-220, -120, f'{NEW}/shack.png',       'base'),
    (-278, -142, f'{OLD}/workbench.png',   'base'),   # against shack west wall? no—west is wall; tucked left of door
    (-124, -138, f'{OLD}/sort_table.png',  'base'),
    # west line (big silhouettes against wall)
    (-282, -40,  f'{NEW}/truck_cab.png',   'base'),
    (-300,  40,  f'{OLD}/tire_stack.png',  'base'),
    (-310, 120,  f'{OLD}/oil_drums.png',   'base'),
    (-245, 175,  f'{NEW}/cable_spool.png', 'base'),
    # east line
    (272,  -100, f'{NEW}/car_on_blocks.png', 'base'),
    (318,  -30,  f'{NEW}/freezer.png',     'base'),
    (300,   50,  f'{OLD}/pallet_cans.png', 'base'),
    (286,  125,  f'{OLD}/bathtub.png',     'base'),
    (325,  180,  f'{OLD}/propane_tank.png','base'),
    (205,  185,  f'{OLD}/wheelbarrow.png', 'base'),
    # shack apron (life-sim pride spot)
    (-160, -95,  f'{OLD}/potted_plant.png','base'),
    (-120, -85,  f'{OLD}/dog_bowl.png',    'base'),
    (-135, -115, f'{OLD}/folding_chair.png','base'),
    (-105, -150, f'{OLD}/chalkboard.png',  'base'),
    # street edge
    (-140, 200,  f'{NEW}/signpost.png',    'base'),
    # south fence line along the wall collider (y=232)
    (-304, 245,  f'{NEW}/fence_strip.png', 'base'),
    (-152, 245,  f'{NEW}/fence_strip.png', 'base'),
    (0,    245,  f'{NEW}/fence_strip.png', 'base'),
    (152,  245,  f'{NEW}/fence_strip.png', 'base'),
    (304,  245,  f'{NEW}/fence_strip.png', 'base'),
]

def compose(out):
    ground = paint_ground()
    W, H = 1152, 648
    ox, oy = W // 2, H // 2
    canvas = Image.new('RGBA', (W, H), (12, 9, 8, 255))
    canvas.paste(ground, (ox + CX_MIN * 32, oy + CY_MIN * 32))
    items = list(PROPS)
    # player: north-facing, in-scene scale 0.45, sprite center at (0, 102)
    pl = Image.open(f'{GAME}/art/player/rotations/north.png').convert('RGBA')
    pl = pl.resize((int(pl.width * 0.45), int(pl.height * 0.45)), Image.NEAREST)
    items.append((0, 102 + pl.height // 2, '__player__', 'base'))
    items.sort(key=lambda t: t[1])
    for x, y, path, anchor in items:
        im = pl if path == '__player__' else Image.open(path).convert('RGBA')
        bb = im.getbbox()
        if anchor == 'base':
            pos = (ox + x - (bb[0] + bb[2]) // 2, oy + y - bb[3])
        else:
            pos = (ox + x - im.width // 2, oy + y - im.height // 2)
        canvas.alpha_composite(im, pos)
    canvas = canvas.resize((int(W * 1.5), int(H * 1.5)), Image.NEAREST)
    canvas.save(out)
    print('saved', out)

if __name__ == '__main__':
    compose(f'{S}/hub_after.png')
