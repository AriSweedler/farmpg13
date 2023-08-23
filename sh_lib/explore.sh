function explore::one() {
  # Parse args
  while (( $# > 0 )); do
    local explore_loc_num
    case "$1" in
      --item)
        local loc item_obj
        item_obj="$(item::new::name "$2")"
        loc="$(item_obj::explore_location "$item_obj")"
        explore_loc_num="$(explore::loc_to_num "$loc")"
        shift 2
        log::debug "Dereferenced item into explore location | item_obj='$item_obj' loc='$loc'"
        ;;
      --apple_cider)
        local drink_cider="true"
        shift
        ;;
      --loc)
        loc="$2"
        explore_loc_num="$(explore::loc_to_num "$loc")"
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
  log::info "Explored successfully | loc='$loc' args='${args[*]}'"

  if [ -z "$remaining_stamina" ] && [ "$drink_cider" == "true" ]; then
    log::warn "Not enough stamina to use an apple cider | output='$output'"
    remaining_stamina=0
  fi
  echo "$remaining_stamina" | tr -d ','
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

function explore::loc_to_num() {
  local -r loc="${1:?}"
  local -r num="$(jq -r '.["'"$loc"'"]' "./scraped/location_to_number.json")"
  if [ "$num" == "null" ]; then
    log::err "Could not turn location into a number | num='$num'"
    printf "0"
    return 1
  fi

  printf "%s" "$num"
}

function explore::shed() {
  local item_name item_obj
  item_name="${1:?Item to shed excess of}"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not convert arg to item object | arg='$1'"
    return 1
  fi

  if (( $(item_obj::inventory "$item_obj") < (FARMRPG_MAX_INVENTORY - 100) )); then
    return
  fi

  # We have too many
  sell "$item_obj" 100
}
