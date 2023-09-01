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
  remaining_stamina="$(awk -F'[<>]' '/<div id="explorestam">/{print $3}' <<< "$output" | tr -d ',')"
  log::debug "Explored successfully | location='$explore_loc_num' remaining_stamina='$remaining_stamina'"
  log::info "Explored successfully | loc='$loc' args='${args[*]}'"

  if [ -z "$remaining_stamina" ] && [ "$drink_cider" == "true" ]; then
    log::warn "Not enough stamina to use an apple cider | output='$output'"
    remaining_stamina=0
  fi
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

# TODO pick priorities and figure out how to explore once
# have a helper loop invoke it until we are done
# Helper loop will use all remaining stamina
# Make sure we are maxed out on mushroom paste, first
function captain::explore() {
  eat "onion_soup"
  drink::orange_juice::all
  captain::explore::whispering_creek
}

function explore::get_current_stamina() {
  # TODO fix this
  explore::one --loc "whispering_creek"
}

# TODO write captain::explore::ensure_item ... to make exploring also craft
function captain::explore::glass_orb() {
  local remaining_stamina
  remaining_stamina="$(explore::get_current_stamina)"

  # TODO do u wanna explore to exhaustion for a resource or until out of stamina
  while (( $(item_obj::inventory "glass_orb") < (FARMRPG_MAX_INVENTORY-100) )); do
    remaining_stamina="$(explore::one --apple_cider --item "glass_orb")"
    craft_max "glass_bottle"
    craft_max "cooking_pot"
    craft_max "magicite"
    explore::shed "magicite"
    if (( remaining_stamina < 1060 )); then
      break
    fi
  done
}

function captain::explore::stone() {
  local remaining_stamina
  remaining_stamina="$(explore::get_current_stamina)"

  # TODO do u wanna explore to exhaustion for a resource or until out of stamina
  while (( $(item_obj::inventory "stone") < (FARMRPG_MAX_INVENTORY-100) )); do
    remaining_stamina="$(explore::one --apple_cider --item "stone")"
    craft_max "glass_bottle"
    craft_max "cooking_pot"
    craft_max "magicite"
    explore::shed "magicite"
    if (( remaining_stamina < 1060 )); then
      break
    fi
  done
}

function captain::explore::forest() {
  local remaining_stamina
  remaining_stamina="$(explore::get_current_stamina)"

  # craftworks "board" "wood_plank"

  while (( remaining_stamina > 1060 )); do
    if (( $(item_obj::inventory "stone") < (100) )); then
      captain::explore::stone
    fi
    while (( $(item_obj::inventory "oak") < (100) )); do
      local i_have
      i_have=$(item_obj::inventory "oak")
      log::info "Getting some oak for crossbow | i_have='$i_have' i_want='100'"
      remaining_stamina="$(explore::one --apple_cider --loc "whispering_creek" 2>/dev/null)"
      if ! (( remaining_stamina > 1060 )); then
        return
      fi
    done

    remaining_stamina="$(explore::one --apple_cider --loc "forest")"
    craft_max "leather"
    craft_max "crossbow"
    # craft_max "mushroom_paste" && craft::use_paste
    craft_max "twine"
    craft_max "rope"
    craft_max "fishing_net"
    craft_max "large_net"
    explore::shed "wood"
  done

  # Use remaining stamina on just exploring
  log::info "Using remaining stamina to explore whispering_creek"
  explore --loc "forest"
}

function captain::explore::whispering_creek() {
  local remaining_stamina
  remaining_stamina="$(explore::get_current_stamina)"

  while (( remaining_stamina > 1060 )); do
    if (( $(item_obj::inventory "stone") < (100) )); then
      captain::explore::stone
    fi
    remaining_stamina="$(explore::one --apple_cider --loc "whispering_creek")"
    craft_max "apple_cider"
    craft_max "orange_juice"
    craft_max "lemonade"
    craft_max "garnet"
    craft_max "garnet_ring"
    craft_max "iron_ring"
    craft_max "salt"
    craft_max "red_dye"
    craft_max "canoe"
    explore::shed "slimestone"
    explore::shed "blue_gel"
    explore::shed "red_berries"
    explore::shed "sour_root"
    explore::shed "thorns"
  done

  # Use remaining stamina on just exploring
  log::info "Using remaining stamina to explore whispering_creek"
  explore --loc "whispering_creek"
}
