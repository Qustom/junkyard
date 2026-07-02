#!/usr/bin/env python3
"""Gradient-map retone applied to the PixelLab hub tilesets (H2, 2026-07-01).
Warm hues (>=295deg or <=58deg, s>0.22) -> Band-0 rust-brown/dusty-ochre ramp;
cool litter hues (58..255deg, s>0.12, dirt_litter sheet only) -> gray-rust ramp.
80/85% ramp + 20/15% original blend to keep texture variation.
Input:  *_original.png (raw PixelLab sheets)   Output: the shipped atlas tiles."""
import colorsys
from PIL import Image

RAMP = [(0.00,(38,26,20)), (0.25,(74,50,34)), (0.50,(122,84,52)), (0.75,(164,124,78)), (1.00,(206,172,120))]
GRAY = [(0.00,(32,28,26)), (0.35,(82,70,60)), (0.65,(128,112,96)), (1.00,(180,162,142))]

def ramp(t, R):
    for i in range(len(R)-1):
        t0,c0=R[i]; t1,c1=R[i+1]
        if t<=t1:
            f=(t-t0)/(t1-t0)
            return tuple(int(a+(b-a)*f) for a,b in zip(c0,c1))
    return R[-1][1]

def retone(im, litter=False):
    im=im.convert('RGBA'); px=im.load()
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,a=px[x,y]
            if a==0: continue
            h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255); hue=h*360
            lum=(0.30*r+0.59*g+0.11*b)/255
            if (hue>=295 or hue<=58) and s>0.22:
                nr,ng,nb=ramp(min(1.0,lum*1.15),RAMP)
                px[x,y]=(int(nr*.8+r*.2),int(ng*.8+g*.2),int(nb*.8+b*.2),a)
            elif litter and 58<hue<255 and s>0.12:
                nr,ng,nb=ramp(min(1.0,lum*1.3),GRAY)
                px[x,y]=(int(nr*.85+r*.15),int(ng*.85+g*.15),int(nb*.85+b*.15),a)
    return im

if __name__=='__main__':
    for name, lit in (('asphalt_dirt',False),('dirt_litter',True),('dirt_scrap',False)):
        retone(Image.open(f'tilesets/{name}_original.png'), lit).save(f'tilesets/{name}_retoned.png')
