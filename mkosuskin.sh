#!/bin/bash
## Fancy way to render an osu skin.
## Requires: blender, lmms, p7zip, parallel, vips, imagemagick
#export skinname="ReZero Script"

## initialize
trap 'cleanup aborted; exit 1' INT
OPTIND=1

export BOLD=$(tput bold)
export NORMAL=$(tput sgr0)
export RED=$(tput setaf 1)
export MAGENTA=$(tput setaf 5)

export module=()
export projectroot="$(pwd)"
export assets_dir="$projectroot"/utils/assets # eg. empty.png
export utils_dir="$projectroot"/utils # render_marker, build_functions, etc.
export build_dir="$projectroot"/out # where each version's output sits
export cache_dir="$projectroot"/cache # store previously rendered stuff

source "$utils_dir"/utils.bash

## get options
while getopts "p:r:dm:ho" opt; do
  case $opt in
    p)
      source_dir="$OPTARG" # get the source dir from here, splitting script and skin
      export skinname="$(echo $OPTARG | sed 's+skin\.++; s+/++')"
      ;;
    r)
      revision="$OPTARG"
      ;;
    d)
      revision="dev"
      ;;
    h)
      exithelp 0
      ;;
    m)
      module+=("$OPTARG")
      ;;
    o)
      use_override=1
      ;;
    *)
      revision=$(date +%Y%m%d%H%M%S%z)
      ;;
  esac
done

[ "$source_dir" == "" ] && exithelp 1

export outname="${skinname} ${revision}"
export out_dir="$build_dir"/"$outname"
mkdir -p "$out_dir"
mkdir -p "$cache_dir"

## prepare
echoreport cleaning up...
cleanup

cd "$source_dir"
echoreport start rendering "$outname"...

## render images
#empties=(count{1..3}.png default-{0..9}.png \
#hit300{,g,k}-0.png inputoverlay-background.png lighting.png \
#ranking-graph.png scorebar-bg.png sliderendcircle.png \
#sliderpoint10.png sliderpoint30.png sliderscorepoint.png \
#spinner-bottom.png spinner-clear.png spinner-glow.png spinner-middle.png \
#star2.png)

### empties
echoreport copying empty image template to images...
parallel render_empty ::: $(cat empties.txt | tr '\n' ' ')

#parallel cp "$assets_dir"/empty.png ::: ${empties[*]}

i="$(find . -name '*.rendermarker.blend' -not -name '*%*')"
exists? $i && \
  for file in $i; do
  render_blender_marker $(basename $file)
  done

i="$(find . -name '*.rendernormal.blend' -not -name '*%*')"
exists? $i && \
  for file in $i; do
  render_blender $(basename $file)
  done

i="$(find . -name '*.svg' -not -name '*%*')"
exists? $i && \
  parallel render_svg {/} ::: $i

i="$(find . -name '*.mmpz' -not -name '*%*')"
exists? $i && \
  parallel render_lmms {/} ::: $i

for x in ${module[@]}; do
  torender_normal="$(find . -name '*.rendernormal.blend' -name '*%'"$x"'*')"
  torender_marker="$(find . -name '*.rendermarker.blend' -name '*%'"$x"'*')"
  torender_lmms="$(find . -name '*.mmpz' -name '*%'"$x"'*')"
  torender_svg="$(find . -name '*.svg' -name '*%'"$x"'*')"

  if exists? $torender_normal; then
    for file in $torender_normal; do
      render_blender $file
    done
  fi
  if exists? $torender_marker; then
    for file in $torender_marker; do
        render_blender_marker $file
    done
  fi
  if exists? $torender_svg; then
    parallel render_svg {/} ::: $torender_svg
  fi
  if exists? $torender_lmms; then
    parallel render_lmms {/} ::: $torender_lmms
  fi
done

## post processing
echoreport resizing score-dot and score-comma...
# TODO: autocrop
#for i in score-{dot,comma}@2xtmp.png; do
#  [ ! -f $i ] && continue
#  convert -crop 20x84+14+0 $i "$(basename $i @2xtmp.png)@2x.png"
#  rm $i
#done
tocrop=$(find . -name '*tocrop*.png')
exists? $tocrop && parallel autocrop ::: $tocrop

totrim=$(find . -name '*totrim.png')
exists? $totrim && parallel autotrim ::: $totrim

### resize
echoreport resizing other images...
toresize=$(find . -name '*resizeto*')
exists? $toresize && parallel resize_resizeto ::: $toresize
parallel "resize_at n" ::: *@*.png
parallel "resize_at t" ::: *@*.png

## package
cd "$projectroot"
echoreport moving rendered files into output folder...

#for i in "$source_dir"/sub.*; do
#  newsub="$out_dir"/$(echo $i | sed s/sub\.//g)
#  mkdir "$newsub"
#  # move files containing neither blend nor mmpz to newsub
#  mv "$(find "$i" | awk '!/blend/ && !/mmpz/')" "$newsub"/
#  # copy txt files to newsub
#  cp "$(find "$i" | grep .txt)" "newsub"/
#done

# cp / mv rendered stuff into cache
mv "$source_dir"/*.{png,wav} "$cache_dir"
mv "$source_dir"/move/* "$cache_dir"/
cp -r "$source_dir"/copy/* "$cache_dir"/

cp -r "$cache_dir"/* "$out_dir"

[ "$use_override" == 1 ] && cp override/* "$out_dir"/ >/dev/null 2>/dev/null
sed "s/NNNNAAAAMMMMEEEE/$skinname $revision/g" "$source_dir"/skin.ini > out/"$outname"/skin.ini

echoreport packaging output folder into osk file...
cd "$build_dir"
7z a "$outname".zip "$outname"/
mv "$outname".zip "$outname".osk

echoreport "$outname".osk is now ready.
