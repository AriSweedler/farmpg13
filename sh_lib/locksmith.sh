function chore::locksmith() {
  local -r amt="${1:?}"
  local -r id="491" # Grab Bag 07

  # Do work
  local output
  if ! output="$(worker "go=openitem" "id=$id" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  # <img src='/img/items/golddrum.png' style='width:16px'> Gold Drum x3<br/><img src='/img/items/goldfin.png' style='width:16px'> Goldfin x1<br/>
  local reward
  reward="$(echo "$output" \
    | sed 's|<br/>|\n|g' \
    | awk -F'[><]' '/img/ {print $3}' \
    | tr '\n' ';')"
  reward="${reward# }"
  case "$output" in
    "") log::err "Failed to open grab bag 07 | output='$output;" ; return 1;;
    *) log::info "Locksmith'd successfully | amt='$amt' reward='$reward'" ;;
  esac
}
