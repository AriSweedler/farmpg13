function fish::loc_to_num() {
  local -r loc_name="$(echo "${1:?}" | tr '-' '_')"
  local -r loc_nr="$(jq -r '.["'"$loc_name"'"]' "./scraped/fishloc_to_number.json")"
  if [ "$loc_nr" == "null" ]; then
    log::err "Could not turn fishing location into a number | loc_nr='$loc_nr' item_name='$item_name'"
    printf "0"
    return 1
  elif [ "$loc_nr" == "-1" ]; then
    log::err "You cannot fish there yet"
    printf "0"
    return 1
  fi

  printf "%s" "$loc_nr"
}

function fish::net::one() {
  local loc
  if ! loc="$(fish::loc_to_num "${1:?}")"; then
    log::err "Couldn't turn arg into location to fish"
    return 1
  fi

  # Send the HTTP request
  local -r mult=1
  local output
  if ! output="$(worker "go=castnet" "id=$loc" "mult=$mult")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Did casting the net fail?
  case "$output" in
    "") log::err "Not enough nets" ; return 1 ;;
    *) log::debug "Cast a net | loc='$loc' mult='$mult' output='$output'" ;;
  esac
  log::info "Cast a net | loc='$loc' mult='$mult'"
  echo "$output"
}

function fish::net::all::old() {
  local output
  while output="$(fish::net::one "$@")"; do
    # Are any fish at max capacity?
    if grep -q "grayscale" <<< "$output"; then
      log::info "Some items are at max capacity, selling them"
      sell_cap
    fi
  done
}

################################################################################

function fish::sell() {
  local output
  if ! output="$(worker "go=sellalluserfish")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  if (( output > 0 )); then
    log::info "Sold fish for some money | output='$output' num_nets='$num_nets'"
    return
  fi

  log::err "Unknown output to '${FUNCNAME[0]}' | output='$output'"
  return 1
}

function fish::net::all() {
  local num_nets
  if ! num_nets="$(item_obj::inventory "large_net")"; then
    log::err "Failed to find number of large nets | num_nets='$num_nets'"
    return 1
  fi
  log::info "We are going to use all our remaining large num_nets | num_nets='$num_nets'"

  if (( num_nets > 250 )); then
    eat "shrimp_a_plenty"
    eat "sea_pincher_special"
  else
    log::warn "You have less than 250 nets, you should save until you have that and then eat the meals - each one gives you 10% more gold (it stacks by multiplying)"
    return 1
  fi

  while (( num_nets > 0 )); do
    fish::net::one "pirate_s_cove" >/dev/null
    (( --num_nets % 10 == 0 )) && fish::sell
  done
}

################################################################################
function fish::selectbait() {
  local item_name item_obj
  item_name="${1:?Bait to set}"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not convert arg to item object | arg='$1'"
    return 1
  fi

  local bait_formal
  if ! bait_formal="$(item_obj::as_bait "$item_obj")"; then
    log::err "Could not set item as bait - it is not bait | item_obj='$item_obj'"
    return 1
  fi

  # Do work
  local output
  if ! output="$(worker "go=selectbait" "bait=$bait_formal" "r=$RANDOM")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Set bait | bait='$item_obj'" ;;
    "") log::err "Failed to set bait | bait='$item_obj'" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function chore::fish() {
  function fish::_mealworm() {
    local fish_loc="${1:?}"
    if ! loc_id="$(fish::loc_to_num "$fish_loc")"; then
      log::err "Couldn't turn arg into location to fish"
      return 1
    fi

    # Do work
    local output
    if ! output="$(worker "go=fishcaught" "id=$loc_id")"; then
      log::err "Failed to invoke worker"
      return 1
    fi

    # Parse output
    case "$output" in
      *fishcnt*)
        local caught
        caught="$(echo "$output" | grep -o 'itemimg. ><br/>.*<span' | awk -F'[><]' '{print $4}')"
        log::debug "Fished with a mealworm | caught='$caught'"
        log::info "Fished with a mealworm"
        ;;
      "") log::err "Failed to fish with a mealworm | output='$output'" ; return 1;;
    esac
  }

  # Parse args
  local count="${1:?}"

  # Set state
  fish::selectbait "Mealworms"

  # Do work
  while (( count-- > 0 )); do
    fish::_mealworm "farm_pond"
  done

  unset fish::_mealworm
}

################################################################################
##################################### nets #####################################
################################################################################

function fish::nets() {
  local count="${1:?}"
  local loc="pirate_s_cove"
  while (( count > 0 )); do
    if (( $(item_obj::inventory "large_net") > 1 )); then
      fish::net::one "$loc" >/dev/null
      (( count -= 25 ))
    elif (( $(item_obj::inventory "fishing_net") > 1 )); then
      fish::net::one "$loc" >/dev/null
      (( count -= 1 ))
    else
      log::err "Out of fishing nets!"
      if ! captain::ensure_have "fishing_net" "$count"; then
        log::err "Could not ensure we had enough fishing nets"
        return 1
      fi
    fi
  done
}
