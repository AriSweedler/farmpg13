function eat() {
  # Item
  local item_name item_obj item_nr
  item_name="${1:?Meal to eat}"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not convert arg to item object | arg='$1'"
    return 1
  fi
  item_nr="$(item_obj::num "$item_obj")"

  # Default value of '1'
  local amt
  amt="${2:-1}"

  # Do work
  local output
  if ! output="$(worker "go=usemultitem" "id=$item_nr" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Ate a meal | item_name='$item_name'" ;;
    *) log::err "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function drink::grape_juice() {
  local output
  if ! output="$(worker "go=drinkgj" "id=280551")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully drank grape juice" ;;
    *) log::err "Failed to drink grape juice" ; return 1 ;;
  esac
}

################################################################################
#################################### apples ####################################
################################################################################

function eat::apple::one() {
  local output
  if ! output="$(worker "go=eatapple" "id=7")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    *"regained some stamina"*) log::info "Successfully ate apple" ;;
    *) log::err "Failed to eat an apple | output='$output'" ; return 1 ;;
  esac
}

function eat::apple::ten() {
  eat::apple::_x 10
}

function eat::apple::hundred() {
  eat::apple::_x 100
}

function eat::apple::_x() {
  local amt="${1:?}"
  case "$amt" in
    10|100) log::debug "About to eat some apples | amt='$amt'" ;;
    *) log::err "This is not a valid number of apples to eat | amt='$amt'" ; return 1;;
  esac

  # Do work
  local output
  if ! output="$(worker "go=eatxapples" "amt=$amt" "id=7")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    *"regained stamina"*) log::info "Successfully ate multiple apples | amt='$amt'" ;;
    *) log::err "Failed to eat multiple apples | output='$output' amt='$amt'" ; return 1 ;;
  esac
}

function eat::apples() {
  local count="${1:?}"
  while (( count > 100 )); do
    eat::apple::hundred
    (( count -= 100 ))
  done
  while (( count > 10 )); do
    eat::apple::ten
    (( count -= 10 ))
  done
  while (( count > 0 )); do
    eat::apple::one
    (( count -= 1 ))
  done
}

################################################################################
################################# orange_juice #################################
################################################################################

function drink::orange_juice::all() {
  # Do work
  local output
  if ! output="$(worker "go=drinkojs" "id=10")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    *drank*)
      output2=$(grep -o "got.*stamina" <<< "$output")
      added_stamina="$(awk '{print $2}' <<< "$output2")"
      log::info "Drank all orange juice | added_stamina='$added_stamina'"
      ;;
    "You don't have any orange juice.") log::warn "$output" ;;
    "") log::err "Failed to drink all OJ" ; return 1;;
    *) log::warn "Unknown output to drinking all OJ | output='$output'" ; return 1 ;;
  esac
}

function drink::orange_juice::one() {
  local output
  if ! output="$(worker "go=drinkoj" "id=10")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    *"got 100 stamina"*) log::info "Successfully drank one OJ" ;;
    *) log::err "Failed to drink OJ | output='$output'" ; return 1 ;;
  esac
}

function drink::orange_juice::ten() {
  drink::orange_juice::_x 10
}

function drink::orange_juice::hundred() {
  drink::orange_juice::_x 100
}

function drink::orange_juice::_x() {
  local amt="${1:?}"
  case "$amt" in
    10|100) log::debug "About to drink some OJ | amt='$amt'" ;;
    *) log::err "This is not a valid number of OJs to drink | amt='$amt'" ; return 1;;
  esac

  # Do work
  local output
  if ! output="$(worker "go=drinkxojs" "amt=$amt" "id=10")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    *"got"*"stamina"*) log::info "Successfully drank multiple OJs | amt='$amt'" ;;
    *) log::err "Failed to drink multiple OJs | output='$output' amt='$amt'" ; return 1 ;;
  esac
}

function drink::orange_juices() {
  local count="${1:?}"
  while (( count > 100 )); do
    drink::orange_juice::hundred
    (( count -= 100 ))
  done
  while (( count > 10 )); do
    drink::orange_juice::ten
    (( count -= 10 ))
  done
  while (( count > 0 )); do
    drink::orange_juice::one
    (( count -= 1 ))
  done
}

################################################################################
################################### lemonade ###################################
################################################################################

function drink::arnold_palmer() {
  local loc explore_loc_num
  loc="${1:?}"
  explore_loc_num="$(explore::loc_to_num "$loc")"

  # Do work
  local output
  if ! output="$(worker "go=drinklm" "id=$explore_loc_num")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    *"helped you find"*) log::info "Successfully drank an arnold palmer" ;;
    *) log::err "Failed to drink an arnold palmer | output='$output'" ; return 1 ;;
  esac
}

function drink::lemonades() {
  local count="${1:?}"
  while (( count > 0 )); do
    drink::arnold_palmer "whispering_creek"
    (( count -= 20 ))
  done
}
