function farm::set_seed() {
  # Parse args
  local item_obj
  if ! item_obj="$(item::new::name "$1")"; then
    log::err "Argument was not an item name"
    return 1
  fi

  # Get the corresponding seed from the plant
  local seed_obj
  if ! seed_obj="$(item_obj::seed "$item_obj")"; then
    log::err "Failed to convert item_obj to seed | item_obj='$item_obj'"
    return 1
  fi

  # Dereference the seed into its ID
  local seed_nr
  if ! seed_nr="$(item_obj::num "$seed_obj")"; then
    log::err "Failed to convert seed name to seed nr | seed_obj='$seed_obj'"
    return 1
  fi

  # Do work
  if ! output="$(worker "go=setfarmseedcounts" "id=$seed_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    "") log::debug "Set farm seed successfully" ; return 0;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function harvest() {
  local output
  if ! output="$(worker "go=harvestall" "id=$FARMRPG_MY_ID")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Harvested all successfully" ;;
    "") log::err "Failed to harvest all | output='$output'" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function plant() {
  local item_name="${1:?}"

  # Set up state
  if ! farm::set_seed "$item_name"; then
    log::err "Failed to set farm seed | item_name='$item_name'"
    return 1
  fi

  # Do work
  local output planted_item grow_time
  if ! output="$(worker "go=plantall" "id=$FARMRPG_MY_ID")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Parse response
  case "$output" in
    "|") log::err "Failed to plant | output='$output'" ; return 40;;
    *"|"*) log::debug "Successfully planted | output='$output'" ;;
  esac

  # Parse and then normalize the item
  IFS="|" read -r planted_item grow_time <<< "$output"
  if ! planted_obj="$(item::new::planted "$planted_item")" ; then
    log::warn "Failed to construct item_object from planted_item | output='$output' planted_item='$planted_item'"
  fi

  # Validate response
  if ! item_obj::is_crop "$planted_obj"; then
    log::warn "Item is not considered a crop | output='$output' planted_item='$planted_item'"
    return 1
  fi

  log::info "Planted all successfully | plant='$planted_obj' grow_time='$grow_time'"
  echo $(( grow_time + 1 ))
}

################################################################################
################################## till suite ##################################
################################################################################
# Returns a value in
#
#     growing
#     grown
#     empty
#
function farmland::status() {
  page::panel_crops | bs4_helper::panel_crops::status
}

# Tilling a field must be done before planting
function farmland::till() {
  local farm_status
  farm_status="$(farmland::status)"
  case "$farm_status" in
    grown) harvest && return $? ;;
    growing)
      log::warn "Crops are still growing. We will see how long until they are ready"
      local seconds
      seconds="$(farmland::seconds_until_ready)"
      if [ "$seconds" != "0" ]; then
        log::warn "Waiting for current plants to grow... | seconds='$seconds'"
        sleep "$seconds"
      fi

      # Recurse. Should be harvestable now. Or maybe still need to wait a bit more
      farmland::till
      ;;
    empty) return ;;
    *) log::err "Unknown farm status | farm_status='$farm_status'"
  esac
}

function farmland::seconds_until_ready() {
  # Measure
  local now l8r sleep=10
  log::info "Measuring how long it will take current crop to finish growing | measurement_time='$sleep'"
  log::debug "Taking first reading"
  now="$(page::panel_crops | bs4_helper::panel_crops::ready_percent)"

  log::debug "Sleeping before taking second reading | sleep='$sleep'"
  sleep "$sleep"

  log::debug "Taking second reading"
  l8r="$(page::panel_crops | bs4_helper::panel_crops::ready_percent)"
  log::debug "Took 2 readings | now='$now' l8r=='$l8r'"

  # Calculate
  local left delta additional_waits seconds_until_done ans
  left=$( bc <<< "100 - $l8r")
  [ "$left" == "0" ] && echo "0" && return
  delta=$(bc <<< "$l8r - $now")
  additional_waits=$(python3 -c "print($left / $delta)")
  seconds_until_done=$(bc <<< "$sleep*$additional_waits")
  log::debug "In 'sleep' seconds we made 'delta' progress and have 'left' percent left. We must do 'aw' additional_waits, which will take us 's' seconds | sleep='$sleep' delta='$delta' left='$left' additional_waits='$additional_waits' seconds_until_done='$seconds_until_done'"
  ans="$(python3 -c "print(int($seconds_until_done))")"
  log::info "Plants will be ready to harvest in about | seconds='$ans'"

  # Return answer to stdout
  echo "$ans"
}

function bs4_helper::panel_crops::ready_percent() {
  python3 -c "from bs4 import BeautifulSoup
import sys

def do_work():
  soup = BeautifulSoup(sys.stdin.read(), 'html.parser')
  my_div = soup.find('span', class_='c-progress-bar-fill pb11')
  if my_div is None:
    return '0.0'
  ready = my_div['style'].split(':')[1].strip('%;')
  if ready == '100%; background-color':
    return '100.0'
  return ready

print(do_work())
"
}

function bs4_helper::panel_crops::status() {
  python3 -c "from bs4 import BeautifulSoup
import sys

def do_work():
  soup = BeautifulSoup(sys.stdin.read(), 'html.parser')
  my_div = soup.find('span', class_='c-progress-bar-fill pb11')
  if my_div is None:
    return 'empty'
  ready = my_div['style'].split(':')[1].strip('%;')
  if ready == '100%; background-color':
    return 'grown'
  return 'growing'

print(do_work())
"
}

function chore::plant() {
  local remaining="${1:?}"

  sell::make_space "peppers" "$((FARMRPG_PLOTS + remaining))"

  local i_have_peppers
  if ! i_have_peppers="$(item_obj::inventory "peppers")"; then
    log::err "Could not figure out how much peppers we have"
    return 1
  fi

  captain::ensure_have "peppers" "$(( i_have_peppers + remaining ))"
}
