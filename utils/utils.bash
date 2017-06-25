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
  # cleanup [aborted]
  [ "$1" == "aborted" ] && echoerror aborted by user, cleaning up...
  rm "$source_dir"/*.{png,jpg,wav} 2>/dev/null
  for i in "$build_dir"/"$outname"{,.osk,.zip}; do
    [ -f "$i" ] && rm "$i" -r
  done
}

render_normal () {
  echoreport rendering "$1"...
  blender -b "$1" -a >/dev/null
}; export -f render_normal

render_python () {
  echoreport rendering "$1" with python script "$(basename $2)" ...
  blender -b "$1" --python "$2" >/dev/null
}; export -f render_python

render_audio_lmms () {
  echoreport rendering audio "$1" ...
  lmms --format wav -r "$1" >/dev/null
  mv "$(basename $1 .mmpz)".wav "$(echo $(basename $1 .mmpz) | sed 's/^lmms\.//g').wav"
}; export -f render_audio_lmms

autotrim () {
  echoreport trimming $1 ...
  convert -trim +repage $1 "$(basename $1 totrim.png)".png
  rm $1
}; export -f autotrim

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
  size=$(echo $orig_file | cut -d'_' -f 2 | sed 's/resizeto//g; s/\.png//')
  target_file="$(basename $orig_file _resizeto"$size".png).png"
  convert -resize $size $orig_file $target_file
  #vipsthumbnail --size="$size" -o $target_file $orig_file
  rm $1
}; export -f resize_resizeto
