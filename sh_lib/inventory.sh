function inventory() {
  # Return cached value if we can
  if [ -f "$FARMRPG_INVENTORY_CACHE" ]; then
    log::debug "Getting inventory | result=cached"
    cat "$FARMRPG_INVENTORY_CACHE"
    return
  fi

  # Otherwise, update the cache. Then return from it
  log::debug "Getting inventory | result=updating_cache"
  inventory::update_cache
  inventory
}

function inventory::clear_cache() {
  log::debug "Clearing inventory cache"
  rm -f "$FARMRPG_INVENTORY_CACHE"
}

function inventory::update_cache() {
  log::debug "Updating inventory cache"
  farmpg13::page "inventory.php" | python3 "./scraped/scripts/inventory.py" > "$FARMRPG_INVENTORY_CACHE"
}

function inventory::update_max_inventory() {
  # Update max inventory
  if ! FARMRPG_MAX_INVENTORY="$(item_obj::inventory "iron")"; then
    log::err "Failed to find max inventory"
    return 1
  fi

  log::info "Updating our max inventory | FARMRPG_MAX_INVENTORY='$FARMRPG_MAX_INVENTORY'"
  local from to
  from='_default_env "FARMRPG_MAX_INVENTORY" .*'
  to='_default_env "FARMRPG_MAX_INVENTORY" '"$FARMRPG_MAX_INVENTORY"
  sed -i '' "s/$from/$to/" sh_lib/globals.sh
}

function dashboard::inventory() {
  cmts=(
    "mushroom_paste"
    "scissors"
    "axe"
    "hammer"

    "coal"
    "black_powder"

    "straw"
    "twine"
    "rope"
    "yarn"
    "fishing_net"
    "large_net"

    "wood"
    "ladder"
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

    "fancy_guitar"
    "fancy_pipe"
    "wrench"
  )
  for item in "${cmts[@]}"; do
    count="$(item_obj::inventory "$item")"
    if (( count+20 > FARMRPG_MAX_INVENTORY )); then
      log::warn "You have count of item | item='$item' count='$count'"
    else
      log::info "You have count of item | item='$item' count='$count'"
    fi
  done
}
