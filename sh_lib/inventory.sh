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
