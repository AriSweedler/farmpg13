function craft() {
  # Parse args
  local -r item_name="${1:?}"
  if ! item_nr="$(item_obj::num "$item_name")"; then
    log::err "Failed to get item ID"
    return 1
  fi
  local quantity="${2:?How many to craft}"
  # quantity=$(python -c "import math; print(math.ceil($quantity / $FARMRPG_CRAFTING_BOOST))")
  if (( quantity == 0 )); then
    log::err "You must craft at least 1 item"
    return 1
  fi
  log::debug "Crafting 80% of desired output because of perks | quantity='$2' adjusted='$quantity' item_name='$item_name'"

  # Do work
  local output
  if ! output="$(worker "go=craftitem" "id=${item_nr}" "qty=${quantity}")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  local -r item="$item_name/$item_nr"
  case "$output" in
    success) log::info "Successfully crafted | item='$item' quantity='$quantity'" ;;
    cannotafford) log::err "Missing a resource necessary to craft this | item='$item'" ; return 1 ;;
    "") log::warn "Output to craft attempt is empty | item='$item' quantity='$quantity'" ; return 1 ;;
    *) log::warn "Unknown output to craft | output='$output'" ; return 1 ;;
  esac
}

function craft_max() {
  local -r item="${1:?}"
  local item_nr
  item_nr="$(item_obj::num "$item")"

  # Fetch recipe
  local -r recipe="$(jq -c -r '.["'"$item_nr"'"]' "./scraped/item_number_to_recipe.json")"
  if [ "$recipe" == "null" ]; then
    log::err "No recipe for this item"
    return 1
  fi
  log::debug "We know how to craft item | item='$item' item_nr='$item_nr' recipe='$recipe'"

  # Do some math to figure out how many we can craft
  # We check how many items we can craft in terms of inventory space
  # Then we check in terms of materials we have
  if ! FARMRPG_MAX_INVENTORY="$(item::inventory::from_name "iron")"; then
    log::err "Could not find max inventory"
    return 1
  fi

  local -r count="$(python3 << EOF
# Load all the data into python
import json
recipe = json.loads('$recipe')
inventory = json.loads('$(inventory)')

# Figure out how many we can craft to hit max inventory
want_craft_inventory = int(($FARMRPG_MAX_INVENTORY - inventory.get('$item_nr', 0)) / $FARMRPG_CRAFTING_BOOST)

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
