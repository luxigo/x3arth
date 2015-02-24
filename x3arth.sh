#!/bin/bash

set -x

ALL=$1
SAMPLE=$HOME/.x3arth/sample.bmp

mkdir -p $HOME/.x3arth/goeswest/fulldisk/fullres/vis || exit 1

cd $HOME/.x3arth/goeswest/fulldisk/fullres/vis || exit 1

[ -f .prevfiles ] || touch .prevfiles || exit 1

wget -N http://goes.gsfc.nasa.gov/goeswest/fulldisk/fullres/vis/ || exit 1

sed -r -n -e 's/.* href="([0-9]{10}......\.tif)".*/\1/p' index.html | while read tiff ; do
  echo $tiff > /tmp/$BASH_PID.tmp
  grep $tiff .prevfiles && continue
  wget -c http://goes.gsfc.nasa.gov/goeswest/fulldisk/fullres/vis/$tiff || exit 1
  echo $tiff >> .prevfiles
  [ -z "$ALL" ] && break
done

tiff=$(cat /tmp/$BASH_PID.tmp)

[ -z "$tiff" ] && exit 1

cropped_image=background.$$.tiff
background_image=background.$$.png

desktop_res=($(xdpyinfo | grep dimens | awk '{print $2}' | tr x ' '))
sw=${desktop_res[0]}
sh=${desktop_res[1]}

image_res=($(identify $tiff | sed -r -n -e 's/.*([0-9]+)x([0-9]+).*/\1 \2/p'))
iw=${image_res[0]}
ih=${image_res[1]}

while true ; do 

RND1=$RANDOM
RND2=$RANDOM

[ $RND1 -lt 0 ] && RND1=$((-RND1))
[ $RND2 -lt 0 ] && RND2=$((-RND2))

ox=$(((iw-(sw-1200))*RANDOM/32767+1200))
oy=$(((ih-sh)*RANDOM/32767))

[ $ox -lt 0 ] && ox=0
[ $oy -lt 0 ] && oy=0

convert -crop ${sw}x${sh}+$ox+$oy $tiff $cropped_image || exit 1

size=$(du -k $cropped_image | cut -f 1)

[ $size -gt 1000 ] && break
done

gimp -i -b "(sample-colorize \"$SAMPLE\" \"$cropped_image\" \"$background_image\")" || exit 1

rm $cropped_image

dconf write /org/gnome/desktop/background/picture-uri "'file://$(pwd)/$background_image'" || exit 1
dconf write /org/gnome/desktop/background/primary-color "'black'" || exit 1
dconf write /org/gnome/desktop/background/picture-options "'spanned'" || exit 1
dconf write /org/gnome/desktop/background/secondary-color "'#000000'" || exit 1

