# Cooking helper functions
function cook::put_in_oven() {
  local item="${1:?}"
  local oven_nr="${2:?}"

  # Parse args
  local item_nr
  if ! item_nr="$(item_obj::num "${item}")"; then
    log::err "Failed to convert item name to num | item='$item'"
    return 1
  fi

  # Do work
  if ! output="$(worker "go=cookitem" "id=$item_nr" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  log::info "Put a meal in the oven | meal='$item' output='$output'"
}

function cook::loop::stir() {
  local -r oven_nr="${1:?}"
  if ! output="$(worker "go=stirmeal" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  log::info "Stirred a meal | oven_nr='$oven_nr' output='$output'"

  sleep $((60*15))
  cook::loop::stir "$@"
}

function cook::loop::taste() {
  local -r oven_nr="${1:?}"
  if ! output="$(worker "go=tastemeal" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  log::info "Tasted a meal | oven_nr='$oven_nr' output='$output'"

  sleep $((60*20))
  cook::loop::taste "$@"
}

function cook::loop::season() {
  local -r oven_nr="${1:?}"
  if ! output="$(worker "go=seasonmeal" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  log::info "Seasoned a meal | oven_nr='$oven_nr' output='$output'"

  sleep $((60*30))
  cook::loop::season "$@"
}

function cook::collect() {
  local -r oven_nr="${1:?}"
  if ! output="$(worker "go=cookready" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Collected a meal | oven_nr='$oven_nr'" ;;
    notready) log::err "Meal is not ready!" ; return 1 ;;
    *) log::err "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

# Cooking event loop
function cook::_impl() {
  # Parse args
  local -r recipe="${1:?What food do you wanna cook}"
  local -r recipe_wait_time="${2:?How long does it take to cook in seconds with optimal stirring}"

  # Figure args out
  function cook::_get_open_oven() {
    echo "1"
  }
  local -r oven_nr="$(cook::_get_open_oven)"

  # Start doing work
  cook::put_in_oven "$recipe" "$oven_nr"
  sleep 2

  # Set up background jobs to stir, taste, and season. Clean these jobs up, too
  ( sleep 60 && cook::loop::stir "$oven_nr" ) &
  killers=( "${killers[@]}" $! )
  ( sleep 180 && cook::loop::taste "$oven_nr" ) &
  killers=( "${killers[@]}" $! )
  ( sleep 300 && cook::loop::season "$oven_nr" ) &
  killers=( "${killers[@]}" $! )
  # shellcheck disable=SC2064
  trap "kill ${killers[*]}" RETURN EXIT SIGINT

  # Main job will wait until the meal is ready to collect. Trap will clean up
  # all the child jobs
  sleep "$recipe_wait_time"
  cook::collect "$oven_nr"
  log::info "Finished working on cooking | recipe='$recipe'"
}

############################## cook specific meals #############################

function cook::bone_broth() {
  cook::_impl "bone_broth" "550"
}

function cook::onion_soup() {
  cook::_impl "onion_soup" "3000"
}

function cook::cats_meow() {
  cook::_impl "cat’s_meow" "6000"
}
