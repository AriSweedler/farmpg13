function buy() {
  # Parse args
  if ! item_id="$(item::name_to_num "$1")"; then
    log::err "Failed to get item ID"
    exit 1
  fi
  local -r quantity="${2:?How many to buy}"

  local -r output="$(worker "go=buyitem" "id=${item_id}" "qty=${quantity}")"

  # Validate output
  if [ "$output" == "success" ]; then
    log::info "Bought successfully | item='$1/$item_id' quantity='$quantity' output='$output'"
  elif [ "$output" == "error" ]; then
    log::err "Failed to buy | output='$output'"
    exit 1
  elif (( output < quantity )) && (( output > 0 )); then
    local -r max_amount="$output"
    log::debug "You tried to buy too many. We will just purchase up to the max amount | max_amount='$max_amount'"
    buy "$1" "$max_amount"
  else
    log::warn "Unknown output to buy | output='$output'"
    exit 1
  fi
}

function sell() {
  # Parse args
  if ! item_id="$(item::name_to_num "$1")"; then
    log::err "Failed to get item ID"
    exit 1
  fi
  local -r quantity="${2:?How many to sell}"

  # Do work
  local output
  if ! output="$(worker "go=sellitem" "id=${item_id}" "qty=${quantity}")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi

  # Validate output
  if (( output > 0 )); then
    log::info "Sold successfully | item='$1/$item_id' quantity='$quantity' output='$output'"
  elif [ "$output" == "0" ]; then
    log::err "Sold for 0 ? | output='$output' output='$output'"
    exit 1
  elif [ "$output" == "error" ]; then
    log::err "Failed to sell | output='$output'"
    exit 1
  else
    log::warn "Unknown output to sell | output='$output'"
    exit 1
  fi
}

function sell_cap::one() {
  local -r item_name="$(echo "${1:?}" | tr '-' '_')"
  local -r item_nr="$(item::name_to_num "$item_name")"
  sell_cap::one::nr "$item_nr"
}

function sell_cap::one::nr() {
  local -r item_nr="${1:?}"
  local -r qty="$(jq -r '.["'"$item_nr"'"]' <<< "$(inventory)")"
  if [ "$qty" == "null" ] || (( qty <= 0 )); then
    log::err "Do not have any item to sell | item='$item_name' qty='$qty'"
    exit 1
  fi
  sell "$item_name" "$qty"
}

function sell_cap() {
  local item_nr
  for item_nr in $(
    jq -r --arg inv_cap "$FARMRPG_MAX_INVENTORY" 'to_entries[] | select(.value >= ($inv_cap|tonumber)) | .key' <(inventory)
  ); do
    item_name="$(item::num_to_name "$item_nr")"
    # Skip keepable items
    case "$(_sale_decision "$item_name")" in
      keep) log::debug "Item is at capacity but is keepable | item_nr='$item_nr' item_name='$item_name'" ;;
      sell_some)
        log::info "Item is at capacity - selling half | item_nr='$item_nr' item_name='$item_name'"
        sell "$item_name" "$(( FARMRPG_MAX_INVENTORY / 2 ))"
        ;;
      unknown)
        log::warn "Item is at capacity - selling half | item_nr='$item_nr' item_name='$item_name'"
        sell "$item_name" "$(( FARMRPG_MAX_INVENTORY / 2 ))"
        ;;
      sell_all)
        log::info "Item is at capacity - selling all | item_nr='$item_nr' item_name='$item_name'"
        sell "$item_name" "$FARMRPG_MAX_INVENTORY"
        ;;
    esac
  done
}

function _sale_decision() {
  case "$1" in
    straw|minnows|board|blue_dye|iron|nails|rope|twine|gummy_worms|sandstone) echo "keep" ;;
    lantern|plumbfish|barracuda|spiral_shell) echo "sell_all" ;;
    serpent_eel|sea_catfish|swordfish) echo "sell_some" ;;
    *) echo "unknown" ;;
  esac
  return 1
}
