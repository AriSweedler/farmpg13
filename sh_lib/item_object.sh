################################################################################
################################# constructors #################################
################################################################################
function item::new::name() {
  if (( $# != 1 )); then
    log::err "Wrong number of arguments | num_args=$#"
    return 1
  fi

  local normalized
  normalized="$(echo "$@" | tr '[:upper:]- ' '[:lower:]__')"
  if ! output="$(jq -e '.["'"$normalized"'"]' "./scraped/item_to_number.json")"; then
    log::err "Unknown item | item_name='$normalized' output='$output'"
    return 1
  fi

  printf "%s" "$normalized"
}

function item::new::number() {
  local -r num="${1:?}"
  if ! output="$(jq -e ".${num}" "./scraped/item_to_number.json")"; then
    log::err "Arg is not a number | arg='$num' output='$output'"
    return 1
  fi
  log::debug "The arg is a valid item number | arg='$num' output='$output'"

  local -r item_name=$(jq -r '. as $json | keys[] | select($json[.] == "'"${num}"'")' "./scraped/item_to_number.json")
  if [ -z "$item_name" ]; then
    log::err "Could not find item name for number $num"
    return 1
  fi

  printf "%s" "$item_name"
}

# When the system tells use that we have planted a crop, it will give a strange format of the name. Such as:
# * Peas
# * Tomatoes
# * Beets
#
# But we want the item name, as it shows up in the shop. So we normalize from them to us
# * peas
# * tomato
# * beet
function item::new::planted() {
  # Exit early if no args
  (( $# == 0 )) && return 1

  # lowercase
  normz="$(tr '[:upper:] ' '[:lower:]_' <<< "$1")"

  # Strip unneeded trailing s
  if [[ "${normz: -1}" == "s" ]]; then
    normz="${normz:0:${#normz}-1}"
  fi
  # Add the 's' back for these special cases
  case "$normz" in
    hop) normz="hops" ;;
    pea) normz="peas" ;;
    radishe) normz="radish" ;;
  esac

  # Fix the abnormal pluralization
  case "$normz" in
    potatoe) normz="potato" ;;
    tomatoe) normz="tomato" ;;
  esac

  # Validate that normz is actually a crop
  if ! item_obj::is_crop "$normz"; then
    log::err "Failed to normalize item name | normz='$normz'"
  fi
  echo "$normz"
}

################################################################################
#################################### getters ###################################
################################################################################
function item_obj::num() {
  local item_obj="${1:?}"

  local num
  if ! num="$(jq -r '.["'"$item_obj"'"]' "./scraped/item_to_number.json")"; then
    log::err "Could not run jq command to conver item name to num"
    return 1
  fi
  if [ "$num" == "null" ]; then
    log::err "Could not turn item into number | num='$num'"
    return 1
  fi

  printf "%s" "$num"
}

function item_obj::name() {
  local item_obj="${1:?}"
  printf "%s" "$item_obj"
}

function item_obj::seed() {
  local ans item_obj
  item_obj="${1:?}"

  # Special case the weird ones
  case "$item_obj" in
    mushroom) ans="mushroom_spores" ;;
    peas) ans="pea_seeds" ;;
    gold_peas) ans="gold_pea_seeds" ;;
    pine_tree) ans="pine_seeds" ;;
  esac
  if [ -n "$ans" ]; then
    echo "$ans"
    return
  fi

  # All the remaining crops
  if is_in_array "$item_obj" $(_echo_short_crops) $(_echo_long_crops) $(_echo_mega_crops) $(_echo_gold_crops); then
    echo "${item_obj}_seeds"
    return
  fi

  log::err "Unknown item - cannot convert to seeds | item_obj='$item_obj'"
  return 1
}

function has_gj_uses_left() {
  log::debug "Do we have gj uses left"
  page::panel_crops | grep -q 'Grape Juice'
  rc=$?
  if (( rc == 0 )); then
    log::debug "Answer is yes"
  else
    log::debug "Answer is no"
  fi
  return $rc
}

# Dereference an item into a method to procure it
function item_obj::procure_method() {
  local item_obj="${1:?}"

  if item_obj::is_buyable "$item_obj"; then
    echo "buy"
    return
  fi

  if item_obj::is_fishable "$item_obj"; then
    echo "fish"
    return
  fi

  if item_obj::is_crop "$item_obj"; then
    if item_obj::is_crop::short "$item_obj"; then
      echo "farm"
      return
    fi

    if item_obj::is_crop::mega "$item_obj"; then
      echo "farm_mega"
      return
    fi

    if item_obj::is_crop::long "$item_obj"; then
      if has_gj_uses_left; then
        echo "farm_gj"
        return
      fi

      log::loud_once "We want more of a long crop, but we are out of grape juice for the day. Wait until tomorrow"
      echo "patience"
      return
    fi

    log::err "This is neither a short crop nor a long crop. Is it golden? | item_obj='$item_obj'"
    echo "unknown"
    return 1
  fi

  if item_obj::is_explorable "$item_obj"; then
    # TODO what items do we wanna explore_cider for?
    echo "explore"
    return
  fi

  if item_obj::is_craftable "$item_obj"; then
    echo "craft"
    return
  fi

  echo "unknown"
  return 1
}

