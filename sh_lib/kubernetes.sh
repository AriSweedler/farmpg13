################################################################################
############################## The main functions ##############################
################################################################################
# Control loop. Keep calling 'procure' until we are done
function captain::ensure_have() {
  local procure_method
  function ceh::logCtx() {
    [ -n "$procure_method" ] && echo -n "procure_method='$procure_method' "
    echo -n "item_obj='$item_obj' i_have/i_want='$i_have/$i_want'"
  }

  local item_obj i_have i_want
  item_obj="$(item::new::name "${1:?}")"
  i_have="$(item_obj::inventory "$item_obj")"
  i_want="${2:?}"

  # Massage and validate args
  if (( i_want > FARMRPG_MAX_INVENTORY )); then
    # TODO better options here?
    log::warn "We cannot ask for more than the max inventory | i_want='$i_want' FARMRPG_MAX_INVENTORY='$FARMRPG_MAX_INVENTORY'"
    i_want="$FARMRPG_MAX_INVENTORY"
  fi

  # Exit early if we can
  if (( i_have >= i_want )); then
    if [ "$FARMRPG_ARGS" == "${FUNCNAME[0]} $*" ]; then
      log::info "We have enough | $(ceh::logCtx)"
    fi
    log::debug "We have enough | $(ceh::logCtx)"
    return
  fi

  # Do work
  log::info "We need to procure {{{ | $(ceh::logCtx)"
  while true; do
    # Figure out how to procure and delegate it
    procure_method="$(item_obj::procure_method "$item_obj")"
    case "$procure_method" in
      buy | craft | explore | explore_cider | farm_gj | farm | fish)
        if ! "captain::_delegate::$procure_method"; then
          log::err "Failed to delegate procurement of item }}} | $(ceh::logCtx)"
          return 1
        fi
        ;;
      patience) log::warn "You need to wait if you want more of this item }}} | $(ceh::logCtx)" ; return 1;;
      unknown) log::warn "It is not known how to procure this item. You have to update ${BASH_SOURCE[0]} }}} | $(ceh::logCtx)" ; return 1;;
      *) log::err "Unknown procure method }}} | $(ceh::logCtx) procure_method='$procure_method'" ; return 1;;
    esac

    # Update state and log
    i_have="$(item_obj::inventory "$item_obj")"
    (( i_have >= i_want )) && break
    log::info "We are procuring | $(ceh::logCtx)"
  done
  log::info "We have procured }}} | $(ceh::logCtx)"
}

################################################################################
############ The 'captain::_delegate::' functions cause side effects ###########
################################################################################
# After each step, we will be closer to having all the items we want
#
# Each of these functions implicitly accepts the following variables:
# * item_obj
# * i_want i_have

# Ensure we can plant
# Ensure we have seeds
# Plant it
# Return grow time
function captain::_delegate::_farm() {
  local -r plant_obj="${item_obj:?}"

  # Ensure we can plant
  if ! farmland::till; then
    log::err "Could not wait until plantable, something went wrong"
    return 1
  fi

  # Ensure we have enough seeds
  local seed_obj
  seed_obj="$(item_obj::seed "$plant_obj")"
  if ! captain::ensure_have "$seed_obj" "$FARMRPG_PLOTS"; then
    log::err "Could not ensure that we have enough seeds | seed_obj='$seed_obj' want_to_have='$FARMRPG_PLOTS'"
    return 1
  fi

  # Plant the plant
  local grow_time
  grow_time="$(plant "$plant_obj")"
  if [ -z "$grow_time" ]; then
    log::err "Failed to plant - could not figure out what 'grow_time' should be"
    return 1
  fi

  # Error check and return
  if [ -z "$grow_time" ]; then
    log::err "No one set 'grow_time' for us"
    return 1
  fi
  echo "$grow_time"
}

function captain::_delegate::farm() {
  local -r plant_obj="${item_obj:?}"

  # Plant
  local grow_time
  if ! grow_time="$(captain::_delegate::_farm "$plant_obj")"; then
    return 1
  fi

  # Wait for the plant to grow
  log::info "Waiting for plant to grow | item_obj='$item_obj'"
  sleep "$grow_time"
  log::info "Plant is grown | item_obj='$item_obj'"
  harvest
}

function captain::_delegate::farm_gj() {
  local -r plant_obj="${item_obj:?}"

  # Ensure we have enough grape juice
  if ! has_gj_uses_left; then
    log::warn "We do not have any grape juice left so we cannot procure via gj"
    return 1
  fi

  # Plant
  if ! captain::_delegate::_farm "$plant_obj" > /dev/null; then
    return 1
  fi

  # gj the crop
  drink::grape_juice
  harvest
}

# Ensure we have enough materials to craft this object
# Craft
function captain::_delegate::craft() {
  # Ensure we have enough materials to craft this object
  captain::_delegate::_fetch_recipe
  # TODO we may not be able to craft as many as we want at once - use recipe fetching to craft less than needed? Or do crafting math....

  # Craft
  local i_get_more
  i_get_more=$(( i_want - i_have ))
  craft "$item_obj" "$i_get_more"
}

