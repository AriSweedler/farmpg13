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
