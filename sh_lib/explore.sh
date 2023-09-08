function explore::loc_to_num() {
  local -r loc="${1:?}"
  local -r num="$(jq -r '.["'"$loc"'"]' "./scraped/location_to_number.json")"
  if [ "$num" == "null" ]; then
    log::err "Could not turn location into a number | num='$num'"
    printf "0"
    return 1
  fi

  printf "%s" "$num"
}

function explore::one() {
  # Parse args
  while (( $# > 0 )); do
    local explore_loc_num
    case "$1" in
      --item)
        local loc item_obj
        item_obj="$(item::new::name "$2")"
        loc="$(item_obj::explore_location "$item_obj")"
        explore_loc_num="$(explore::loc_to_num "$loc")"
        shift 2
        log::debug "Dereferenced item into explore location | item_obj='$item_obj' loc='$loc'"
        ;;
      --apple_cider)
        local drink_cider="true"
        shift
        ;;
      --loc)
        loc="$2"
        explore_loc_num="$(explore::loc_to_num "$loc")"
        shift 2
        ;;
      [0-9][0-9])
        explore_loc_num="$1"
        shift 1
        ;;
      *) echo "Unknown argument in ${FUNCNAME[0]}: '$1'"; return 1 ;;
    esac
  done

  # Also add cider
  args=("go=explore" "id=${explore_loc_num}")
  if [ "$drink_cider" == "true" ]; then
    args=( "${args[@]}" "cider=1" )
  fi

  if ! output="$(worker "${args[@]}")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  local remaining_stamina
  remaining_stamina="$(awk -F'[<>]' '/<div id="explorestam">/{print $3}' <<< "$output" | tr -d ',')"
  log::debug "Explored successfully | location='$explore_loc_num' remaining_stamina='$remaining_stamina'"
  log::info "Explored successfully | loc='$loc' args='${args[*]}'"

  if [ -z "$remaining_stamina" ] && [ "$drink_cider" == "true" ]; then
    log::warn "Not enough stamina to use an apple cider | output='$output'"
    remaining_stamina=0
  fi
  echo "$remaining_stamina"
}

function explore() {
  local remaining_stamina=999
  while (( remaining_stamina > 0 )); do
    remaining_stamina="$(explore::one "$@" | tr -d ',')"
  done
}

################################################################################
############################# item management (itm) ############################
################################################################################

##
# Sell excess items when the inventory exceeds a certain limit. Ensures that
# you maintain a minimum quantity of a specific item while selling the excess
# to keep your inventory manageable.
#
# \param item_name The name of the item to shed excess of.
#
# \note
# - Configurable parameters:
#   - `keep_at_least`: Minimum quantity of the item to keep.
#   - `sell_cap`: Maximum allowed inventory size before selling excess.
#
# \code{shell}
# item_management::sell "slimestone"
# \endcode
function item_management::sell() {
  # Config
  local keep_at_least=700
  local sell_cap=$(( FARMRPG_MAX_INVENTORY - 100 ))

  # Parse args
  local item_name item_obj
  item_name="${1:?Item to shed excess of}"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not convert arg to item object | arg='$1'"
    return 1
  fi

  # Read state
  local i_have
  i_have="$(item_obj::inventory "$item_obj")"

  # We don't have too many, just return
  if (( i_have < sell_cap )); then
    log::debug "We have less than sell_cap of item. Returning | sell_cap='$sell_cap' item_name='$item_name'"
    return
  fi

  # Figure out how many to sell and sell them
  local excess=$(( i_have - keep_at_least ))
  if (( excess > 0 )); then
    sell "$item_obj" "$excess"
  fi
}

