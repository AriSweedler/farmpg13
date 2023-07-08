function _get_first_open_oven() {
  echo "1"
}

function cook() {
  local item="${1:?}"
  local item_nr
  if ! item_nr="$(item::name_to_num "${item}")"; then
    log::err "Failed to convert item name to num | item='$item'"
    exit 1
  fi

  local -r oven_nr="$(_get_first_open_oven)"
  if ! output="$(worker "go=cookitem" "id=$item_nr" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi
  log::info "Put a meal in the oven | meal='$item' output='$output'"
}

function cook::stir() {
  local -r oven_nr="$(_get_first_open_oven)"
  if ! output="$(worker "go=stirmeal" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi
  log::info "Stirred a meal | oven_nr='$oven_nr' output='$output'"
}

function cook::taste() {
  local -r oven_nr="$(_get_first_open_oven)"
  if ! output="$(worker "go=tastemeal" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi
  log::info "Tasted a meal | oven_nr='$oven_nr' output='$output'"
}

function cook::season() {
  local -r oven_nr="$(_get_first_open_oven)"
  if ! output="$(worker "go=seasonmeal" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi
  log::info "Seasoned a meal | oven_nr='$oven_nr' output='$output'"
}

function cook::collect() {
  local -r oven_nr="$(_get_first_open_oven)"
  if ! output="$(worker "go=cookready" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi

  case "$output" in
    success) log::info "Collected a meal | oven_nr='$oven_nr'" ;;
    notready) log::err "Meal is not ready!" ; exit 1 ;;
    *) log::err "Unknown output to worker | output='$output'" ; exit 1 ;;
  esac
}

function cook::bone_broth() {
  ( sleep 0 && cook "bone_broth" ) &
  sleep 2
  # TODO we can optimize this. For the longer cook times, you can stir again and again.
  ### Stirring reduces remaining time by 10%. 1 min original timer. 15 min cooldown.
  ### Tasting. 3 min original timer. 20 min cooldown.
  ### Seasoning. 5 min original timer. 30 min cooldown.
  ( sleep 60 && cook::stir ) &
  ( sleep 180 && cook::taste ) &
  ( sleep 300 && cook::season ) &
  ( sleep 510 && cook::collect ) &
  wait
  log::info "Finished cooking a bone broth"
}
