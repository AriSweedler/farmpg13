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

  # Use all that extra stamina
  # explore --item glass_orb
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
  local -r plant="rice"
  local -r seed="$(item::name_to_seed_name "$plant")"
  local -r qty=$((2*FARMRPG_PLOTS))
  if ! item::ensure_have "$seed" "$qty"; then
    log::err "Could not ensure that we have enough seeds for grapejuice boost | seed='$seed' qty='$qty'"
    return 1
  fi
  harvest

  local gj_uses=2
  log::info "Using grapejuice on plant | plant='$plant' gj_uses='$gj_uses'"
  (set -e
  while (( gj_uses > 0 )); do
    plant "$plant"
    farm::use_grapejuice
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

function gm::items() {
  # Pets
  collect_pet_items

  # Craft for the orchard
  craft_max "glass_orb"
  craft_max "glass_bottle"
  craft_max "apple_cider"
  craft_max "orange_juice"
  craft_max "lemonade"
  craft_max "arnold_palmer"
  #craft "grape_juice" 2
  craft_max "wine"

  # Craft all the random objects and sell the proper ones
  craft_max "twine"
  craft_max "iron_ring"

  # gm::items::money

  craft_max "twine"
  craft_max "iron_ring"
  craft_max "cooking_pot"

  # Place wine in the cellar
  # gm::wine
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
  if ! wine_i_have="$(item::inventory::from_name "wine")"; then
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

function goodmorning() {
  # Farm stuff
  gm::pet_chickens
  gm::pet_cows
  gm::feed_pigs
  gm::raptors
  gm::work_storehouse
  gm::rest_farmhouse
  #gm::use_grape_juice

  # Crafting
  gm::items

  # Town stuff
  gm::spinwheel
  gm::wishing_well "bacon"
  #vault::crack
  
  # Friendship
  gm::friends
}

function gm::friends() {
  friendship::thomas
  friendship::roomba
}
