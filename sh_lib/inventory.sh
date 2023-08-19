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
