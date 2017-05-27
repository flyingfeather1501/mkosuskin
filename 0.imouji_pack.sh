#!/bin/bash

### functions
echoreport () {
  echo ${BOLD}${MAGENTA}"<$0> "${NORMAL}${BOLD}"$*"${NORMAL}
}

echoerror () {
  echo ${BOLD}${MAGENTA}"<$0> "${RED}${BOLD}"$*"${NORMAL} 1>&2
}

cleanup () {
  echoerror aborted by user, cleaning up...
  rm "$projectroot"/src/*.png 2>/dev/null
  [ -f "$out" ] && rm "$out" -r
  [ -f "$out".osk ] && rm "$out".osk
  [ -f "$out".zip ] && rm "$out".zip
  echoreport exiting...
  exit
}

render_marker () {
  echoreport rendering "$1"...
  blender -b $1 --python render_marker.py
}

alldownto2x () {
for f in 8 4; do
  echoreport resizing @"$f"x to @$((f/2))x and removing @"$f"x...
  for i in *@"$f"x.png; do
    [ ! -f $i ] && continue
    convert -resize 50% $i $(basename $i @"$f"x.png)@$((f/2))x.png
    rm $i
  done
done
}

generate_empties () {
  echoreport creating empty images...
  for i in ${empties[@]}; do
    convert -size 1x1 xc:none $i
  done
}

HD2SD () {
  echoreport creating SD images from @2x...
  for i in *@2x.png; do
    convert -resize 50% $i $(basename $i @2x.png).png
  done
}

autotrim () {
  echoreport trimming totrim images...
  for i in *totrim.png; do
    [ ! -f $i ] && continue
    convert -trim +repage $i $(basename $i totrim.png).png
    rm $i
  done
}

autoresize () {
  echoreport resizing images with _resizeto in them
  # name the files as ${name}_resizeto${x}x${y}.png
  filelist=$(find *resizeto*); [[ $? != 0 ]] && return
  for i in $filelist; do
    size=$(echo $i | cut -d'_' -f 2 | sed 's/resizeto//g; s/\.png//')
    convert -resize $size $i $(basename $i _resizeto"$size".png).png
    rm $i
  done
}

### prepare
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
MAGENTA=$(tput setaf 5)
trap cleanup INT
case $1 in
  -r)
    [ -z $2 ] || revision=$2
    ;;
  -h|--help)
    echo "Usage: $(basename $0) [-r REVISION] [-h|--help]"
    exit
    ;;
  *)
    revision=$(date +%Y%m%d%H%M%S%z)
esac
skinname="ReZero Script"
out=out/"${skinname}"-"${revision}"
projectroot="$(pwd)"
mkdir -p "$out"

cd "$projectroot"/src/
rm *.png >/dev/null 2>/dev/null # Cleanup

### render images
empties=(lighting.png sliderendcircle.png sliderpoint10.png sliderpoint30.png sliderscorepoint.png spinner-{glow,middle,bottom,clear,osu}.png ranking-graph.png hit300{,g,k}-0.png count{1,2,3}.png)

generate_empties
for blend in *.blend; do
  render_marker $blend
done
autoresize
alldownto2x
echoreport resizing score-dot and score-comma...
for i in score-{dot,comma}@2xtmp.png; do
  [ ! -f $i ] && continue
  convert -crop 20x84+14+0 $i $(basename $i @2xtmp.png)@2x.png
  rm $i
done
autotrim
HD2SD

cp button-left.png button-middle.png
cp button-left.png button-right.png

### package
cd "$projectroot"
echoreport moving rendered files into output folder...
mv src/*.png "$out"/
cp Audio/* "$out"/ # gotta also manage audio files later
cp External\ Audio/* "$out"/
sed "s/NNNNAAAAMMMMEEEE/$skinname $revision/g" src/skin.ini > "$out/skin.ini"

echoreport packaging output folder into osk file...
7z a "$out".zip "$out"
mv "$out".zip "$out".osk

echoreport "$out".osk is now ready.
