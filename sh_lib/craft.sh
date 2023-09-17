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
  local -r item_name="${1:?}"
  local item_nr
  item_nr="$(item_obj::num "$item_name")"
  log::debug "[CRAFT] [MAX] Trying to craft | item='$item_name/$item_nr'"

  # Fetch recipe
  local -r recipe="$(item_obj::recipe "$item_name")"
  if [ "$recipe" == "null" ]; then
    log::err "[CRAFT] [MAX] No recipe for this item"
    return 1
  fi
  log::debug "[CRAFT] [MAX] We know how to craft item | item_name='$item_name' item_nr='$item_nr' recipe='$recipe'"

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
ans = min(want_craft_inventory, want_craft_materials*$FARMRPG_CRAFTING_BOOST)
print(int(max(0, ans)))
EOF
)"
  if (( count == 0 )); then
    log::debug "[CRAFT] [MAX] Cannot craft any | item_name='$item_name' count='$count'"
    return 1
  fi
  log::debug "[CRAFT] [MAX] Trying to craft as many as we can | item_name='$item_name' count='$count'"

  # Do work
  if craft "${item_name:?}" "${count:?}"; then
    craft_max "$@"
  fi
  return 0
}

function craft_max::tree() {
  # Parse args
  local item_obj
  if ! item_obj="$(item::new::name "$1")"; then
    log::err "[CRAFT] [MAX TREE] Argument was not an item name"
    return 1
  fi

  # Exit early
  if ! item_obj::is_craftable "$item_obj"; then
    log::debug "[CRAFT] [MAX TREE] This item is not craftable | item='$item_obj/$item_nr'"
    return 1
  fi

  local item_nr
  item_nr="$(item_obj::num "$item_obj")"
  log::info "[CRAFT] [MAX TREE] Start {{{ | item='$item_obj/$item_nr'"

  # Recurse to craft all the children, craft as many of us as we can.
  # Repeat this until we make no more of us
  local rc=1 ritem_obj ritem_nr
  local -r recipe="$(item_obj::recipe "$item_obj")"
  while true; do
    # Craft max tree on all child objects
    for ritem_nr in $(jq -r 'keys[]' <<< "$recipe"); do
      ritem_obj="$(item::new::number "$ritem_nr")"
      craft_max::tree "$ritem_obj"
    done

    # Keep running this loop while we're making more
    if craft_max "$item_obj"; then
      rc=0
      continue
    fi

    # Terminate
    log::info "[CRAFT] [MAX TREE] Crafted as much as possible }}} | item='$item_obj'"
    return $rc
  done
}

function craftworks() {
  craftworks::remove_all || return 1

  # Iterate through input and make them all part of craftwords
  local item_name item_obj item_nr
  for item_name in "$@"; do
    # Error check
    if (( crafty_count++ > FARMRPG_CRAFTWORKS_SLOTS )); then
      log::err "Cannot place items in craftworks, we only have FARMRPG_CRAFTWORKS_SLOTS slots | FARMRPG_CRAFTING_BOOST='$FARMRPG_CRAFTWORKS_SLOTS' item_name='$item_name'"
      continue
    fi

    # Parse item
    if ! item_obj="$(item::new::name "$item_name")"; then
      log::err "Could not convert arg to item object | arg='$1'"
      return 1
    fi
    item_nr="$(item_obj::num "$item_obj")"

    # Do work
    item_obj::craftworks::add "$item_obj"
  done
  craftworks::play_all || return 1

  sleep 1
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

function craft::use_paste() {
  craft_max::tree "hammer"
  craft_max::tree "shovel"
  craft_max::tree "canoe"
  craft_max::tree "fancy_guitar"
  craft_max::tree "garnet_ring"
  craft_max::tree "axe"
  craft_max::tree "leather_diary"
  craft_max::tree "purple_diary"
  craft_max::tree "green_diary"
}

function captain::workshop() {
  log::info "[CAPTAIN] Workshop {{{"
  cmts_priority=(
    "rope"
    "wooden_box"
  )
  cmts=(
    "mushroom_paste"
    "large_net"
    "black_powder"
    "cooking_pot"
    "fancy_guitar"
    "fancy_pipe"
    "ladder"
    "wooden_shield"
    "rope"
    "scissors"
    "axe"
    "hammer"
    "sturdy_bow"
    "sturdy_box"
    "sturdy_shield"
    "treasure_chest"
    "wagon_wheel"
    "wooden_barrel"
    "wooden_box"
    "wooden_shield"
    "wooden_sword"
    "wooden_table"
    "wrench"
    "yarn"
  )
  inventory::clear_cache
  for item in "${cmts_priority[@]}"; do
    craft_max::tree "$item"
  done
  for item in "${cmts[@]}"; do
    if (( RANDOM % 6 == 0 )); then
      craft_max::tree "$item"
    fi
  done
  log::info "[CAPTAIN] Workshop }}}"
}