function item_obj::recipe() {
  local item_obj item_nr
  item_obj="${1:?}"
  if ! item_nr="$(item_obj::num "$item_obj")"; then
    log::err "Failed to get item number for crafting recipe | item_obj='$item_obj'"
    return 1
  fi

  if ! jq --exit-status --compact-output --raw-output '.["'"$item_nr"'"]' "./scraped/item_number_to_recipe.json"; then
    log::err "Failed to find recipe for item | item='$item_obj/$item_nr'"
    return 1
  fi
}

function item_obj::inventory() {
  local -r item_obj="$(item::new::name "${1:?Give an item name to find inventory for}")"

  local item_nr
  if ! item_nr="$(item_obj::num "$item_obj")"; then
    log::err "Failed to get number for item | item='$item_obj'"
    return 1
  fi

  local ans
  if ! ans="$(jq -r '.["'"$item_nr"'"]' <<< "$(inventory)")"; then
    log::err "Could not read how many items were in inventory | item_obj='$item_obj' item_nr='$item_nr'"
    return 1
  fi

  if [ "$ans" == "null" ]; then
    log::debug "There is no key in inventory - answering '0' | key='$item_nr' item_obj='$item_obj'"
    printf "0"
    return 0
  fi

  # Return success
  echo "$ans"
}

function item_obj::explore_location {
  local item_obj="${1:?}"
  local -r loc="$(jq -r '.["'"$item_obj"'"]' "./scraped/item_to_location.json")"
  if [ "$loc" == "null" ]; then
    log::err "Could not turn item into a location | loc='$loc' item_obj='$item_obj'"
    printf "0"
    return 1
  fi

  printf "%s" "$loc"
}

function item_obj::as_bait() {
  local item_obj="${1:?}"

  if ! (( $(item_obj::inventory "$item_obj") > 0 )); then
    log::err "You tried to set the bait for something you're all out of | item_obj='$item_obj'"
    return
  fi

  case "$item_obj" in
    grubs) echo "Grubs" ;;
    gummy_worms) echo "Gummy Worms" ;;
    mealworms) echo "Mealworms" ;;
    minnows) echo "Minnows" ;;
    worms) echo "Worms" ;;
    *) return 1 ;;
  esac
}
################################################################################
################################ classification ################################
################################################################################
function item_obj::is_fishable() {
  local item_obj="${1:?}"
  _is_key_in_json_file "$item_obj" "./scraped/fish_to_location.json"
}

function item_obj::is_explorable() {
  local item_obj="${1:?}"
  _is_key_in_json_file "$item_obj" "./scraped/item_to_location.json"
}

function item_obj::is_craftable() {
  local item_obj item_nr
  item_obj="${1:?}"
  item_nr="$(item_obj::num "$item_obj")"
  _is_key_in_json_file "$item_nr" "./scraped/item_number_to_recipe.json"
}

function item_obj::is_buyable() {
  local item_obj="${1:?}"

  case "$item_obj" in
    worms|*_seeds|*_spores) return 0 ;;
    *) return 1 ;;
  esac
}
################################################################################
############################## crop classification #############################
################################################################################
function item_obj::is_crop() {
  local item_obj="${1:?}"
  is_in_array "$item_obj" $(_echo_short_crops) $(_echo_long_crops) $(_echo_mega_crops) $(_echo_gold_crops)
}

function item_obj::is_crop::short() {
  local item_obj="${1:?}"
  is_in_array "$item_obj" $(_echo_short_crops)
}

function item_obj::is_crop::long() {
  local item_obj="${1:?}"
  is_in_array "$item_obj" $(_echo_long_crops)
}

function item_obj::is_crop::gold() {
  local item_obj="${1:?}"
  is_in_array "$item_obj" $(_echo_gold_crops)
}

function item_obj::is_crop::mega() {
  local item_obj="${1:?}"
  is_in_array "$item_obj" $(_echo_mega_crops)
}
################################################################################
############################### private functions ##############################
################################################################################
function _is_key_in_json_file() {
  local -r key="${1:?What key are we trying to find in the file}"
  local -r json_file="${2:?What is the file}"

  if ! [ -f "$json_file" ]; then
    log::err "Cannot find json file | json_file='$json_file'"
    return 1
  fi

  jq --arg key "$key" --exit-status '.[$key]' "$json_file" &> /dev/null
}

function _echo_short_crops() {
  local crops=(
    pepper
    carrot
    peas
    cucumber
    eggplant
    radish
    mushroom
    onion
    hops
    potato
    tomato
    leek
    watermelon
    corn
    cabbage
    pine_tree
    pumpkin
  )
  for c in "${crops[@]}"; do
    echo "$c"
  done
}

function _echo_long_crops() {
  local crops=(
    wheat
    broccoli
    cotton
    sunflower
    beet
    rice
  )
  for c in "${crops[@]}"; do
    echo "$c"
  done
}

function _echo_mega_crops() {
  local crops=(
    mega_beet
    mega_sunflower
    mega_cotton
  )
  for c in "${crops[@]}"; do
    echo "$c"
  done
}

function _echo_gold_crops() {
  local crops=(
    gold_pepper
    gold_carrot
    gold_cucumber
    gold_eggplant
  )
  for c in "${crops[@]}"; do
    echo "$c"
  done
}
################################################################################
########################### Monkey patched functions ###########################
################################################################################
# function item_obj::craftworks::add() {