##
# Craft items when inventory exceeds a specified limit.
#
# This function crafts items when the inventory of a specific item exceeds a
# certain limit. It converts excess items into a different item to manage
# inventory effectively.
#
# \param item_name The name of the item to craft from when inventory exceeds the craft cap.
# \param cm_item_name The name of the item to craft into.
#
# \note
# - Configurable parameter:
#   - `craft_cap`: The inventory limit for triggering crafting.
#
# \code{shell}
# item_management::craft "apple" "apple_cider"
# \endcode
##
function item_management::craft() {
  # If we have more than this, start crafting
  local craft_cap=700

  # Parse args
  local item_name item_obj
  item_name="${1:?Item to shed excess of}"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not convert arg to item object | arg='$1'"
    return 1
  fi

  local cm_item_name cm_item_obj
  cm_item_name="${2:?Item to craft into}"
  if ! cm_item_obj="$(item::new::name "$cm_item_name")"; then
    log::err "Could not convert arg to item object | arg='$2'"
    return 1
  fi

  # Read state
  local i_have
  i_have="$(item_obj::inventory "$item_obj")"

  # We don't have too many, just return
  if (( i_have < craft_cap )); then
    log::debug "We have less than craft_cap of item. Returning | craft_cap='$craft_cap' item_name='$item_name' cm_item_name='$cm_item_name'"
    return
  fi

  # Figure out how many to sell and sell them
  craft_max "$cm_item_obj"
}

##
# Craft items when inventory dips below a specified limit.
#
# This function crafts items when the inventory of that item dips below a
# certain limit. It helps with getting other items crafted.
#
# \param item_name The name of the item to make sure we have enough of.
#
# \code
# # Example usage:
# item_management::reagent "iron_ring"
# \endcode
#
function item_management::reagent() {
  # Parse args
  local item_name item_obj
  item_name="${1:?Item to make sure we have enough of}"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not convert arg to item object | arg='$1'"
    return 1
  fi

  # Check if we have enough
  local item_threshold=400
  if (( $(item_obj::inventory "$item_obj") > item_threshold )); then
    return
  fi

  # Do work
  craft_max "$item_obj"
}

##
# Ensure inventory does not exceed a specified limit after exploring a location.
#
# This helper function is designed to be used after exploring a location. It
# checks the inventory of items and ensures that you don't have too many of any
# item, preventing you from voiding any valuable items.
#
# \param location The name or identifier of the location that was explored.
#
# \code
# item_management::explored "whispering_creek"
# \endcode
function item_management::explored() {
  local loc="${1:?}"
  log::info "Crafting up all the items we explored for {{{ | loc='$loc'"

  case "$loc" in
    whispering_creek)
      item_management::craft "apple" "apple_cider"
      item_management::craft "orange" "orange_juice"
      item_management::craft "lemon" "lemonade"
      item_management::craft "unpolished_garnet" "garnet"
      item_management::craft "garnet" "garnet_ring"
      item_management::reagent "iron_ring"
      item_management::craft "salt_rock" "salt"
      item_management::craft "striped_feather" "red_dye"
      item_management::craft "oak" "canoe"
      item_management::sell "slimestone"
      item_management::sell "blue_gel"
      item_management::sell "red_berries"
      item_management::sell "sour_root"
      item_management::sell "thorns"
      ;;
    ember_lagoon)
      item_management::craft "glass_orb" "glass_bottle"
      item_management::craft "emberstone" "cooking_pot"
      item_management::craft "prism_shard" "magicite"
      item_management::sell "magicite"
      ;;
    forest)
      item_management::craft "hide" "leather"
      item_management::craft "arrowhead" "crossbow"
      item_management::craft "mushroom_paste"
      item_management::craft "straw" "twine"
      item_management::craft "twine" "rope"
      item_management::craft "antler" "fishing_net"
      item_management::craft "fishing_net" "large_net"
      item_management::sell "wood"
      ;;
    all)
      item_management::explored "whispering_creek"
      item_management::explored "ember_lagoon"
      item_management::explored "forest"
      ;;
    *) log::warn "Unknown how to deal with items from | loc='$loc'" ;;
  esac

  log::info "Crafted all the items we explored for }}}"
}

