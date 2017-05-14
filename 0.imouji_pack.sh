#!/bin/bash
# Still missing:
### Image
# - cursor.png cursormiddle.png cursortrail.png
# - followpoint-n.png
# - inputoverlay-background.png inputoverlay-key.png
# - menu-back-n.png menu-button-background.png
# - play-skip.png
# - ranking-panel.png
# - ready.png
# - scorebar-bg.png scorebar-colour-n.png
# - section-fail.png section-pass.png
# - selection-tab.png
# - spinner-rpm.png
# - star.png
# - star2.png
# - mania, taiko, catch

empties=(lighting.png sliderendcircle.png sliderpoint10.png sliderpoint30.png sliderscorepoint.png spinner-{glow,middle,bottom,clear,osu,top}.png ranking-graph.png mode-{fruits,taiko,mania,osu}-small.png hit300{,g,k}-0.png count{1,2,3}.png)

echo creating empty images...
for i in ${empties[@]}; do
  convert -size 1x1 xc:none $i
done

if ls *.png 2>/dev/null >/dev/null; then
  echo trimming totrim images
  for i in *totrim.png; do
    [ ! -f $i ] && continue
    convert -trim +repage $i $(basename $i totrim.png).png
    rm $i
  done
fi


echo copying button.png into button-*
for i in button-{left,middle,right}.png; do
  cp button.png $i
done
rm button.png

echo creating score-percent...
convert -size 1040x1 xc:none score-percent.png

echo generating ranking-small from normal ranking...
for i in ranking-{A,B,C,D,S,SH,X,XH}@2x.png; do
  convert -resize 8% $i $(basename $i @2x.png)-small@2x.png
done

for f in 8 4; do
  echo resizing @"$f"x to @$((f/2))x and removing @"$f"x...
  for i in *@"$f"x.png; do
    [ ! -f $i ] && continue
    convert -resize 50% $i $(basename $i @"$f"x.png)@$((f/2))x.png
    rm $i
  done
done

echo resizing score-dot and score-comma...
for i in score-{dot,comma}@2xtmp.png; do
  [ ! -f $i ] && continue
  convert -crop 20x84+14+0 $i $(basename $i @2xtmp.png)@2x.png
  rm $i
done

echo resizing inputoverlay-key...
for i in inputoverlay-key@2xtmp.png; do
  [ ! -f $i ] && continue
  convert -resize 86x86 $i $(basename $i @2xtmp.png)@2x.png
  rm $i
done

echo creating SD images from @2x...
for i in *@2x.png; do
  convert -resize 50% $i $(basename $i @2x.png).png
done

echo copying combo-{0-9} to default-{0-9}...
for i in $(ghci -e [0..9] | sed 's/,/ /g' | sed 's/\[//g' | sed 's/\]//g'); do
  cp combo-"$i"@2x.png default-"$i"@2x.png
  cp combo-"$i".png default-"$i".png
done
