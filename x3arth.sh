#!/bin/bash
#
#    x3arth.sh - Download, crop, colorize and set as wallpaper satellite images of the earth
#
#    This file is part of the x3arth project https://github.com/luxigo/x3arth
#
#    Copyright (C) 2015 Luc Deschenaux <luc.dechenaux@freesurf.ch>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Additional Terms:
#
#      You are required to preserve legal notices and author attributions in
#      that material or in the Appropriate Legal Notices displayed by works
#      containing it.


set -x

[ -z "$X3ARTH" ] && X3ARTH=$HOME/.x3arth
[ -z "$BARS_THRESHOLD" ] && BARS_THRESHOLD=20
[ -z "$QUARTERS_THRESHOLD" ] && QUARTERS_THRESHOLD=3

CONFIG=$X3ARTH/config
[ -f "$CONFIG" ] && . "$CONFIG"

init() {

  # parse command line options
  if ! options=$(getopt -o harx:y:s:d:npu:R -l help,all,random,offsetx:,offsety:,sample:,destdir:,nochange,previous,url,reload -- "$@")
  then
      # something went wrong, getopt will put out an error message for us
      exit 1
  fi

  eval set -- "$options"

  while [ $# -gt 0 ] ; do
      case $1 in
      -h|--help) usage ;;
      -a|--all) ALL=yes ;;
      -r|--random) RANDOMIMAGE=yes ;;
      -x|--offsetx)
        offset=$2
        shift
        if [ "${offset:0:1}" == '+' -o "${offset:0:1}" == '-' ] ; then
          OFFSETX=$((OFFSETX+offset))
        else
          OFFSETX=$offset
        fi
      ;;
      -y|--offsety)
        offset=$2
        shift
        if [ "${offset:0:1}" == '+' -o "${offset:0:1}" == '-' ] ; then
          OFFSETY=$((OFFSETY+offset))
        else
          OFFSETY=$offset
        fi
      ;;
      -s|--sample) SAMPLE=$2 ; shift ;;
      -d|--destdir) DEST=$2 ; shift ;;
      -n|--nochange) CHANGE=no ;;
      -c|--change) CHANGE=yes ;;
      -p|--previous) PREVIOUS=yes ;;
      -u|--url) URL=$2 ; shift ;;
      -r|--reload) RELOAD=yes ;;
      (--) shift; break;;
      (-*) echo "$(basename $0): error - unrecognized option $1" 1>&2; exit 1;;
      (*) break;;
      esac
      shift
  done

  # update preferences

  [ $# -gt 4 ] && usage

  [ -z "$DEFAULTPATH" ] && DEFAULTPATH=goeswest/fulldisk/fullres/vis
  export IMAGEPATH=($(echo $DEFAULTPATH | tr '/' ' '))

  # positional parameters (subdirectories)
  for (( i=0; i<$# ; ++i)) ; do
    IMAGEPATH[$i]=$1
    shift
  done

  DEFAULTPATH=$(echo ${IMAGEPATH[*]} | tr ' ' '/')

  [ -z "$SAMPLE" ] && SAMPLE=$X3ARTH/sample.bmp
  [ -z "$DEST" ] && DEST=$X3ARTH
  [ -z "$URL" ] && URL=http://goes.gsfc.nasa.gov
  saveprefs
}

usage() {
  cat << EOF
NAME
  x3arth - download, crop, colorize and set satellite images as wallpaper

SYMOPSIS
  usage: x3arth [options] [<remote_path>]

OPTIONS

  -h|--help
  -r|--reload
  -p|--previous
  -r|--random
  -x|--offsetx [+|-]<offset>
  -y|--ofsety [+|-]<offset>
  -n|--nochange
  -c|--change
  -s|--sample <gradient>
  -d|--destdir <directory>
  -u|--url <url>

EOF

  exit 1
}

main() {

  init "$@"

  mkdir -p $DEST/$DEFAULTPATH || exit 1
  cd $DEST/$DEFAULTPATH || exit 1

  [ -f $DEST/.prevbackground ] || touch $DEST/.prevbackground || exit 1
  [ -f .prevfiles ] || touch .prevfiles || exit 1

  if [ -z "$RELOAD"  -a -n "$PREVIOUS" -a -n "$BACKGROUNDIMAGE" ] ; then

    if [ -n "$RANDOMIMAGE" ] ; then

      echo "loading random previous background"
      BACKGROUNDIMAGE=$(find . -name \*png | shuf -n 1 )

    else
      while read BG ; do
        if [[ "BACKGROUNDIMAGE" != "$BG" ]] ; then
          PREVIOUSBG=$BG
        else
          BACKGROUNDIMAGE=$PREVIOUSBG
          echo "loading previous background image from list"
          break
        fi
      done < $DEST/.prevbackground
    fi

    if [ -z "$BACKGROUNDIMAGE" ] ; then
      echo "error: no background image found"
      exit 1
    fi

    saveprefs
    displaybg
    exit 0

  fi

  if [ -z "$RELOAD" ] ; then

    if [ -n "$RANDOMIMAGE" ] ; then

      echo "using random previous raw image"
      TIFF=$(find $DEST/$DEFAULTPATH -name \*.tif | shuf -n 1 )

    else

      echo "downloading next raw image"
      wget -N $URL/$DEFAULTPATH/ || exit 1

      FIFO=$(mktemp -u).$$
      mkfifo $FIFO

      if [ -z "$PREVIOUS" ] ; then
        echo "extract next raw image name from index.html"
      else
        echo "extract previous raw image name from index.html"
      fi

      sed -r -n -e 's/.* href="([0-9]{10}......\.tif)".*/\1/p' index.html > $FIFO &
      while read tiff ; do

        if [ -n "$PREVIOUS" ] ; then
          # extract previous raw image name from index.html

          if [[ "$BACKGROUNDIMAGE" != $(basename $tiff .tif)* ]] ; then
            PREVIOUS=$tiff
            continue
          fi

          TIFF=$PREVIOUS

          # dont download again
          grep $TIFF .prevfiles && break

          tiff=$TIFF

        else
          grep $tiff .prevfiles && continue

        fi

        echo "downloading raw image"
        wget -c $URL/$DEFAULTPATH/$tiff || exit 1

        TIFF=$tiff

        echo $TIFF >> .prevfiles

        # stop after the first download unless specified
        [ -z "$ALL" ] && break

        # stop if we were extracting previous raw image from index.html
        [ -n "$PREVIOUS" ] && break

      done < $FIFO
      rm $FIFO

    fi

  else
    echo "using same raw image"
  fi

  [ -z "$TIFF" ] && exit 1

  desktop_res=($(xdpyinfo | grep dimens | awk '{print $2}' | tr x ' '))
  sw=${desktop_res[0]}
  sh=${desktop_res[1]}

  image_res=($(identify $TIFF | sed -r -n -e 's/.*TIFF ([0-9]+)x([0-9]+) .*/\1 \2/p'))
  iw=${image_res[0]}
  ih=${image_res[1]}

  RETRY=10
  while true ; do

    if [ "$CHANGE" != "no" -o -z "$OFFSETX" -o -z "$OFFSETY" -o -n "$offset_changed" ] ; then
      echo offset=reuse$offset
      if [ -z "$offset" ] ; then
        OFFSETX=$(((iw-sw)*RANDOM/32767))
        OFFSETY=$(((ih-sh)*RANDOM/32767))
        offset_changed=1
      fi
    fi

    ox=$OFFSETX
    oy=$OFFSETY

    [ $ox -lt 0 ] && ox=0
    [ $oy -lt 0 ] && oy=0

    if [ -z "$RELOAD" -o -z "$BACKGROUNDIMAGE" -o -n "$offset_changed" ] ; then
      BACKGROUNDIMAGE=$(basename $TIFF .tif).$(date +%s).png
      convert -crop ${sw}x${sh}+$ox+$oy $TIFF $BACKGROUNDIMAGE || exit 1
      newimage=yes

      # exit loop when image looks okay
      if histogram_check $BACKGROUNDIMAGE $BARS_THRESHOLD $QUARTERS_THRESHOLD ; then
        break

      else

        # avoid infinite loop
        if [ $((RETRY--)) -eq 0 ] ; then
          echo "Cannot find a nice tile to display, giving up"
          exit 1
        fi

        if [ -n "$RANDOMIMAGE" ] ; then
          TIFF=$(find $DEST/$DEFAULTPATH -name \*.tif | shuf -n 1)
          image_res=($(identify $TIFF | sed -r -n -e 's/.*TIFF ([0-9]+)x([0-9]+) .*/\1 \2/p'))
          iw=${image_res[0]}
          ih=${image_res[1]}
        else
          if [ -z "$offset_changed" ] ; then
            echo "Cannot find a nice tile to display, giving up"
            echo "Try another image or offsets"
            exit 1
          fi

        fi

        # retry
        continue

      fi

    fi

    break

  done

  if [ -n "$newimage" ] ; then
    gimp -i -b "(sample-colorize \"$SAMPLE\" \"$BACKGROUNDIMAGE\" \"$BACKGROUNDIMAGE\")" -b "(gimp-quit 1)" || exit 1
  fi

  saveprefs
  displaybg
}

displaybg() {
  dconf write /org/gnome/desktop/background/picture-uri "'file://$(pwd)/$BACKGROUNDIMAGE'" || exit 1
  dconf write /org/gnome/desktop/background/primary-color "'black'" || exit 1
  dconf write /org/gnome/desktop/background/picture-options "'spanned'" || exit 1
  dconf write /org/gnome/desktop/background/secondary-color "'#000000'" || exit 1
}

saveprefs() {
  cat << EOF > $CONFIG
OFFSETX=$OFFSETX
OFFSETY=$OFFSETY
CHANGE=$CHANGE
SAMPLE=$SAMPLE
DEST=$DEST
URL=$URL
ZOOM=$ZOOM
DEFAULTPATH=$DEFAULTPATH
BACKGROUNDIMAGE=$BACKGROUNDIMAGE
TIFF=$TIFF
EOF
}

main "$@"