################################################################################
################################ scrape stamina ################################
################################################################################
##
# Scrape the "stamina" value from farmrpg
function explore::get_current_stamina() {
  farmpg13::page "area.php?id=10" | bs4_helper::explore::get_current_stamina
}

function bs4_helper::explore::get_current_stamina() {
  python3 -c "from bs4 import BeautifulSoup
import sys

def extract_feed_units(html):
    soup = BeautifulSoup(html, 'html.parser')
    span = soup.find('span', id='stamina')
    return span.get_text().replace(',', '')

html_content = sys.stdin.read()
feed_units = extract_feed_units(html_content)
print(feed_units)
"
}

################################################################################
################ how to prevent voiding of items when exploring ################
################################################################################
function captain::explore::xp() {
  function fish::_mealworm() {
    local fish_loc="${1:?}"
    if ! loc_id="$(fish::loc_to_num "$fish_loc")"; then
      log::err "Couldn't turn arg into location to fish"
      return 1
    fi

    # Do work
    local output
    if ! output="$(worker "go=fishcaught" "id=$loc_id")"; then
      log::err "Failed to invoke worker"
      return 1
    fi

    # Parse output
    case "$output" in
      *fishcnt*)
        local caught
        caught="$(echo "$output" | grep -o 'itemimg. ><br/>.*<span' | awk -F'[><]' '{print $4}')"
        log::debug "Fished with a mealworm | caught='$caught'"
        log::info "Fished with a mealworm"
        ;;
      "") log::err "Failed to fish with a mealworm | output='$output'" ; return 1;;
    esac
  }

  local mw_count
  if ! mw_count="$(item_obj::inventory "mealworms")"; then
    log::err "Could not read how many mealworms we have"
    return 1
  fi
  if (( mw_count < 10 )); then
    log::warn "No mealworms"
    explore::exhaust_and_craft "whispering_creek"
    return
  fi

  # Set state
  fish::selectbait "Mealworms"

  while true; do
    log::info "Going for an explore::xp cycle | mw_count='$mw_count' {{{"
    # Use all the stamina
    #explore::exhaust_and_craft "jundland_desert"
    explore::exhaust_and_craft "whispering_creek"

    # Find how many mw's we have
    if ! mw_count="$(item_obj::inventory "mealworms")"; then
      log::err "Could not read how many mealworms we have"
      return 1
    fi
    if (( mw_count < 40 )); then
      log::warn "Out of mealworms!"
      break
    fi

    # Regain stamina
    for _ in {1..40}; do
      fish::_mealworm "farm_pond"
    done
    log::info "We have gone for an explore::xp cycle for }}}"
  done

  # And loop
  log::info "Sleeping for an hour then running this again"
  sleep $((60*60))
  captain::explore::xp
}

# Explore until exhaustion. Don't void any items
function explore::exhaust_and_craft() {
  # Parse args
  local loc="${1:?Location to explore}"

  log::info "Starting this exhaust_and_craft session {{{ | loc='$loc'"
  explore::exhaust "$loc"
  item_management::explored "$loc"
  log::info "Finished this exhaust_and_craft session }}}"
}

function explore::exhaust() {
  local loc="${1:?Location to explore}"

  # Read initial state
  local remaining_stamina
  remaining_stamina="$(explore::get_current_stamina)"
  log::info "Exploring with stamina {{{ | remaining_stamina='$remaining_stamina'"

  # Explore with ciders for as much as we can
  local cider_count STAMINA_FOR_CIDER=1060
  while (( remaining_stamina > STAMINA_FOR_CIDER )); do
    remaining_stamina="$(explore::one --apple_cider --loc "$loc")"
    if (( ++cider_count > 4 )); then
      cider_count=0
      item_management::explored "$loc"
    fi
  done

  # Finish it off with regular explores, crafting, and logging
  log::info "We do not have enough stamina for cider. Falling back to regular exploring | remaining_stamina='$remaining_stamina'"
  explore --loc "$loc"
  log::info "Exploring done }}}"
}
