friendship::_give() {
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
    log::warn "Nothing to give to friend | item_obj='$item_obj'"
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

################################################################################
################################## Individuals #################################
################################################################################

function friendship::buddy() {
  friendship::_give "gummy_worms" "22447"
  # friendship::_give "pirate_bandana" "22447"
  # friendship::_give "pirate_flag" "22447"
}

function friendship::roomba() {
  friendship::_give "carbon_sphere" "71761"
}

function friendship::thomas() {
  friendship::_give "minnows" "22441"
}

function friendship::captain_thomas() {
  friendship::_give "minnows" "71805"
}

function friendship::beatrix() {
  friendship::_give "black_powder" "22440"
}

function friendship::vincent() {
  friendship::_give "mushroom_paste" "22445"
  friendship::_give "wooden_box" "22445"

  for useless_item in \
    "drum" "largemouth_bass" "trout" "carp" "flier" \
    "grubs" "stone"; do
    friendship::_give "$useless_item" "22445"
  done
}

function friendship::star() {
  friendship::_give "eggs" "46158"
}

function friendship::jill() {
  friendship::_give "yellow_perch" "22444"
}

function friendship::lorn() {
  # TODO have vincent stop taking all the stone
  while craft_max::tree "iron_cup"; do
    friendship::_give "iron_cup" "22446"
  done
}

################################################################################
################################### everyone ###################################
################################################################################

function friendship::campaign() {
  log::info "Being friendly {{{"
  friendship::captain_thomas
  friendship::roomba
  friendship::buddy
  friendship::beatrix
  friendship::vincent
  friendship::star
  friendship::lorn
  log::info "Being friendly }}}"
}