# Quasi-inline
function captain::_delegate::_fetch_recipe() {
  # Find the recipe for the item
  local recipe
  if ! recipe="$(item_obj::recipe "$item_obj")"; then
    log::err "Failed to get recipe for object when delegating craft"
    return 1
  fi

  # Find the required items (the recipe gives the nr only)
  local ritem_nrs
  read -ra ritem_nrs <<< "$(jq -r 'keys[]' <<< "$recipe" | tr '\n' ' ')"

  # Ensure we have enough of the required items
  local i_get_more ritem_nr ritem_obj required_for_1_craft required
  i_get_more=$(( i_want - i_have ))
  additional_crafts=$(python -c "import math; print(math.ceil($i_get_more / $FARMRPG_CRAFTING_BOOST))")
  log::dev "additional_crafts=$additional_crafts"
  for ritem_nr in "${ritem_nrs[@]}"; do
    # Construct an item obj from the required item number
    ritem_obj="$(item::new::number "$ritem_nr")"
    required_for_1_craft="$(jq -r '."'"$ritem_nr"'"' <<< "$recipe")"
    required=$(( additional_crafts * required_for_1_craft ))
    log::dev "I need this item to craft with | ritem_obj='$ritem_obj' required='$required'"
    captain::ensure_have "$ritem_obj" "$required"
  done
}

# Buy
function captain::_delegate::buy() {
  local i_get_more=$(( i_want - i_have ))
  buy "$item_obj" "$i_get_more"
}

# Explore (without cider)
function captain::_delegate::explore() {
  remaining_stamina="$(explore::one --item "$item_obj")"
  if (( remaining_stamina == 0 )); then
    return 1
  fi
}

# Explore (with cider)
function captain::_delegate::explore_cider() {
  captain::ensure_have "apple_cider" 1
  explore --apple_cider --item "$item_obj"
}

# TODO
function captain::_delegate::fish() {
  log::warn "Not implemented yet"
  log::dev "Implement me (API fishing? Large nets?)"
  fish --item "$item_obj"
}

################################################################################
############################# convenience functions ############################
################################################################################

function captain::crop() {
  local crops
  read -ra crops <<< "$(_echo_long_crops | tr '\n' ' ') $(_echo_short_crops | tr '\n' ' ')"

  local crop_obj desired_count
  for crop_obj in "${crops[@]}"; do
    # Determine how many we need to have to stop growing this crop
    desired_count=$(python -c "import math; print(math.ceil($FARMRPG_MAX_INVENTORY - $FARMRPG_FARMING_BOOST*$FARMRPG_PLOTS))")
    if [ "$crop_obj" == "mushroom" ]; then # TODO write a "max desired" function for MEGA crops and include mushrooms in it
      desired_count=$(python -c "import math; print(math.ceil($FARMRPG_MAX_INVENTORY - 10*$FARMRPG_FARMING_BOOST*$FARMRPG_PLOTS))")
    fi

    # Grow until we have enough
    captain::ensure_have "$crop_obj" "$desired_count"
  done
}

function captain::paste() {
  craftworks "mushroom_paste" "twine"
  desired_count=$(python -c "import math; print(math.ceil($FARMRPG_MAX_INVENTORY - 10*$FARMRPG_FARMING_BOOST*$FARMRPG_PLOTS))")
  captain::ensure_have "mushroom" "$desired_count"
  # TODO figure out how to spend extra mushroom paste on crafting all the mushroom paste items...
  # * some are for optimal resource use (maximize gem value - paste is worht 500 added silverg)
  # * others are for holding (always have max shovels axes spoons etc)
  # * And still others are for selling (create and sell canoe)
  #
  # amber_cane
  # garnet_ring
  # aquamarine_ring
  # axe
  # canoe
  # emerald_ring
  # fancy_drum
  # fancy_guitar
  # green_diary
  # purple_diary
  # leather_diary
  # hourglass
  # lemon_quartz_ring
  # mystic_ring
  # ruby_ring
  # shimmer_ring
  # shovel
  # sturdy_bow
  # sturdy_sword
}

function captain::nets() {
  craft_max "twine"
  craft_max "rope"
  craft_max "fishing_net"
  craft_max "iron_ring"
  craft_max "large_net"
  fish::net::all
}

# TODO pick priorities and figure out how to explore once
# have a helper loop invoke it until we are done
# Helper loop will use all remaining stamina
# Make sure we are maxed out on mushroom paste, first
function captain::explore() {
  eat "onion_soup"
  drink::orange_juice::all

  local remaining_stamina
  while (( $(item_obj::inventory "glass_orb") < (FARMRPG_MAX_INVENTORY-100) )); do
    remaining_stamina="$(explore::one --apple_cider --item "glass_orb")"
    craft_max "glass_bottle"
    craft_max "cooking_pot"
    craft_max "magicite"
    explore::shed "magicite"
    if (( remaining_stamina < 1060 )); then
      return
    fi
  done

  while remaining_stamina="$(explore::one --apple_cider --loc "whispering_creek")"; do
    craft_max "apple_cider"
    craft_max "orange_juice"
    craft_max "lemonade"
    craft_max "garnet"
    craft_max "garnet_ring"
    craft_max "iron_ring"
    if (( $(item_obj::inventory "stone") < (100) )); then
      remaining_stamina="$(explore::one --apple_cider --item "glass_orb")"
      if (( remaining_stamina < 1060 )); then
        return
      fi
    fi
    craft_max "salt"
    craft_max "red_dye"
    craft_max "canoe"
    explore::shed "slimestone"
    explore::shed "blue_gel"
    explore::shed "red_berries"
    explore::shed "sour_root"
    explore::shed "thorns"
    if (( remaining_stamina < 1060 )); then
      return
    fi
  done
}
