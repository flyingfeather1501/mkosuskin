#!/bin/bash
## Fancy way to render an osu skin.
## Requires: blender, lmms, p7zip, parallel, vips, imagemagick
export skinname="ReZero Script"

## initialize
trap 'cleanup aborted; exit 1' INT
OPTIND=1

export BOLD=$(tput bold)
export NORMAL=$(tput sgr0)
export RED=$(tput setaf 1)
export MAGENTA=$(tput setaf 5)

export projectroot="$(pwd)"
export assets_dir="$projectroot"/utils/assets # eg. empty.png
export utils_dir="$projectroot"/utils # render_marker, build_functions, etc.
export build_dir="$projectroot"/out # where each version's output sits
export cache_dir="$projectroot"/cache # store previously rendered stuff

source "$utils_dir"/utils.bash

## get options
while getopts "p:r:dho" opt; do
  case $opt in
    p)
      source_dir="$OPTARG" # get the source dir from here, splitting script and skin
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

files_to_render="$(sha256sum --check --quiet "$projectroot"/hashes 2>/dev/null \
                   | cut -d':' -f 1; # returns changed files
                   diff <(cat "$projectroot"/hashes 2>/dev/null \
                          | cut -d' ' -f 3 \
                          | sed "s|.*$source_dir||g" \
                          | sort) \
                        <(find "$source_dir" 2>/dev/null \
                          | grep -v "\.git" \
                          | sed "s|.*$source_dir||g" \
                          | sort) \
                   | grep '>' \
                   | sed s/'> '//g)" # returns unhashed files

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
exists? empty.*.png && \
  parallel render_empty_png ::: empty.*.png
exists? empty.*.wav && \
  parallel render_empty_wav ::: empty.*.wav
parallel cp "$assets_dir"/empty.png ::: ${empties[*]}

i="$(echo "$files_to_render" | grep 'rendermarker' | grep 'blend$')"
exists? $i && \
  parallel render_blender_py {/} "$utils_dir"/render_marker.py ::: $i

i="$(echo "$files_to_render" | grep 'rendernormal' | grep 'blend$')"
exists? $i && \
  parallel render_blender {/} ::: $i

i="$(echo "$files_to_render" | grep 'svg$')"
exists? $i && \
  parallel render_svg {/} ::: $i

i="$(echo "$files_to_render" | grep 'lmms' | grep 'mmpz$')"
exists? $i && \
  parallel render_lmms {/} ::: $i

sha256sum "$source_dir"/* > "$projectroot"/hashes 2>/dev/null

## post processing
echoreport resizing score-dot and score-comma...
# TODO: autocrop
for i in score-{dot,comma}@2xtmp.png; do
  [ ! -f $i ] && continue
  convert -crop 20x84+14+0 $i "$(basename $i @2xtmp.png)@2x.png"
  rm $i
done
exists? *totrim.png && parallel autotrim ::: *totrim.png

### resize
echoreport resizing other images...
exists? *resizeto*.png && parallel resize_resizeto ::: *resizeto*.png
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
cp "$source_dir"/copy/* "$cache_dir"/

cp "$cache_dir"/* "$out_dir"

[ "$use_override" == 1 ] && cp override/* "$out_dir"/ >/dev/null 2>/dev/null
sed "s/NNNNAAAAMMMMEEEE/$skinname $revision/g" "$source_dir"/skin.ini > out/"$outname"/skin.ini

echoreport packaging output folder into osk file...
cd "$build_dir"
7z a "$outname".zip "$outname"/
mv "$outname".zip "$outname".osk

echoreport "$outname".osk is now ready.
