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
    *) log::err "Unknown output to eat meal | output='$output'" ; return 1 ;;
  esac
}

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
      added_stamina="$(sed -nE "s/.*got ([0-9]+) stamina.*/\1/p" <<< "$output")"
      log::info "Drank all orange juice | added_stamina='$added_stamina'"
      ;;
    "You don't have any orange juice.") log::warn "$output" ;;
    "") log::err "Failed to drink all OJ" ; return 1;;
    *) log::warn "Unknown output to drinking all OJ | output='$output'" ; return 1 ;;
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
