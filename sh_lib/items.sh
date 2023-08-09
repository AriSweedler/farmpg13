function item_obj::num() {
  local item_name="${1:?}"

  local num
  if ! num="$(jq -r '.["'"$item_name"'"]' "./scraped/item_to_number.json")"; then
    log::err "Could not run jq command to conver item name to num"
    return 1
  fi
  if [ "$num" == "null" ]; then
    log::err "Could not turn item into number | num='$num'"
    return 1
  fi

  printf "%s" "$num"
}

function item::name_to_seed_name() {
  local -r item_name="$(echo "${1:?}" | tr '[:upper:]-' '[:lower:]_')"
  case "$item_name" in
    mushroom) echo "mushroom_spores" ;;
    pepper|eggplant|tomato|carrot|pea|cucumber\
    |radish|onion|hops|potato|leek|watermelon\
    |corn|cabbage|pumpkin|wheat|gold_pepper\
    |gold_carrot|gold_pea|gold_cucumber|cotton\
    |broccoli|gold_eggplant|sunflower|pine|beet\
    |mega_beet|mega_sunflower|rice|spring\
    |mega_cotton) echo "${item_name}_seeds" ;;
    *) log::err "Unknown item - cannot convert to seeds | item_name='$item_name'"; return 1 ;;
  esac
}

function item::name_to_location() {
  local -r item_name="$(item::new::name "${1:?}")"
  local -r loc="$(jq -r '.["'"$item_name"'"]' "./scraped/item_to_location.json")"
  if [ "$loc" == "null" ]; then
    log::err "Could not turn item into a location | loc='$loc' item_name='$item_name'"
    printf "0"
    return 1
  fi

  printf "%s" "$loc"
}

function item::location_to_num() {
  local -r loc="$(item::new::name "${1:?}")"
  local -r num="$(jq -r '.["'"$loc"'"]' "./scraped/location_to_number.json")"
  if [ "$num" == "null" ]; then
    log::err "Could not turn item into a location | num='$num'"
    printf "0"
    return 1
  fi

  printf "%s" "$num"
}

function item::inventory::from_name() {
  local -r item_name="$(item::new::name "${1:?Give an item name to find inventory for}")"

  local item_nr
  if ! item_nr="$(item_obj::num "$item_name")"; then
    log::err "Failed to get number for item | item='$item_name'"
    return 1
  fi

  local ans
  if ! ans="$(jq -r '.["'"$item_nr"'"]' <<< "$(inventory)")"; then
    log::err "Could not read how many items were in inventory | item_name='$item_name' item_nr='$item_nr'"
    return 1
  fi

  if [ "$ans" == "null" ]; then
    log::debug "There is no key in inventory - answering '0' | key='$item_nr' item_name='$item_name'"
    printf "0"
    return 0
  fi

  # Return success
  echo "$ans"
}

function item::number_to_name() {
  local -r item_nr="${1:?}"
  jq -r \
    --arg value "$item_nr" \
    'to_entries[] | select(.value == $value) | .key' \
    "./scraped/item_to_number.json"
}

function item::ensure_have() {
  local -r item_name="$(item::new::name "${1:?}")"
  local -r i_want="${2:?}"

  # Check user state
  local i_have
  if ! i_have="$(item::inventory::from_name "$item_name")"; then
    log::err "Failed to read inventory state"
    return 1
  fi

  # Determine if we need to do work
  if (( i_have >= i_want )); then
    log::debug "We have enough | item='$item_name' i_have='$i_have'"
    return
  fi

  # Do work
  log::info "We need to procure | item='$item_name' i_want='$i_want' i_have='$i_have'"
  if ! item::procure "$item_name" "$i_want"; then
    log::err "Failed to procure item | item='$item_name'"
    return 1
  fi
}

function item::procure() {
  local -r item_name="$(item::new::name "${1:?}")"
  local i_have i_want i_get_more
  i_have="$(item::inventory::from_name "$item_name")"
  i_want="${2:?}"

  # Exit early if we can
  i_get_more=$(( i_want - i_have ))
  if (( i_have >= i_want )); then
    log::warn "Tried to procure item when we already have enough | item='$item_name' i_want='$i_want' i_have='$i_have'"
    return 0
  fi

  local -r procure_method="$(item::procure::method "$item_name")"
  case "$(item::procure::method "$item_name")" in
    farm)
      log::info "Procuring more via farming | item_name='$item_name'"
      while (( i_have < i_want )); do
        if ! planty "$item_name"; then
          log::err "Failed to plant for procurement | item_name='$item_name'"
          return 1
        fi
        i_have="$(item::inventory::from_name "$item_name")"
      done
      ;;
    craft)
      log::info "Procuring more via crafting | item_name='$item_name'"
      # TODO turn an item into a recipe and turn the recipe into a multiplier
      # and ensure have all those items
      craft "$item_name" "$i_get_more"
      ;;
    buy)
      log::info "Procuring more via buying | item_name='$item_name' i_get_more='$i_get_more'"
      buy "$item_name" "$i_get_more" ;;
    explore)
      log::info "Procuring more via exploring | item_name='$item_name'"
      # Set up state so we know how many to get
      i_have="$(item::inventory::from_name "$item_name")"
      explore --item "$item_name"

      # Loop until we have enough
      i_have="$(item::inventory::from_name "$item_name")"
      while ((i_have < i_want)); do
        # Explore, drinking OJ if needed
        for _ in {1..100}; do
          if ! explore --item "$item_name"; then
            if ! drink::orange_juice 1; then
              log::err "Could not drink orange juice"
              return 1
            fi
          fi
        done
        i_have="$(item::inventory::from_name "$item_name")"
      done
      ;;
    fish)
      log::warn "TODO Fishing not implemented yet"
      return 1
      ;;
    patience)
      log::warn "TODO you just need to wait about this one"
      return 1
      ;;
    feedmill_corn)
      local mill_corn=$(( (i_get_more+1) / 2 ))
      feed_mill::load "corn" "$mill_corn"
      ;;
    unknown)
      log::warn "It is not known how to procure this item. You have to update ${BASH_SOURCE[0]} | item='$item_name'"
      return 1;;
    *)
      log::err "Unknown procure method | item='$item_name' procure_method='$procure_method'"
      return 1
      ;;
  esac
}

function item::procure::method() {
  local -r item_name="${1:?}"

  case "$item_name" in
    worms|*_seeds|*_spores) echo "buy" ;;
    pepper|eggplant|tomato|carrot|pea|cucumber\
    |radish|onion|hops|potato|leek|watermelon\
    |corn|cabbage|pumpkin|wheat|gold_pepper\
    |gold_carrot|gold_pea|gold_cucumber|cotton\
    |broccoli|gold_eggplant|sunflower|pine|beet\
    |mega_beet|mega_sunflower|rice|spring\
    |mega_cotton|mushroom) echo "farm" ;;
    mushroom_paste) item::ensure_have mushroom 320 && echo "craft" ;; # TODO procure pre-reqs in body of 'craft', NOT in body of 'procure'
    feed) echo "feedmill_corn" ;;
    raptor_egg) echo "explore" ;;
    *) echo "unknown" ;;
  esac
}
