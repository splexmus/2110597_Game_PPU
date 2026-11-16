#!/usr/bin/env python3
"""Run serial gameplay and full-raster RTL checks with Icarus + Pillow."""
from pathlib import Path
import re
import subprocess
import tempfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'test/output'


def run(*args, cwd=ROOT):
    subprocess.run(args, cwd=cwd, check=True)


def words(name):
    return [int(v,16) for v in (ROOT/'data'/name).read_text().split()]


def rgb(v):
    return tuple(((v >> shift) & 3)*85 for shift in (4,2,0))


def check_rom_paths():
    # Match Playground's literal-only ROM discovery and src-relative paths.
    sources = '\n'.join(p.read_text() for p in (ROOT/'src').glob('*.v'))
    paths = re.findall(r'\$readmem[hb]\s*\(\s*"([^"]+)"', sources)
    assert len(paths) == len(re.findall(r'\$readmem[hb]\s*\(', sources)) == 4
    targets = {(ROOT/'src'/p).resolve() for p in paths}
    assert targets == set((ROOT/'data').glob('*.mem'))
    assert all(p.is_file() for p in targets)
    print('PASS: Playground discovers all four ROM files relative to src')


def check_frames():
    tiles, maps, sprites, font = (words(n) for n in ('bg_tiles.mem','room_maps.mem','sprites.mem','font.mem'))
    assert len({tuple(maps[r*50:(r+1)*50]) for r in range(5)}) == 5
    assert any(v==0 for v in sprites) and any(v & 64 for v in sprites)
    previews = []
    names = ['THE GATE','BONE HALL','THE CRYPT','IRON KEEP','THRONE ROOM']
    for scene in range(9):
        with Image.open(OUTPUT/f'scene{scene}.ppm') as frame:
            frame.load()
            assert frame.size == (640,480)
            small = frame.resize((160,120),Image.Resampling.NEAREST)
            # Every pixel must be replicated exactly 4x4, including line ends.
            assert small.resize(frame.size,Image.Resampling.NEAREST).tobytes() == frame.tobytes(), f'Scaling/line timing scene {scene}'
            room = scene-1 if 1 <= scene <= 5 else 4
            if 1 <= scene <= 6:
                for y in range(26,96):
                    for x in range(160):
                        if 55 <= y < 57:  # Health bars have separate boundary checks below.
                            continue
                        tile = maps[room*50+((y-16)//16)*10+x//16]
                        expected = tiles[tile*256+((y-16)%16)*16+x%16]
                        objects = [(0,28,60),(6,72,40),(8,0,28),(8,144,28)]
                        if scene <= 5: objects.append((room+1,108,60))
                        else: objects.append((7,72,64))
                        if room % 2: objects.append((9,8,64))
                        for sprite, sx, sy in objects:
                            if sx <= x < sx+16 and sy <= y < sy+24:
                                value = sprites[sprite*384+(y-sy)*16+x-sx]
                                if value & 64: expected = value & 63
                        assert small.getpixel((x,y)) == rgb(expected), (scene,x,y,'ROM pixel mismatch')
                assert small.getpixel((44,55)) == rgb(0x0c)
                assert small.getpixel((45,55)) == rgb(0x10)
                header = f'ROOM {room+1}/5  {names[room]}'.ljust(26)
                status = f'HP 23/30  FOE {6+scene if scene<=5 else 0:02d}'.ljust(26)
            else:
                header = 'FIVE SEALED ROOMS'.center(26)
                status = ' '*26
            # Check the first and last scanlines of actual text ROM output too.
            text_color = 0x35 if scene==8 else 0x3c if scene==7 else 0x3f
            for row, message in enumerate((header,status)):
                for col, char in enumerate(message):
                    for gy in range(8):
                        for gx in range(6):
                            ink = gx<5 and font[ord(char)*8+gy] & (1 << (4-gx))
                            expected = rgb(text_color if ink else 1)
                            assert small.getpixel((2+col*6+gx,2+row*8+gy)) == expected, (scene,row,col,gx,gy,'font/HUD mismatch')
            frame.save(OUTPUT/f'scene{scene}.png')
            previews.append(frame.copy())
    montage = Image.new('RGB',(640*3,480*3))
    for n,frame in enumerate(previews): montage.paste(frame,((n%3)*640,(n//3)*480))
    montage.save(OUTPUT/'dungeon_preview.png')
    print('PASS: five distinct maps, ROM pixel composition, text, HP bars and exact 4x scaling')


def main():
    OUTPUT.mkdir(exist_ok=True)
    check_rom_paths()
    run('python3','scripts/mem_gen.py','--check')
    with tempfile.TemporaryDirectory(prefix='dungeon-') as temp:
        for bench in ('game','video'):
            exe = str(Path(temp)/f'{bench}.vvp')
            run('iverilog','-g2005','-s',f'tb_{bench}','-o',exe,
                *[str(p.relative_to(ROOT)) for p in sorted((ROOT/'src').glob('*.v'))],f'test/tb_{bench}.v')
            run('vvp',exe,cwd=ROOT/'src')
    check_frames()

if __name__ == '__main__':
    main()
