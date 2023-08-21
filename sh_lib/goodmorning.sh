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

  # Place broccoli in the feeder
  # feed_mill::load broccoli 1
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

function gm::use_grape_juice() {
  local -r plant_obj="$(item::new::name "beet")"
  local -r seed_obj="$(item_obj::seed "$plant_obj")"
  local -r qty=$((2*FARMRPG_PLOTS))
  if ! captain::ensure_have "$seed_obj" "$qty"; then
    log::err "Could not ensure that we have enough seeds for grapejuice boost | seed_obj='$seed_obj' qty='$qty'"
    return 1
  fi
  harvest

  local gj_uses=2
  log::info "Using grapejuice on plant | plant='$plant_obj' seed='$seed_obj' gj_uses='$gj_uses'"
  (set -e
  while (( gj_uses > 0 )); do
    plant "$plant_obj"
    drink::grape_juice
    harvest
    ((gj_uses--))
  done)
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

  # Place wine in the cellar
  # gm::wine
}

function gm::explore() {
  # Use OJ and then apple cider at locations
  # Eat an onion soup
  :
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

function gm::wine() {
  craft_max "wine"
  if ! wine_i_have="$(item_obj::inventory "wine")"; then
    log::err "Failed to read how much win we have"
    return 1
  fi

  # Store all the wine we have
  while ((wine_i_have-- > 0)); do
    cellar::store_wine
  done
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
  # TODO build safeguard to not spend gold

  # Parse args
  if ! item_id="$(item_obj::num "$1")"; then
    log::err "Failed to get item ID"
    return 1
  fi

  local output
  if ! output="$(worker "go=tossmanyintowell" "id=$item_id" "amt=9")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    "Gold spent for") log::err "WHY THE FUCK DID YOU DO THIS" ;;
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

function goodmorning() {
  # Farm stuff
  gm::pet_chickens
  gm::pet_cows
  gm::feed_pigs
  gm::raptors
  gm::work_storehouse
  gm::rest_farmhouse
  #gm::use_grape_juice

  # Use and replenish items
  gm::orchard
  gm::items
  gm::fishing
  gm::explore

  # Town stuff
  gm::spinwheel
  gm::wishing_well "salt" # spiked_shell
  #vault::crack

  # Friendship
  gm::friends
}

function gm::friends() {
  friendship::thomas
  friendship::roomba
}
