# item
# location
# location number
function explore::one() {
  # Parse args
  set -e
  while (( $# > 0 )); do
    local explore_loc_num
    case "$1" in
      --item)
        local loc item
        item="${2:?}"
        loc="$(item::name_to_location "$item")"
        explore_loc_num="$(item::location_to_num "$loc")"
        shift 2
        log::info "Dereferenced item into explore location | item='$item' loc='$loc'"
        ;;
      --loc)
        explore_loc_num="$(item::location_to_num "$2")"
        shift 2
        ;;
      [0-9][0-9])
        explore_loc_num="$1"
        shift 1
        ;;
      *) echo "Unknown argument in ${FUNCNAME[0]}: '$1'"; exit 1 ;;
    esac
  done
  set +e

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
    remaining_stamina="$(explore::one "$@" | tr -d ',')"
  done
}

function rapid_explore() {
  while True; do
    ( ./bin/cli explore 7 & ) &>/dev/null
    sleep "$(rapid_tap_delay)"
  done
}

