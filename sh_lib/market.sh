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
  # TODO validate that this is an item_obj
  if ! item_id="$(item_obj::num "$1")"; then
    log::err "Failed to get item ID"
    return 1
  fi
  local -r quantity="${2:?How many to sell}"

  # Do work
  local output
  if ! output="$(worker "go=sellitem" "id=${item_id}" "qty=${quantity}")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  if (( output > 0 )); then
    log::info "Sold successfully | item='$1/$item_id' quantity='$quantity' output='$output'"
  elif [ "$output" == "0" ]; then
    log::err "Sold for 0 ? | output='$output' output='$output'"
    return 1
  elif [ "$output" == "error" ]; then
    log::err "Failed to sell | item='$1/$item_id' quantity='$quantity' output='$output'"
    return 1
  else
    log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'"
    return 1
  fi
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

function _sale_decision() {
  case "$1" in
    *_seeds |*_spores | apple | orange | lemon | grapes | eggs | milk | minnows \
    | gummy_worms | worms | board | iron | nails | rope | twine | steel | broom \
    | glass_bottle | iron_ring | straw | wood | coal | stone | sandstone | blue_feathers \
    | feathers | blue_dye | bottle_rocket | bird_egg | flour | peppers | potato \
    | tomato | green_diary | horseshoe | red_twine | sturdy_box | sweet_root \
    | thorns | white_parchment | mealworms | mushroom | mushroom_paste | slimestone \
    | steel_wire | grubs | carrot | eggplant | hops | leek | onion | 4-leaf_clover \
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
