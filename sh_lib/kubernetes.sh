function captain::crop() {
  local crops=( $(_echo_crops) )

  if ! FARMRPG_MAX_INVENTORY="$(item::inventory::from_name "iron")"; then
    log::err "Failed to find max inventory"
    return 1
  fi

  local crop desired_count
  for crop in "${crops[@]}"; do
    # Determine how many we need to have to stop growing this crop
    desired_count=$(( FARMRPG_MAX_INVENTORY - FARMRPG_PLOTS ))
    if [ "$crop" == "mushroom" ]; then
      desired_count=$(( FARMRPG_MAX_INVENTORY - 10*FARMRPG_PLOTS ))
    fi

    # Grow until we have enough
    captain::ensure_have "$crop" "$desired_count"
  done
}

function captain::ensure_have() {
  function logCtx() {
    [ $procure_method ] && echo -n "procure_method='$procure_method' "
    [ $ari_var ] && echo -n "ari_var='$ari_var' "
    echo -n "item_obj='$item_obj' i_want/i_have='$i_want/$i_have'"
  }

  local -r item_obj="$(item::new::name "${1:?}")"
  local i_want="${2:?}"

  # Check user state
  local i_have
  if ! i_have="$(item::inventory::from_name "$item_obj")"; then
    log::err "Failed to read inventory state | item_obj='$item_obj'"
    return 1
  fi

  # Determine if we need to do work
  if (( i_have >= i_want )); then
    log::debug "We have enough | $(logCtx)"
    return
  fi

  # Do work
  log::info "We need to procure {{{ | $(logCtx)"
  if ! captain::_procure "$item_obj" "$i_want"; then
    log::err "Failed to procure item }}} | $(logCtx)"
    return 1
  fi
  log::info "We have procured }}} | $(logCtx)"
}

function captain::ensure_have::recipe() {
  log::dev "TODO implement me"
  return 1

  # Item
  local item_name item_obj item_nr
  item_name="${1:?Meal to eat}"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not convert arg to item object | arg='$1'"
    return 1
  fi
  item_nr="$(item_obj::num "$item_obj")"

  # Default value of '1'
  local amt
  amt="${2:-1}"
}

################################################################################
################################ procure methods ###############################
################################################################################

# Control loop. Keep calling 'procure' until we are done
function captain::_procure() {
  function logCtx() {
    [ $procure_method ] && echo -n "procure_method='$procure_method'"
    echo -n "item_obj='$item_obj' i_want/i_have='$i_want/$i_have'"
  }

  local -r item_obj="$(item::new::name "${1:?}")"
  i_have="$(item::inventory::from_name "$item_obj")"
  i_want="${2:?}"

  # Exit early if we can
  if (( i_have >= i_want )); then
    log::warn "Tried to procure item when we already have enough | $(logCtx)"
    return 0
  fi

  local -r procure_method="$(item_obj::procure_method "$item_obj")"
  while (( i_have < i_want )); do
    case "$procure_method" in
      buy | craft | explore | farm | fish)
        log::info "Procuring more via delegation | $(logCtx)"
        if ! "captain::_delegate::$procure_method"; then
          log::err "Failed to procure item | $(logCtx)"
          return 1
        fi
        ;;
      unknown) log::warn "It is not known how to procure this item. You have to update ${BASH_SOURCE[0]} | item_obj='$item_obj'" ; return 1;;
      *) log::err "Unknown procure method | item_obj='$item_obj' procure_method='$procure_method'" ; return 1;;
    esac
    i_have="$(item::inventory::from_name "$item_obj")"
  done
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
  local -r plant="${item_obj:?}"

  # Ensure we have enough seeds
  local seed_obj
  seed_obj="$(item_obj::seed "$plant")"
  if ! captain::ensure_have "$seed_obj" "$FARMRPG_PLOTS"; then
    log::err "Could not ensure that we have enough seeds | seed_obj='$seed_obj' want_to_have='$FARMRPG_PLOTS'"
    return 1
  fi

  # Ensure we can plant
  harvest
  local rc grow_time
  grow_time="$(plant "$plant")"
  rc=$?
  while (( rc != 0 )); do
    if (( rc != 40 )); then
      log::err "Failed to plant | plant='$plant' rc=$rc"
      return 1
    fi
    seconds="$(time_until_farm_ready)"
    log::warn "Waiting for current plants to grow... | plant='$plant' seconds='$seconds'"
    sleep "$seconds"
    harvest
    grow_time="$(plant "$plant")"
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

# Ensure we have enough materials to craft this object
# Craft max
function captain::_delegate::craft() {
  local i_get_more=$(( i_want - i_have ))
  if ! captain::ensure_have::recipe "$item_obj" "$i_get_more"; then
    log::err "Failed to get items for the recipe | target_item_obj='$item_obj'"
    return 1
  fi
  craft "$item_obj" "$i_get_more"
}

# Buy
function captain::_delegate::buy() {
  local i_get_more=$(( i_want - i_have ))
  buy "$item_obj" "$i_get_more"
}

# Explore (without cider)
function captain::_delegate::explore() {
  explore --item "$item_obj"
}

# Explore (wit cider)
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
