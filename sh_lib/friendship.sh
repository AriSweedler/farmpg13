function friendship::buddy() {
  friendship::_give "gummy_worms" "22447"
}

function friendship::roomba() {
  friendship::_give "carbon_sphere" "71761"
}

function friendship::thomas() {
  friendship::_give "minnows" "22441"
}

function friendship::_give() {
  # Give thomas all the minnows
  local item_obj recipient
  item_obj="$(item::new::name "$1")"
  recipient="${2:?Who to give to}"

  # Get the item ID and qty to give
  local item_id
  if ! item_id="$(item_obj::num "$item_obj")"; then
    log::err "Failed to get item ID"
    return 1
  fi
  if ! qty="$(item_obj::inventory "$item_obj")"; then
    log::err "Could not figure out how much to donate"
    return 1
  fi

  if (( qty <= 0 )); then
    log::warn "Nothing to give to friend | item_obj='$item_obj' qty='$qty'"
    return 1
  fi

  local output
  if ! output="$(worker "go=givemailitem" "id=$item_id" "to=$recipient" "qty=$qty")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Gave item to friend | item='$item_obj/$item_id qty='$qty'" ; return 0;;
    "") log::err "Failed to give item to friend" ; return 1 ;;
  esac
}
