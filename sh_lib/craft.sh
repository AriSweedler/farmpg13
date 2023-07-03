function craft() {
  # Parse args
  if ! item_id="$(item::name_to_num "$1")"; then
    log::err "Failed to get item ID"
    exit 1
  fi
  local quantity="${2:?How many to craft}"
  # quantity=$(python -c "import math; print(math.ceil($quantity / $FARMRPG_CRAFTING_BOOST))")
  if (( quantity == 0 )); then
    log::err "You must craft at least 1 item"
    exit 1
  fi
  log::debug "Crafting 80% of desired output because of perks | quantity='$2' adjusted='$quantity'"

  # Do work
  local output
  if ! output="$(worker "go=craftitem" "id=${item_id}" "qty=${quantity}")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi

  # Validate output
  if [ "$output" == "success" ]; then
    log::info "Successfully crafted | item='$1/$item_id' quantity='$quantity'"
  elif [ "$output" == "cannotafford" ]; then
    log::err "Missing a resource necessary to craft this"
    exit 1
  else
    log::warn "Unknown output to craft | output='$output'"
    exit 1
  fi
}

function craft_max() {
  local -r item="${1:?}"
  local -r item_nr="$(item::name_to_num "$item")"

  # Fetch recipe
  local -r recipe='{"22": 1, "95": 3, "35": 2}'

  # Do some math to figure out how many we can craft
  local -r count="$(python3 << EOF
import json
recipe = json.loads('$recipe')
inventory = json.loads('$(inventory)')
want_craft_inventory = int(($FARMRPG_MAX_INVENTORY - inventory.get('$item_nr', 0)) / $FARMRPG_CRAFTING_BOOST)
want_craft_materials = dict()
for key, value in recipe.items():
    want_craft_materials[key] = 0
    if key not in inventory: want_craft_inventory = 0
    while inventory[key] > recipe[key]:
      inventory[key] -= recipe[key]
      want_craft_materials[key] += 1

import sys
want_craft_materials2=min(want_craft_materials.values())
ans = min(want_craft_inventory, min(want_craft_materials.values()))
print(f"{want_craft_inventory=} {want_craft_materials=} {want_craft_materials2=} {ans=}", file=sys.stderr)
print(ans)
EOF
)"
  craft "${item:?}" "${count:?}"
}
