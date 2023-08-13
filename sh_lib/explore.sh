function explore::one() {
  # Parse args
  while (( $# > 0 )); do
    local explore_loc_num
    case "$1" in
      --item)
        local loc item
        item="${2:?}"
        loc="$(item::name_to_location "$item")"
        explore_loc_num="$(item::location_to_num "$loc")"
        shift 2
        log::debug "Dereferenced item into explore location | item='$item' loc='$loc'"
        ;;
      --apple_cider)
        local drink_cider="true"
        shift
        ;;
      --loc)
        loc="$2"
        explore_loc_num="$(item::location_to_num "$loc")"
        shift 2
        ;;
      [0-9][0-9])
        explore_loc_num="$1"
        shift 1
        ;;
      *) echo "Unknown argument in ${FUNCNAME[0]}: '$1'"; return 1 ;;
    esac
  done

  # Also add cider
  args=("go=explore" "id=${explore_loc_num}")
  if [ "$drink_cider" == "true" ]; then
    args=( "${args[@]}" "cider=1" )
  fi

  if ! output="$(worker "${args[@]}")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  local remaining_stamina
  remaining_stamina="$(awk -F'[<>]' '/<div id="explorestam">/{print $3}' <<< "$output")"
  log::debug "Explored successfully | location='$explore_loc_num' remaining_stamina='$remaining_stamina'"
  log::info "Explored successfully | loc='$loc'"

  echo "$remaining_stamina"
}

function explore() {
  local remaining_stamina=999
  while (( remaining_stamina > 0 )); do
    remaining_stamina="$(explore::one "$@" | tr -d ',')"
  done
}

function rapid_explore() {
  kill_pids=()
  while True; do
    ( explore "$@" & ) >/dev/null
    kill_pids=( "${kill_pids[@]}" $! )
    sleep "$(rapid_tap_delay)"
    if (( ${#kill_pids[@]} > 100 )); then
      sleep 3
      log::info "Killing ${#kill_pids[@]} explore processes processes"
      for pid in "${kill_pids[@]}"; do
        kill "$pid" &>/dev/null || true
      done
    fi
  done
}
