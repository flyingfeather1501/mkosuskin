#!/bin/bash
## Fancy way to render an osu skin.
## Requires: blender, lmms, p7zip, parallel, vips, imagemagick

## initialize
trap 'cleanup aborted; exit 1' INT
OPTIND=1

export BOLD=$(tput bold)
export NORMAL=$(tput sgr0)
export RED=$(tput setaf 1)
export MAGENTA=$(tput setaf 5)

export projectroot="$(pwd)"
export utils_dir="$projectroot"/utils # render_marker, build_functions, etc.
export build_dir="$projectroot"/out # where each version's output sits
export source_dir="$projectroot"/src # .blend, .mmpz, .svg, etc.
export skinname="ReZero Script"

source "$utils_dir"/utils.bash

## get options
while getopts "r:dh" opt; do
  case $opt in
    r)
      revision="$OPTARG"
      ;;
    d)
      revision="dev"
      ;;
    h)
      exithelp 0
      ;;
    *)revision=$(date +%Y%m%d%H%M%S%z)
  esac
done

export outname="${skinname} ${revision}"
mkdir -p "$build_dir"/"$outname"

## prepare
echoreport cleaning up...
cleanup

cd "$source_dir"
echoreport start rendering "$outname"...

## render images
empties=(count{1..3}.png default-{0..9}.png \
hit300{,g,k}-0.png inputoverlay-background.png lighting.png \
ranking-graph.png scorebar-bg.png sliderendcircle.png \
sliderpoint10.png sliderpoint30.png sliderscorepoint.png \
spinner-bottom.png spinner-clear.png spinner-glow.png spinner-middle.png \
star2.png)

### empties
echoreport copying empty image template to images...
parallel 'cp empty_image' ::: ${empties[*]}

parallel render_python {} "$utils_dir"/render_marker.py ::: rendermarker.*.blend
parallel render_normal ::: rendernormal.*.blend
parallel render_audio_lmms ::: lmms.*.mmpz

## post processing
echoreport resizing score-dot and score-comma...
for i in score-{dot,comma}@2xtmp.png; do
  [ ! -f $i ] && continue
  convert -crop 20x84+14+0 $i "$(basename $i @2xtmp.png)@2x.png"
  rm $i
done
parallel autotrim ::: *totrim.png

### resize
echoreport resizing other images...
parallel resize_resizeto ::: *resizeto*.png
parallel "resize_at n" ::: *@*.png
parallel "resize_at t" ::: *@*.png

cp button-left.png button-middle.png
cp button-left.png button-right.png

## package
cd "$projectroot"
echoreport moving rendered files into output folder...
mv "$source_dir"/*.png "$build_dir"/"$outname"/
mv "$source_dir"/*.wav "$build_dir"/"$outname"/
cp audio/*.ogg "$build_dir"/"$outname"/ # for external / prerecorded audio files
sed "s/NNNNAAAAMMMMEEEE/$skinname $revision/g" src/skin.ini > out/"$outname"/skin.ini

echoreport packaging output folder into osk file...
cd "$build_dir"
7z a "$outname".zip "$outname"/
mv "$outname".zip "$outname".osk

echoreport "$outname".osk is now ready.
