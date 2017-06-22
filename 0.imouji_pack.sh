#!/bin/bash
## Fancy way to render an osu skin.
## Requires: blender, lmms, p7zip, parallel, vips, imagemagick

## functions

exithelp () {
  echo "Usage: $(basename $0) [-r REVISION | -d] [-h|--help]"
  echo "Arguments:"
  echo " -r REVISION  specify a revision"
  echo " -d           revision=dev"
  echo " -h           print help (this message)"
  exit $1
}

echoreport () {
  echo ${BOLD}${MAGENTA}"<$0> "${NORMAL}${BOLD}"$*"${NORMAL}
}; export -f echoreport

echoerror () {
  echo ${BOLD}${MAGENTA}"<$0> "${RED}${BOLD}"$*"${NORMAL} 1>&2
}; export -f echoerror

cleanup () {
  echoerror aborted by user, cleaning up...
  rm "$projectroot"/src/*.png 2>/dev/null
  for i in "$projectroot"/out/"$outname"{,.osk,.zip}; do
    [ -f "$i" ] && rm "$i" -r
  done
  echoreport exiting...
  exit
}

render_normal () {
  echoreport rendering "$1"...
  blender -b "$1" -a >/dev/null
}; export -f render_normal

render_marker () {
  echoreport rendering "$1" with render_marker.py ...
  blender -b "$1" --python "$projectroot"/utils/render_marker.py >/dev/null
}; export -f render_marker

render_audio_lmms () {
  echoreport rendering audio "$1" ...
  lmms --format wav -r "$1" >/dev/null
  mv "$(basename $1 .mmpz)".wav "$(echo $(basename $1 .mmpz) | sed 's/^lmms\.//g').wav"
}; export -f render_audio_lmms

#alldownto2x () {
#for f in 8 4; do
#  echoreport resizing @"$f"x to @$((f/2))x and removing @"$f"x...
#  parallel
#  for i in *@"$f"x.png; do
#    [ ! -f $i ] && continue
#    convert -resize 50% $i "$(basename $i @"$f"x.png)@$((f/2))x.png"
#    rm $i
#  done
#done
#}

#HD2SD () {
#  echo resizing $1 ...
#  convert -resize 50% $1 "$(basename $1 @2x.png).png"
#}; export -f HD2SD

autotrim () {
  echoreport trimming totrim images...
  for i in *totrim.png; do
    [ ! -f $i ] && continue
    convert -trim +repage $i "$(basename $i totrim.png).png"
    rm $i
  done
}

resize_at () {
  # resize_at <n|t> <stst@Nx.png>
  # $1 == n -> only resize @n | n != 2
  # $1 == t -> only resize @2
  two_switch=$1
  orig_file=$2
  orig_size=$(echo $orig_file | sed 's/.*@//g; s/x.*png//g') # "*@3x.png" -> "3x.png" -> "3"
  case $two_switch in
    t)
      [ ! $orig_size -eq 2 ] && return
      target_size=1
      target_file=$(basename "$orig_file" @2x.png).png
      ;;
    n)
      [ $orig_size -eq 2 ] && return
      target_size=2
      target_file=$(basename "$orig_file" @"$orig_size"x.png)@"$target_size"x.png
      ;;
    *)
      echoerror resize_at failed && exit
      ;;
  esac
    echo resizing $orig_file...
  #convert -resize $(python -c "print('{0:.2f}'.format(${target_size} / ${orig_size}))") $orig_file $target_file
  vips resize $orig_file $target_file $(python -c "print('{0:.2f}'.format(${target_size} / ${orig_size}))")
  [ ! "$orig_size" -eq 2 ] && rm $orig_file
}; export -f resize_at

resize_resizeto () {
  echo resizing $1...
  # name the files as ${name}_resizeto${x}x${y}.png
  orig_file="$1"
  target_file="$(basename $1 _resizeto"$size".png).png"
  size=$(echo $orig_file | cut -d'_' -f 2 | sed 's/resizeto//g; s/\.png//')
  #convert -resize $size $1 "$(basename $1 _resizeto"$size".png).png"
  vipsthumbnail --size="$size" -o $target_file $orig_file
  rm $1
}; export -f resize_resizeto

## prepare
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
MAGENTA=$(tput setaf 5)
trap cleanup INT
case $1 in
  -r)
    if [ -z $2 ]; then
      exithelp 1
    else
      revision="$2"
    fi
    ;;
  -d)
    revision="dev"
    ;;
  -h|--help)
    exithelp 0
    ;;
  *)
    revision=$(date +%Y%m%d%H%M%S%z)
esac
skinname="ReZero Script"
outname="${skinname} ${revision}"
projectroot="$(pwd)"
mkdir -p "$projectroot"/out/"$outname"

cd "$projectroot"/src/
rm *.png >/dev/null 2>/dev/null # Cleanup

echoreport starting to render "$outname"...

## render images
empties=(count1.png count2.png count3.png default-{0..9}.png hit300-0.png hit300g-0.png hit300k-0.png inputoverlay-background.png lighting.png ranking-graph.png scorebar-bg.png sliderendcircle.png sliderpoint10.png sliderpoint30.png sliderscorepoint.png spinner-top.png spinner-clear.png spinner-glow.png spinner-middle.png star2.png)

### empties
echoreport copying empty image template to images...
parallel 'cp empty_image' ::: ${empties[*]}

parallel render_marker ::: rendermarker.*.blend
parallel render_normal ::: rendernormal.*.blend
parallel render_audio_lmms ::: lmms.*.mmpz

## post processing
echoreport resizing score-dot and score-comma...
for i in score-{dot,comma}@2xtmp.png; do
  [ ! -f $i ] && continue
  convert -crop 20x84+14+0 $i "$(basename $i @2xtmp.png)@2x.png"
  rm $i
done
autotrim

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
mv src/*.png out/"$outname"/
mv src/*.wav out/"$outname"/
cp audio/*.ogg out/"$outname"/ # for external / prerecorded audio files
sed "s/NNNNAAAAMMMMEEEE/$skinname $revision/g" src/skin.ini > out/"$outname"/skin.ini

echoreport packaging output folder into osk file...
cd $projectroot/out
7z a "$outname".zip "$outname"/
mv "$outname".zip "$outname".osk

echoreport "$outname".osk is now ready.
