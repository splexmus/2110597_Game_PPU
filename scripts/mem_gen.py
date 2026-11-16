#!/usr/bin/env python3
"""Rebuild compact RGB222 tile/sprite/font ROMs; never emit a framebuffer."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'data'
FONT = {
'A':['01110','10001','10001','11111','10001','10001','10001'],
'B':['11110','10001','10001','11110','10001','10001','11110'],
'C':['01111','10000','10000','10000','10000','10000','01111'],
'D':['11110','10001','10001','10001','10001','10001','11110'],
'E':['11111','10000','10000','11110','10000','10000','11111'],
'F':['11111','10000','10000','11110','10000','10000','10000'],
'G':['01111','10000','10000','10111','10001','10001','01111'],
'H':['10001','10001','10001','11111','10001','10001','10001'],
'I':['111','010','010','010','010','010','111'],
'J':['00111','00010','00010','00010','10010','10010','01100'],
'K':['10001','10010','10100','11000','10100','10010','10001'],
'L':['10000','10000','10000','10000','10000','10000','11111'],
'M':['10001','11011','10101','10101','10001','10001','10001'],
'N':['10001','11001','10101','10011','10001','10001','10001'],
'O':['01110','10001','10001','10001','10001','10001','01110'],
'P':['11110','10001','10001','11110','10000','10000','10000'],
'Q':['01110','10001','10001','10001','10101','10010','01101'],
'R':['11110','10001','10001','11110','10100','10010','10001'],
'S':['01111','10000','10000','01110','00001','00001','11110'],
'T':['11111','00100','00100','00100','00100','00100','00100'],
'U':['10001','10001','10001','10001','10001','10001','01110'],
'V':['10001','10001','10001','10001','10001','01010','00100'],
'W':['10001','10001','10001','10101','10101','10101','01010'],
'X':['10001','10001','01010','00100','01010','10001','10001'],
'Y':['10001','10001','01010','00100','00100','00100','00100'],
'Z':['11111','00001','00010','00100','01000','10000','11111'],
'0':['01110','10001','10011','10101','11001','10001','01110'],
'1':['00100','01100','00100','00100','00100','00100','01110'],
'2':['01110','10001','00001','00010','00100','01000','11111'],
'3':['11110','00001','00001','01110','00001','00001','11110'],
'4':['00010','00110','01010','10010','11111','00010','00010'],
'5':['11111','10000','10000','11110','00001','00001','11110'],
'6':['01110','10000','10000','11110','10001','10001','01110'],
'7':['11111','00001','00010','00100','01000','01000','01000'],
'8':['01110','10001','10001','01110','10001','10001','01110'],
'9':['01110','10001','10001','01111','00001','00001','01110'],
'/':['00001','00001','00010','00100','01000','10000','10000'],
':':['00000','00100','00100','00000','00100','00100','00000'],
'>':['10000','01000','00100','00010','00100','01000','10000'],
'-':['00000','00000','00000','11111','00000','00000','00000'],
}


def rgb222(pixel):
    r, g, b = (min(3, (c + 42) // 85) for c in pixel[:3])
    return (r << 4) | (g << 2) | b


def crop(im, box, size, opaque=False):
    assert 0 <= box[0] < box[2] <= im.width and 0 <= box[1] < box[3] <= im.height
    part = im.crop(box).resize(size, Image.Resampling.NEAREST)
    if opaque:
        base = Image.new('RGBA', size, (32, 28, 56, 255))
        base.alpha_composite(part)
        part = ImageEnhance.Brightness(base).enhance(1.5)
    return part


def build():
    bg = Image.open(OUT / 'bg/Medieval_tiles_free2.png').convert('RGBA')
    props = Image.open(OUT / 'sprite_rom/Medieval_props_free.png').convert('RGBA')
    boxes = [(64,32,96,64), (160,432,192,464), (96,608,128,640),
             (16,400,48,432), (400,416,432,448), (456,16,488,48),
             (320,592,352,624), (640,64,672,96)]
    tiles = [crop(bg, box, (16,16), True) for box in boxes]
    # Alternate palettes keep all five rooms visually distinct while sharing art.
    for tile in tiles[:]:
        variant = tile.copy()
        variant.putdata([(b, min(255,g+30), r//2, a) for r,g,b,a in (tile.getpixel((x,y)) for y in range(tile.height) for x in range(tile.width))])
        tiles.append(variant)
    sprites = []
    for kind in range(6):
        im = Image.new('RGBA', (16,24)); d = ImageDraw.Draw(im)
        if kind == 1:  # Slime.
            d.ellipse((1,12,14,22), fill='#55aa55', outline='#005500')
            d.rectangle((4,13,9,14), fill='#aaffaa')
            d.point((5,17), fill='black'); d.point((11,17), fill='black')
        elif kind == 3:  # Wraith.
            d.polygon([(8,2),(13,7),(14,23),(10,20),(7,23),(4,20),(1,23),(3,7)], fill='#aa55ff')
            d.rectangle((5,7,10,11), fill='#000055')
            d.point((6,8), fill='#55ffff'); d.point((9,8), fill='#55ffff')
        else:
            armor = ['#aaaaff','#ffffff','#ffffaa','#aaaaaa','#aa5555','#aa00aa'][kind]
            d.rectangle((4,4,11,10), fill=armor)
            d.rectangle((3,11,12,18), fill=armor)
            d.rectangle((4,19,6,22), fill='#5555aa'); d.rectangle((9,19,11,22), fill='#5555aa')
            d.rectangle((4,7,11,8), fill='#000055')
            d.point((6,7), fill='#ffff55'); d.point((10,7), fill='#ffff55')
            d.line((14,5,14,19), fill='#ffffff'); d.line((12,16,15,16), fill='#ffaa00')
            d.rectangle((0,12,3,18), fill='#5555ff', outline='#ffff55')
            if kind == 0: d.rectangle((7,1,9,3), fill='#ff5555')
            if kind == 2:
                d.rectangle((5,12,10,17), fill='#555555')
                for y in (12,14,16): d.line((5,y,10,y), fill='#ffffaa')
            if kind == 5:
                d.polygon([(3,4),(2,0),(6,3),(9,3),(13,0),(12,5)], fill='#ffff55')
                d.rectangle((5,9,10,10), fill='#ff5555')
        sprites.append(im)
    sprites += [crop(props,(68,28,116,86),(16,24)),
                crop(props,(329,65,354,87),(16,24)),
                crop(props,(431,117,459,145),(16,24)),
                crop(props,(443,58,470,88),(16,24))]
    tile_words = [rgb222(p) for im in tiles for p in (im.getpixel((x,y)) for y in range(im.height) for x in range(im.width))]
    sprite_words = [(0x40 if p[3] >= 128 else 0) | rgb222(p) for im in sprites for p in (im.getpixel((x,y)) for y in range(im.height) for x in range(im.width))]
    maps = []
    for room in range(5):
        wall = [1,4,9,12,7][room]; floor = [2,6,10,14,6][room]
        for row in range(5):
            for col in range(10):
                tile = wall if row < 4 else floor
                if col in (0,9): tile = 3 if room < 2 else 11
                if row == 2 and col in ([2,7] if room % 2 else [1,8]): tile = 7
                maps.append(tile)
    font_words = []
    for code in range(128):
        rows = FONT.get(chr(code), ['00000']*7)
        font_words += [int(row.center(5,'0'),2) for row in rows] + [0]
    assert len(tile_words)==4096 and max(tile_words)<64
    assert len(sprite_words)==3840 and max(sprite_words)<128
    assert len(maps)==250 and max(maps)<16
    assert len(font_words)==1024 and max(font_words)<32
    return {'bg_tiles.mem':tile_words, 'sprites.mem':sprite_words,
            'room_maps.mem':maps, 'font.mem':font_words}, tiles, sprites


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='verify committed ROMs match the PNGs and generator')
    args = parser.parse_args()
    memories, tiles, sprites = build()
    for name, words in memories.items():
        width = 1 if name == 'room_maps.mem' else 2
        data = ''.join(f'{v:0{width}x}\n' for v in words)
        if args.check:
            assert (OUT/name).read_text() == data, f'{name} is stale; run scripts/mem_gen.py'
        else:
            (OUT/name).write_text(data)
        print(f'{name}: {len(words)} words')
    if not args.check:
        sheet = Image.new('RGBA',(16*16,48),(24,20,36,255))
        for i, im in enumerate(tiles): sheet.alpha_composite(im,(i*16,0))
        for i, im in enumerate(sprites): sheet.alpha_composite(im,(i*16,24))
        sheet.resize((1024,192),Image.Resampling.NEAREST).convert('RGB').save(OUT/'rom_preview.png')

if __name__ == '__main__':
    main()
