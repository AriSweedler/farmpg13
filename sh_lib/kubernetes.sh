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
    # TODO BETTER_CRAFT_MAX better options here?
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
        log::info "We are procuring | $(ceh::logCtx)"
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
  # TODO BETTER_CRAFT_MAX we may not be able to craft as many as we want at once - use recipe fetching to craft less than needed? Or do crafting math....

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
  # Figure out where to fish
  local loc
  loc="$(item_obj::get_fishing_location "$item_obj")"

  # We *could* API fish with mealworms, but instead... just:
  # Cast a net there
  fish::net::one "$loc"
}

################################################################################
############################# convenience functions ############################
################################################################################

# Currently, this is supposed to be left on
#
# TODO change it to wanna run every minute. We will check if stuff needs to be
# harvested and such
function captain::crop() {
  local crops
  read -ra crops <<< "$(_echo_long_crops | tr '\n' ' ') $(_echo_short_crops | tr '\n' ' ')"

  local crop_obj desired_count
  for crop_obj in "${crops[@]}"; do
    # Determine how many we need to have to stop growing this crop
    desired_count=$(python -c "import math; print(math.ceil($FARMRPG_MAX_INVENTORY - $FARMRPG_FARMING_BOOST*$FARMRPG_PLOTS))")
    desired_count_mega=$(python -c "import math; print(math.ceil($FARMRPG_MAX_INVENTORY - 10*$FARMRPG_FARMING_BOOST*$FARMRPG_PLOTS))")
    if item_obj::is_crop::mega "$crop_obj"; then
      desired_count=$desired_count_mega
    fi

    # Grow until we have enough
    captain::ensure_have "$crop_obj" "$desired_count"
    captain::ensure_have "mushroom" "$desired_count_mega"
  done
}

function captain::paste() {
  local paste_items
  paste_items=(
    "amber_cane"
    "aquamarine_ring"
    "axe"
    "canoe"
    "emerald_ring"
    "fancy_drum"
    "fancy_guitar"
    "garnet_ring"
    "green_diary"
    "hourglass"
    "leather_diary"
    "lemon_quartz_ring"
    "mystic_ring"
    "purple_diary"
    "ruby_ring"
    "shimmer_ring"
    "shovel"
    "sturdy_bow"
    "sturdy_sword"
  )

  # Put mushroom_paste in the craftworks and grow a bunch of mushrooms. Try to
  # spend all the paste, then grow some more.
  craftworks "mushroom_paste" "twine" || return 1
  desired_count=$(python -c "import math; print(math.ceil($FARMRPG_MAX_INVENTORY - 10*$FARMRPG_FARMING_BOOST*$FARMRPG_PLOTS))")
  while (( "$(item_obj::inventory "mushroom")" < desired_count )); do
    captain::ensure_have "mushroom" "$desired_count"
    for pi in "${paste_items[@]}"; do
      craft_max::tree "$pi"
    done
  done
}

function captain::nets() {
  craft_max::tree "large_net"
  fish::net::all
}

# shellcheck disable=SC1102,SC2086
captain::kuber() {
  local now ts_loop_time sleep_seconds
  now=$(date +'%s')
  ts_loop_time=$now
  local next_ts_explore=0 next_ts_cook=0 next_ts_workshop=0 next_ts_gm=0
  local MINUTES="* 60" HOURS="* 60 * 60"
  while true; do
    # If now is before our ts_loop_time time then we sleep
    now=$(date +'%s')
    log::debug "[KUBER] Now | now='$now' ts_loop_time='$ts_loop_time'"
    if (( now < ts_loop_time )); then
      sleep_seconds=$(( ts_loop_time - now ))
      log::debug "[KUBER] Sleeping | sleep_seconds='$sleep_seconds'"
      sleep "$sleep_seconds"
    fi
    ts_loop_time=$(( ts_loop_time + 1 $MINUTES ))

    # Run this every 20 minutes
    # If now is after our next_ts_explore time then we explore
    now=$(date +'%s')
    if (( now > next_ts_explore )); then
      next_ts_explore=$(( now + 20 $MINUTES ))
      log::debug "[KUBER] Explore | next_ts_explore='$next_ts_explore'"
      captain::explore::xp # TODO don't just explore XP, but actually decide where to go
    fi

    # Run this every 2 minutes
    now=$(date +'%s')
    if (( now > next_ts_cook )); then
      next_ts_cook=$(( now + 2 $MINUTES ))
      log::debug "[KUBER] Cook | next_ts_cook='$next_ts_cook'"
      captain::cook
    fi

    # Run this every 10 min
    now=$(date +'%s')
    if (( now > next_ts_workshop )); then
      next_ts_workshop=$(( now + 10 $MINUTES ))
      log::debug "[KUBER] Workshop crafting | next_ts_workshop='$next_ts_workshop'"
      captain::workshop
    fi

    # Run this every N minutes
    # TODO monitor crops
    # Like... harvest them
    # Choose what to plant
    # Etc.

    # Run this once a day
    now=$(date +'%s')
    if (( now > next_ts_gm )); then
      next_ts_gm=$(( now + 24 $HOURS ))
      log::debug "[KUBER] Goodmorning | next_ts_gm='$next_ts_gm'"
      captain::goodmorning
    fi
  done
}
