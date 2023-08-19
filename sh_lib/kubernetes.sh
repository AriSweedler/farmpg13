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
  while (( i_have < i_want )); do
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
    # Update state
    i_have="$(item_obj::inventory "$item_obj")"
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

# Ensure we have seeds
# Ensure we can plant. If necessary: {wait, harvest}
# Plant, wait, harvest
function captain::_delegate::farm() {
  local -r plant_obj="${item_obj:?}"

  # Ensure we have enough seeds
  local seed_obj
  seed_obj="$(item_obj::seed "$plant_obj")"
  if ! captain::ensure_have "$seed_obj" "$FARMRPG_PLOTS"; then
    log::err "Could not ensure that we have enough seeds | seed_obj='$seed_obj' want_to_have='$FARMRPG_PLOTS'"
    return 1
  fi

  # Ensure we can plant
  harvest
  local rc grow_time
  grow_time="$(plant "$plant_obj")"
  rc=$?
  while (( rc != 0 )); do
    if (( rc != 40 )); then
      log::err "Failed to plant | plant_obj='$plant_obj' rc=$rc"
      return 1
    fi
    seconds="$(time_until_farm_ready)"
    log::warn "Waiting for current plants to grow... | plant_obj='$plant_obj' seconds='$seconds'"
    sleep "$seconds"
    harvest
    grow_time="$(plant "$plant_obj")"
    rc=$?
  done

  # Error check
  if [ -z "$grow_time" ]; then
    log::err "No one set 'grow_time' for us"
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

  # Ensure we have enough seeds
  local seed_obj
  seed_obj="$(item_obj::seed "$plant_obj")"
  if ! captain::ensure_have "$seed_obj" "$FARMRPG_PLOTS"; then
    log::err "Could not ensure that we have enough seeds | seed_obj='$seed_obj' want_to_have='$FARMRPG_PLOTS'"
    return 1
  fi

  # Ensure we can plant
  harvest
  local rc grow_time
  grow_time="$(plant "$plant_obj")"
  rc=$?
  while (( rc != 0 )); do
    if (( rc != 40 )); then
      log::err "Failed to plant | plant_obj='$plant_obj' rc=$rc"
      return 1
    fi
    seconds="$(time_until_farm_ready)"
    log::warn "Waiting for current plants to grow... | plant_obj='$plant_obj' seconds='$seconds'"
    sleep "$seconds"
    harvest
    grow_time="$(plant "$plant_obj")"
    rc=$?
  done

  # Error check
  if [ -z "$grow_time" ]; then
    log::err "No one set 'grow_time' for us"
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
    if [ "$crop_obj" == "mushroom" ]; then
      desired_count=$(python -c "import math; print(math.ceil($FARMRPG_MAX_INVENTORY - 10*$FARMRPG_FARMING_BOOST*$FARMRPG_PLOTS))")
    fi

    # Grow until we have enough
    captain::ensure_have "$crop_obj" "$desired_count"
  done
}

function captain::paste() {
  craftworks "mushroom_paste"
  captain::ensure_have "mushroom" "$FARMRPG_PLOTS"
}
