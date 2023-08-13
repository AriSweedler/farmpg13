function friendship::roomba() {
  friendship::_give "carbon_sphere" "71761"
}

function friendship::thomas() {
  friendship::_give "minnows" "22441"
}

function friendship::_give() {
  # Give thomas all the minnows
  local item_name="${1:?What item to give}"
  local recipient="${2:?Who to give to}"

  # Get the item ID and qty yo give
  local item_id
  if ! item_id="$(item_obj::num "$item_name")"; then
    log::err "Failed to get item ID"
    return 1
  fi
  if ! qty="$(item::inventory::from_name "$item_name")"; then
    log::err "Could not figure out how much to donate"
    return 1
  fi

  local output
  if ! output="$(worker "go=givemailitem" "id=$item_id" "to=$recipient" "qty=$qty")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Gave item to friend | item='$item_name/$item_id qty='$qty'" ; return 0;;
    "") log::err "Failed to give item to friend" ; return 1 ;;
  esac
}
