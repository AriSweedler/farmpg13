function buy() {
  # Parse args
  if ! item_id="$(item_obj::num "$1")"; then
    log::err "Failed to get item ID"
    return 1
  fi
  local -r quantity="${2:?How many to buy}"

  local -r output="$(worker "go=buyitem" "id=${item_id}" "qty=${quantity}")"

  # Validate output
  case "$output" in
    success) log::info "Bought successfully | item='$1/$item_id' quantity='$quantity'" ; return 0;;
    error) log::err "Failed to buy" ; return 1 ;;
    "") log::err "Empty output to 'buy'" ; return 1 ;;
  esac

  if (( output < quantity )) && (( output >= 0 )); then
    local -r max_amount="$output"
    log::debug "You tried to buy too many. We will just purchase up to the max amount | max_amount='$max_amount'"
    buy "$1" "$max_amount"
  else
    log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'"
    return 1
  fi
}

function sell() {
  # Parse args
  local item_name item_obj item_nr
  item_name="${1:?}"
  item_obj="$(item::new::name "$item_name")"
  if ! item_nr="$(item_obj::num "$1")"; then
    log::err "Failed to get item ID"
    return 1
  fi
  local -r quantity="${2:?How many to sell}"

  # Do work
  local output
  if ! output="$(worker "go=sellitem" "id=${item_nr}" "qty=${quantity}")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  case "$output" in
    0) log::err "Sold for 0? | output='$output'" ; return 1;;
    error) log::err "Failed to sell | item='$item_name/$item_nr' quantity='$quantity' output='$output'" ; return 1;;
  esac
  if (( output > 0 )); then
    log::info "Sold successfully | item='$item_name/$item_nr' quantity='$quantity' output='$output'"
    return
  fi

  log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'"
  return 1
}

function sell_max() {
  local -r item_name="$(echo "${1:?}" | tr '-' '_')"
  local -r item_nr="$(item_obj::num "$item_name")"
  sell_cap::one::nr "$item_nr"
}

function sell_cap::one::nr() {
  local -r item_nr="${1:?}"
  local -r qty="$(jq -r '.["'"$item_nr"'"]' <<< "$(inventory)")"
  if [ "$qty" == "null" ] || (( qty <= 0 )); then
    log::err "Do not have any item to sell | item='$item_name' qty='$qty'"
    return 1
  fi
  sell "$item_name" "$qty"
}

function sell_cap() {
  local item_nr item_obj item_name
  for item_nr in $(
    jq -r --arg inv_cap "$FARMRPG_MAX_INVENTORY" 'to_entries[] | select(.value >= ($inv_cap|tonumber)) | .key' <(inventory)
  ); do
    item_obj="$(item::new::number "$item_nr")"
    item_name="$(item_obj::name "$item_obj")"
    # Skip keepable items
    case "$(_sale_decision "$item_name")" in
      keep) log::debug "Item is at capacity but is keepable | item_nr='$item_nr' item_name='$item_name'" ;;
      sell_some)
        log::info "Item is at capacity - selling half | item_nr='$item_nr' item_name='$item_name'"
        sell "$item_name" "$(( FARMRPG_MAX_INVENTORY / 2 ))"
        ;;
      unknown)
        log::warn "Item is at capacity - UNCERTAIN how to handle it | item_nr='$item_nr' item_name='$item_name' fix='sh_lib/market.sh'"
        ;;
      sell_all)
        log::info "Item is at capacity - selling all | item_nr='$item_nr' item_name='$item_name'"
        sell "$item_name" "$FARMRPG_MAX_INVENTORY"
        ;;
    esac
  done
  log::info "Inventory is looking good!"
}

function sell::all_but_one() {
  local item_name item_obj
  item_name="${1:?}"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not convert name to obj | item_name='$item_name'"
    return 1
  fi

  local i_have
  if ! i_have="$(item_obj::inventory "$item_obj")"; then
    log::err "Could not figure out how much feed we have"
    return 1
  fi
  sell "$item_obj" $((i_have-1))
}

function sell::make_space() {
  local item_name item_obj
  item_name="${1:?}"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not convert name to obj | item_name='$item_name'"
    return 1
  fi

  local incoming="${2:?How many empty inv spaces do we need}"

  local i_have
  if ! i_have="$(item_obj::inventory "$item_obj")"; then
    log::err "Could not figure out how much feed we have"
    return 1
  fi

  local desired_amount to_sell
  desired_amount=$(( FARMRPG_MAX_INVENTORY - incoming ))
  to_sell=$(( i_have - desired_amount ))
  log::debug "Selling item to make sure we have empty spaces | item_obj='$item_obj' empty_space='$incoming' i_have='$i_have' desired_amount='$desired_amount' to_sell='$to_sell'"
  if (( to_sell > 0 )); then
    sell "$item_obj" "$to_sell"
  fi
  log::info "We have enough inventory space for additional amt of item | item_obj='$item_obj' amt='$incoming'"
}

function _sale_decision() {
  case "$1" in
    *_seeds |*_spores | apple | orange | lemon | grapes | eggs | milk | minnows \
    | gummy_worms | worms | board | iron | nails | rope | twine | steel | broom \
    | glass_bottle | iron_ring | straw | wood | coal | stone | sandstone | blue_feathers \
    | feathers | blue_dye | bottle_rocket | bird_egg | flour | peppers | potato \
    | tomato | green_diary | horseshoe | red_twine | sturdy_box | sweet_root \
    | thorns | white_parchment | mealworms | mushroom | mushroom_paste | slimestone \
    | steel_wire | grubs | carrot | eggplant | hops | leek | onion | 4_leaf_clover \
    | ruby | spoon | axe | arrowhead | blue_gel | bucket | essence_of_slime | feed \
    | hammer | red_berries | cabbage | yarn | steak | chum | butter_churn ) echo "keep" ;;

    lantern | fancy_pipe | studry_shielf | green_chromis | small_prawn \
    | swordfish | barracuda | sea_catfish | plumbfish | spiral_shell | serpent_eel | ruby_coral \
    ) echo "sell_all" ;;

    fluorifish | green_jellyfish | jellyfish \
    | marlin | blue_catfish | bone_fish | sunfish | trout | globber | ruby_fish \
    | shrimp | skipjack | stingray | blue_tiger_fish \
    | clam_shell | clownfish | conch_shell | red_starfish | seahorse | starfish \
    | blue_crab | blue_sea_bass | blue_shell | mackerel | lemon_quartz_ring \
    ) echo "sell_some" ;;
    *) echo "unknown" ;;
  esac
  return 1
}

function chore::sell() {
  #set -x
  local remaining="${1:?}"
  local i_have
  while (( remaining > 0 )); do
    read -ra trashy <<< "$(_echo_generatable_items | tr '\n' ' ')"
    for item_obj in "${trashy[@]}"; do
      i_have=$(item_obj::inventory "$item_obj") || continue
      if (( i_have > remaining )); then
        sell "$item_obj" "$remaining"
        return
      fi
      # sell "$item_obj" "$i_have"
      remaining=$(( remaining - i_have ))
    done
    log::err "We are gunna have to wait for more generatable items"
    sleep $((60 * 10))
  done
}
