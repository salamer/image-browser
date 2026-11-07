#!/usr/bin/env python3
"""Generate a complete macOS AppIcon asset catalog from the artwork.
Uses Pillow only for resizing and removing the white artwork canvas.
"""
from PIL import Image, ImageOps
from pathlib import Path
import json, sys

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'Resources' / 'icon-artwork.png'
out = root / 'Resources' / 'Assets.xcassets' / 'AppIcon.appiconset'
out.mkdir(parents=True, exist_ok=True)
image = Image.open(source).convert('RGB')
# The icon artwork has a white outer canvas; isolate the rounded navy symbol.
pixels = image.load()
w, h = image.size
# Dark pixels of the icon are easily separated from its near-white canvas.
box = Image.new('L', image.size, 0)
mask = box.load()
for y in range(h):
    for x in range(w):
        r,g,b = pixels[x,y]
        darkness = 255 - min(r,g,b)
        mask[x,y] = max(0, min(255, int((darkness-10)*18)))
bounds = box.getbbox()
if not bounds:
    raise ValueError('Icon artwork has no nonwhite bounds')
# Keep a small transparent breathing room consistent with macOS app icons.
left,top,right,bottom = bounds
side=max(right-left,bottom-top)
cx=(left+right)//2;cy=(top+bottom)//2
pad=int(side*0.035);side+=pad*2
square=(cx-side//2,cy-side//2,cx+(side-side//2),cy+(side-side//2))
rgba=image.convert('RGBA');rgba.putalpha(box)
icon=rgba.crop(square).resize((1024,1024), Image.Resampling.LANCZOS)
icon.save(root / 'Resources' / 'SwiftLensIcon.png')
specs=[(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
images=[]
for base,scale in specs:
    pixels=base*scale
    filename=f'icon_{base}x{base}{"@2x" if scale==2 else ""}.png'
    icon.resize((pixels,pixels), Image.Resampling.LANCZOS).save(out/filename)
    images.append({'idiom':'mac','size':f'{base}x{base}','scale':f'{scale}x','filename':filename})
(out/'Contents.json').write_text(json.dumps({'images':images,'info':{'author':'xcode','version':1}},indent=2))
(root/'Resources'/'Assets.xcassets'/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2))
print('Built macOS AppIcon from',source)
