#!/bin/bash

set -x

[ -z "$X3ARTH" ] && X3ARTH=$HOME/.x3arth
CONFIG=$X3ARTH/config
[ -f "$CONFIG" ] && . "$CONFIG"

init() {

  # parse command line options
  if ! options=$(getopt -o harx:y:s:d:npu:kR -l help,all,random,offsetx:,offsety:,sample:,destdir:,nochange,previous,url,keep,reload -- "$@")
  then
      # something went wrong, getopt will put out an error message for us
      exit 1
  fi

  eval set -- "$options"

  while [ $# -gt 0 ] ; do
      case $1 in
      -h|--help) usage $1 ;;
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
      -n|--nochange) NOCHANGE=yes ;;
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

  [ $# -gt 4 ] && usage -h

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
  echo "usage: $(basename $0) -harxySdspP"
  exit $1
}

main() {

  init "$@"

  mkdir -p $DEST/$DEFAULTPATH || exit 1
  cd $DEST/$DEFAULTPATH || exit 1

  [ -f .prevfiles ] || touch .prevfiles || exit 1

  if [ -z "$RELOAD" ] ; then

    TIFFNAME=$(mktemp tmp.tifflistXXXXXX)

    if [ -n "$RANDOMIMAGE" ] ; then
      find $DEST/$DEFAULTPATH -name \*.tif | shuf -n 1 > $TIFFNAME

    else

      if [ -z "$PREVIOUS" ] ; then
        wget -N $URL/$DEFAULTPATH/ || exit 1
      fi

      sed -r -n -e 's/.* href="([0-9]{10}......\.tif)".*/\1/p' index.html | while read tiff ; do
        echo $tiff > $TIFFNAME
        if [ -n "$PREVIOUS" ] ; then
          if [[ "$BACKGROUNDIMAGE" != $(basename $tiff .tif)* ]] ; then
            PREVIOUS=$tiff
            continue
          fi
          echo $PREVIOUS > $TIFFNAME
          break
        fi
        grep $tiff .prevfiles && continue
        wget -c $URL/$DEFAULTPATH/$tiff || exit 1
        echo $tiff >> .prevfiles
        [ -z "$ALL" ] && break
      done

    fi

    TIFF=$(cat $TIFFNAME)
    rm $TIFFNAME

  fi

  [ -z "$TIFF" ] && exit 1

  cropped_image=$(basename $TIFF .tif).$(date +%s).tiff
  BACKGROUNDIMAGE=$(basename $TIFF .tif).$(date +%s).png

  desktop_res=($(xdpyinfo | grep dimens | awk '{print $2}' | tr x ' '))
  sw=${desktop_res[0]}
  sh=${desktop_res[1]}

  image_res=($(identify $TIFF | sed -r -n -e 's/.*TIFF ([0-9]+)x([0-9]+) .*/\1 \2/p'))
  iw=${image_res[0]}
  ih=${image_res[1]}

#  while true ; do

  [ -z "$offset" ] && OFFSETX=$(((iw-sw)*RANDOM/32767))
  [ -z "$offset" ] && OFFSETY=$(((ih-sh)*RANDOM/32767))

  ox=$OFFSETX
  oy=$OFFSETY

  [ $ox -lt 0 ] && ox=0
  [ $oy -lt 0 ] && oy=0

  convert -crop ${sw}x${sh}+$ox+$oy $TIFF $cropped_image || exit 1

  #size=$(du -k $cropped_image | cut -f 1)

  #[ $size -gt 1000 ] && break

#  done

  gimp -i -b "(sample-colorize \"$SAMPLE\" \"$cropped_image\" \"$BACKGROUNDIMAGE\")" -b "(gimp-quit 1)" || exit 1

  saveprefs
  rm $cropped_image

  dconf write /org/gnome/desktop/background/picture-uri "'file://$(pwd)/$BACKGROUNDIMAGE'" || exit 1
  dconf write /org/gnome/desktop/background/primary-color "'black'" || exit 1
  dconf write /org/gnome/desktop/background/picture-options "'spanned'" || exit 1
  dconf write /org/gnome/desktop/background/secondary-color "'#000000'" || exit 1
}

saveprefs() {
  cat << EOF > $CONFIG
OFFSETX=$OFFSETX
OFFSETY=$OFFSETY
NOCHANGE=$NOCHANGE
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

