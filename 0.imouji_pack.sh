#!/bin/bash

### functions
render_marker () {
  echo rendering $1
  echo ========
  blender -b $1 --python render_marker.py
}

alldownto2x () {
for f in 8 4; do
  echo resizing @"$f"x to @$((f/2))x and removing @"$f"x...
  for i in *@"$f"x.png; do
    [ ! -f $i ] && continue
    convert -resize 50% $i $(basename $i @"$f"x.png)@$((f/2))x.png
    rm $i
  done
done
}

generate_empties () {
  echo creating empty images...
  for i in ${empties[@]}; do
    convert -size 1x1 xc:none $i
  done
}

HD2SD () {
  echo creating SD images from @2x...
  for i in *@2x.png; do
    convert -resize 50% $i $(basename $i @2x.png).png
  done
}

autotrim () {
  echo trimming totrim images
  for i in *totrim.png; do
    [ ! -f $i ] && continue
    convert -trim +repage $i $(basename $i totrim.png).png
    rm $i
  done
}

autoresize () {
  echo resizing images with _resizeto in them
  # name the files as ${name}_resizeto${x}x${y}.png
  file=$(find *resizeto*); [[ $? != 0 ]] && return
  size=$(echo $file | cut -d'_' -f 2 | sed 's/resizeto//g; s/\.png//')
  convert -resize $size $file $(basename $file _resizeto"$size".png)
  rm $file
}

### prepare
version=$(date +%Y%m%d%H%M%S%z)
skinname="ReZero Script"
out=out/"${skinname}"-"${version}"
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
echo resizing score-dot and score-comma...
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
mv src/*.png "$out"/
cp Audio/* "$out"/ # gotta also manage audio files later
cp External\ Audio/* "$out"/
sed "s/NNNNAAAAMMMMEEEE/$skinname/g" src/skin.ini > "$out/skin.ini"

7z a "$out".zip "$out"
mv "$out".zip "$out".osk
