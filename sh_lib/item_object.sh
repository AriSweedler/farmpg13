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
  normz="$(tr '[:upper:]' '[:lower:]' <<< "$1")"

  # Strip unneeded trailing s
  if [[ "${normz: -1}" == "s" ]]; then
    normz="${normz:0:${#normz}-1}"
  fi
  # Add the 's' back for these special cases
  case "$normz" in
    hop) normz="hops" ;;
    pea) normz="peas" ;;
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
  local -r item_name="$(echo "${1:?}" | tr '[:upper:]-' '[:lower:]_')"
  case "$item_name" in
    mushroom) echo "mushroom_spores" ;;
    peas) echo "pea_seeds" ;;
    gold_peas) echo "gold_pea_seeds" ;;
    pepper|eggplant|tomato|carrot|cucumber\
    |radish|onion|hops|potato|leek|watermelon\
    |corn|cabbage|pumpkin|wheat|gold_pepper\
    |gold_carrot|gold_cucumber|cotton\
    |broccoli|gold_eggplant|sunflower|pine|beet\
    |mega_beet|mega_sunflower|rice|spring\
    |mega_cotton) echo "${item_name}_seeds" ;;
    *) log::err "Unknown item - cannot convert to seeds | item_name='$item_name'"; return 1 ;;
  esac
}

# Dereference an item into a method to procure it
function item_obj::procure_method() {
  if item_obj::is_buyable "$item_obj"; then
    echo "buy"
    return
  fi

  if item_obj::is_fishable "$item_obj"; then
    echo "fish"
    return
  fi

  if item_obj::is_explorable "$item_obj"; then
    echo "explore"
    return
  fi

  if item_obj::is_craftable "$item_obj"; then
    echo "craft"
    return
  fi

  if item_obj::is_crop "$item_obj"; then
    echo "farm"
    return
  fi

  echo "unknown"
  return 1
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

function item_obj::is_crop() {
  local crops=( $(_echo_crops) )
  for crop in "${crops[@]}"; do
    if [ "$item_obj" == "$crop" ]; then
      # Return success
      return 0
    fi
  done

  # Return failure
  return 1
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

function _echo_crops() {
  local crops=(
    pepper
    carrot
    peas
    cucumber
    eggplant
    radish
    onion
    hops
    potato
    tomato
    leek
    watermelon
    corn
    cabbage
    pine
    pumpkin
    wheat
    mushroom
    # broccoli
    # cotton
    # sunflower
    # beet
    # rice
  )
  for c in "${crops[@]}"; do
    echo "$c"
  done
}
