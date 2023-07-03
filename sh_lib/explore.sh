function explore::one() {
  local -r explore_loc_num="${1:?where to explore::one}"

  if ! output="$(worker "go=explore" "id=${explore_loc_num}")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi
  local remaining_stamina
  remaining_stamina="$(awk -F'[<>]' '/<div id="explorestam">/{print $3}' <<< "$output")"
  log::info "Explored successfully | location='$explore_loc_num' remaining_stamina='$remaining_stamina'"

  echo "$remaining_stamina"
}

function explore() {
  local remaining_stamina=999
  while (( remaining_stamina > 0 )); do
    remaining_stamina="$(explore::one "$@")"
  done
}

function rapid_explore() {
  while True; do
    ( ./bin/cli explore 5 & ) &>/dev/null
    sleep "$(rapid_tap_delay)"
  done
}

