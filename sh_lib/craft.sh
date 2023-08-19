function craft() {
  local item_obj item_nr
  function craft::logCtx() {
    [ -n "$qty" ] && echo -n "qty='$qty' "
    [ -n "$adjusted_qty" ] && echo -n "adjusted_qty='$adjusted_qty' "
    echo -n "item='$item_obj/$item_nr'"
  }

  # Parse item arg
  item_obj="$(item::new::name "$1")"
  if ! item_nr="$(item_obj::num "$item_obj")"; then
    log::err "Failed to get item ID"
    return 1
  fi

  # Parse and massage qty arg
  local qty adjusted_qty
  qty="${2:?How many to craft}"
  if (( qty == 0 )); then
    log::err "You must craft at least 1 item"
    return 1
  fi
  adjusted_qty=$(python -c "import math; print(math.ceil($qty / $FARMRPG_CRAFTING_BOOST))")
  log::debug "Asking to craft less than desired output because of perks | $(craft::logCtx)"

  # Do work
  local output
  if ! output="$(worker "go=craftitem" "id=${item_nr}" "qty=${adjusted_qty}")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  case "$output" in
    success) log::info "Successfully crafted | $(craft::logCtx)" ;;
    cannotafford) log::err "Missing a resource necessary to craft this | $(craft::logCtx)" ; return 1 ;;
    "") log::warn "Output to craft attempt is empty | $(craft::logCtx)" ; return 1 ;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | $(craft::logCtx) output='$output'" ; return 1 ;;
  esac
}

function craft_max() {
  local -r item="${1:?}"
  local item_nr
  item_nr="$(item_obj::num "$item")"
  log::info "Trying to craft | item='$item/$item_nr'"

  # Fetch recipe
  local -r recipe="$(jq -c -r '.["'"$item_nr"'"]' "./scraped/item_number_to_recipe.json")"
  if [ "$recipe" == "null" ]; then
    log::err "No recipe for this item"
    return 1
  fi
  log::debug "We know how to craft item | item='$item' item_nr='$item_nr' recipe='$recipe'"

  local -r count="$(python3 << EOF
# Load all the data into python
import json
recipe = json.loads('$recipe')
inventory = json.loads('$(inventory)')

# Figure out how many we can craft to hit max inventory
want_craft_inventory = int($FARMRPG_MAX_INVENTORY - inventory.get('$item_nr', 0))

# Figure how many we can craft given our materials
want_craft_materials_dict = dict()
for key, value in recipe.items():
    want_craft_materials_dict[key] = 0
    if key not in inventory:
      want_craft_inventory = 0
      continue
    while inventory[key] >= recipe[key]:
      inventory[key] -= recipe[key]
      want_craft_materials_dict[key] += 1
want_craft_materials = min(want_craft_materials_dict.values())

# Give the answer
ans = min(want_craft_inventory, want_craft_materials)
print(max(0, ans))
EOF
)"
  if (( count == 0 )); then
    log::debug "Cannot craft any | item='$item' count='$count'"
    return 0
  fi
  log::debug "Trying to craft as many as we can | item='$item' count='$count'"

  # Do work
  if craft "${item:?}" "${count:?}"; then
    craft_max "$@"
  fi
  return 0
}

function craftworks() {
  craftworks::remove_all

  # Iterate through input and make them all part of craftwords
  local item_name item_obj item_nr
  for item_name in "$@"; do
    # Error check
    if (( crafty_count++ > FARMRPG_CRAFTWORKS_SLOTS )); then
      log::err "Cannot place items in craftworks, we only have FARMRPG_CRAFTWORKS_SLOTS slots | FARMRPG_CRAFTING_BOOST='$FARMRPG_CRAFTWORKS_SLOTS' item_name='$item_name'"
      continue
    fi

    # Parse item
    item_name="${1:?Item to place in craftworks}"
    if ! item_obj="$(item::new::name "$item_name")"; then
      log::err "Could not convert arg to item object | arg='$1'"
      return 1
    fi
    item_nr="$(item_obj::num "$item_obj")"

    # Do work
    item_obj::craftworks::add "$item_obj"
  done
  craftworks::play_all
}

function craftworks::remove_all() {
  # Do work
  local output
  if ! output="$(worker "go=removeallcw" "id=$id")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Removed all items from craftworks" ;;
    "") log::err "Failed to remove all items from craftworks" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function craftworks::play_all() {
  # Do work
  local output
  if ! output="$(worker "go=playallcw" "id=$id")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Played all items in craftworks" ;;
    "") log::err "Failed to play all items in craftworks" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function item_obj::craftworks::add() {
  # Parse args
  local item_obj="${1:?}"

  # Get item id
  local item_id
  if ! item_id="$(item_obj::num "$1")"; then
    log::err "Failed to get item ID"
    return 1
  fi

  # Do work
  local output
  if ! output="$(worker "go=addcwitem" "id=$item_id")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Added craftworks item | item_obj='$item_obj'" ;;
    "") log::err "Failed to add craftworks item | item_obj='$item_obj'" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}
