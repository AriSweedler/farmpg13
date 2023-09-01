function gm::pet_chickens() {
  local output
  if ! output="$(worker "go=petallchickens")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully pet all the chickens :3" ;;
    *) log::err "Failed to pet chickens" ; return 1 ;;
  esac
}

function gm::pet_cows() {
  local output
  if ! output="$(worker "go=petallcows")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully pet all the cows OwO" ;;
    *) log::err "Failed to pet cows (L)" ; return 1 ;;
  esac
}

function gm::feed_pigs() {
  local output
  if ! output="$(worker "go=feedallpigs")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully fed all the pigs OwO" ;;
    *) log::err "Failed to feed piggies (L)" ; return 1 ;;
  esac

  # Place corn in the feeder
  local i_have_feed i_want_feed i_macerate_corn
  if ! i_have_feed="$(item_obj::inventory "feed")"; then
    log::err "Could not figure out how much to donate"
    return 1
  fi
  i_want_feed=$((FARMRPG_MAX_INVENTORY - 100))
  loaded_feed=0 # TODO scrape to learn how much we have loaded already
  i_macerate_corn=$(( (i_want_feed-i_have_feed-loaded_feed) / 2))
  feed_mill::load corn "$i_macerate_corn"
}

function gm::work_storehouse() {
  local output
  if ! output="$(worker "go=work" "id=280551")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully worked in the storehouse" ;;
    *) log::err "Failed to work in the storehouse" ; return 1 ;;
  esac

  inventory::update_max_inventory
}

function gm::rest_farmhouse() {
  local output
  if ! output="$(worker "go=rest" "id=280551")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully rested in the farmhouse" ;;
    *) log::err "Failed to rest in the farmhouse" ; return 1 ;;
  esac
}

function gm::spinwheel() {
  local output
  if ! output="$(worker "go=spinfirst")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  log::info "Wheel spin results: '$(tr '\n' ' ' <<< "$output")'"
}

function gm::orchard() {
  # Craft for the orchard
  craft_max "glass_orb"
  craft_max "glass_bottle"
  craft_max "apple_cider"
  craft_max "orange_juice"
  craft_max "lemonade"
  craft_max "arnold_palmer"
  craft_max "grape_juice"
  craft_max "wine"
}

function gm::items() {
  # Pets
  collect_pet_items

  craft_max "twine"
  craft_max "iron_ring"
  craft_max "cooking_pot"
  craft_max "white_parchment"
  craft_max "toilet_paper"
  craft_max "inferno_sphere"
  craft_max "lava_sphere"
  craft_max "red_dye"
  craft_max "red_shield"
  sell_max "red_shield"
  sell_max "steak_kabob"
}

function gm::items::money() {
  craft_max "sturdy_bow"
  craft_max "sturdy_shield"
  craft_max "fancy_pipe"
  craft_max "lantern"
  sell_max "sturdy_bow"
  sell_max "sturdy_shield"
  sell_max "fancy_pipe"
  sell_max "lantern"
}

function gm::raptors() {
  local output
  if ! output="$(worker "go=incuallraptors")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully incubated/pet raptors" ;;
    *) log::err "Failed to incubate raptors" ; return 1 ;;
  esac
}

function gm::wishing_well() {
  # Parse args
  if ! item_id="$(item_obj::num "$1")"; then
    log::err "Failed to get item ID"
    return 1
  fi

# # YES items
  # You have thrown <strong>9</strong> things into the well today
# # NO items
  # todo...
  local thrown cap
  cap=9
  thrown="$(farmpg13::page "well.php" \
    | grep -o 'thrown\(.*\)things into the well' \
    | awk -F'[><]' '{print $3}')"
  if (( thrown >= cap )); then
    log::warn "We used all our wishing well today | thrown='$thrown'"
    return
  fi

  # Compute how many to throw
  local throw_num=$((cap - thrown))

  # Do work
  local output
  if ! output="$(worker "go=tossmanyintowell" "id=$item_id" "amt=$throw_num")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  case "$output" in
    "Gold spent for") log::err "Spent gold at the wishing well. This is probably a bug" ;;
    *) log::info "Wished in the well | output='$output'" ;;
  esac
}

function gm::fishing() {
  craft_max "twine"
  craft_max "rope"
  craft_max "fishing_net"
  craft_max "large_net"
  craft_max "iron_ring"
  craft_max "twine"
  craft_max "rope"
}

function gm::friends() {
  friendship::thomas
  friendship::roomba
  friendship::buddy
}

function captain::goodmorning() {
  # Farm stuff
  gm::pet_chickens
  gm::pet_cows
  gm::feed_pigs
  gm::raptors
  gm::work_storehouse
  gm::rest_farmhouse
  captain::cellar

  # Use and replenish items
  gm::orchard
  gm::items
  gm::fishing

  # Town stuff
  gm::spinwheel
  gm::wishing_well "salt" # spiked_shell
  #vault::crack

  # misc
  gm::friends
  mastery::claim::all
  captain::chores
}
