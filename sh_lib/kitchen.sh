################################################################################
#################################### actions ###################################
################################################################################
function cook::put_in_oven() {
  local item="${1:?}"
  local oven_nr="${2}"
  if [ -z "$oven_nr" ]; then
    if ! oven_nr="$(cook::_get_open_oven)"; then
      log::err "Failed to get open oven"
      return
    fi
  fi

  # Parse args
  local item_nr
  if ! item_nr="$(item_obj::num "${item}")"; then
    log::err "Failed to convert item name to num | item='$item'"
    return 1
  fi

  # Do work
  if ! output="$(worker "go=cookitem" "id=$item_nr" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Cooking item | item='$item' oven_nr='$oven_nr'" ;;
    "") log::err "Failed to cook recipe | item='$item' oven_nr='$oven_nr' output='$output'" ; return 1;;
    *) log::err "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function cook::stir() {
  local -r oven_nr="${1:?}"
  if ! output="$(worker "go=stirmeal" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  log::info "Stirred a meal | oven_nr='$oven_nr' output='$output'"

  # Ignore output
}

function cook::taste() {
  local -r oven_nr="${1:?}"
  if ! output="$(worker "go=tastemeal" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  log::info "Tasted a meal | oven_nr='$oven_nr' output='$output'"

  # Ignore output
}

function cook::season() {
  local -r oven_nr="${1:?}"
  if ! output="$(worker "go=seasonmeal" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  log::info "Seasoned a meal | oven_nr='$oven_nr' output='$output'"

  # Ignore output
}

function cook::collect() {
  local -r oven_nr="${1:?}"
  if ! output="$(worker "go=cookready" "oven=$oven_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Collected a meal | oven_nr='$oven_nr'" ;;
    notready) log::err "Meal is not ready!" ; return 1 ;;
    *) log::err "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

################################################################################
############################# parse html into state ############################
################################################################################
function cook::_get_open_oven() {
  farmpg13::page "kitchen.php" | python3 -c "
from bs4 import BeautifulSoup
import sys

def get_empty_oven(html_content):
  soup = BeautifulSoup(html_content, 'html.parser')
  for div in soup.find_all(class_='item-title'):
    if 'Empty' in div.get_text():
      return div.find('span').get_text().strip().strip('Oven #')
  exit(1)

print(get_empty_oven(sys.stdin.read()))
"
}

function cook::_choose_meal() {
  farmpg13::page "cookbook.php" | python3 -c "
from bs4 import BeautifulSoup
import sys


def cooker_number(recipe_div):
    text = recipe_div.get_text()
    if 'Enough resources to cook ' not in text:
      return 0

    # Extract the number after the desired text
    number_str = text.split('Enough resources to cook ')[1].strip()
    return int(number_str)

def cooker_name(recipe_div):
    name_descr = recipe_div.find('strong')
    if not name_descr:
      return 'UNKNOWN'
    for span in name_descr.find_all('span'):
        span.decompose()  # Remove the <span> element
    return name_descr.get_text(strip=True).lower().replace(' ', '_')

def get_cook_cmd(html_content):
  soup = BeautifulSoup(html_content, 'html.parser')
  recipe_divs = soup.find_all('div', class_='item-title', style='line-height:18px')
  for recipe_div in recipe_divs:
    can_make = cooker_number(recipe_div)
    recipe = cooker_name(recipe_div)
    if can_make > 0:
      return f'cook::put_in_oven {recipe}'

html_content = sys.stdin.read()
print(get_cook_cmd(html_content))
"
}

function cook::_get_cooking_actions() {
  farmpg13::page "kitchen.php" | python3 -c "
from bs4 import BeautifulSoup
import sys
from datetime import datetime, timedelta

def get_cooking_actions(html_content):
  soup = BeautifulSoup(html_content, 'html.parser')
  ans = list()
  current_datetime = datetime.now()

  # Loop through each <li> element to extract oven number and alt text.
  # Get actions
  blocks = soup.select('div.list-block')
  li_elements = blocks[1].find_all('li')
  for li in li_elements:
    oven_nr = li.find('a')['href'].split('=')[1]
    actions = li.find_all('img', alt=True)
    for action_img in actions:
      action = action_img.get('alt').split()[-1].lower()
      if action == 'stir':
        ans.append(f'log::debug \"[Cooking captain] Do not stir meals because we want this to last\"')
        continue
      ans.append(f'cook::{action} {oven_nr}')

    for span in li.select('div.item-after span'):
      countdown_to_str = span.get('data-countdown-to')
      countdown_to_time = datetime.fromisoformat(countdown_to_str)
      delta = countdown_to_time - current_datetime - timedelta(hours=2)
      if delta > timedelta(0):
        ans.append(f'log::debug \"[Cooking captain] We have to wait to collect from oven | {oven_nr=} {delta}\"')
        continue
      ans.append(f'cook::collect {oven_nr}')

  # Return success
  return ';'.join(ans)

print(get_cooking_actions(sys.stdin.read()))
"
}

################################################################################
############################## put it all together #############################
################################################################################
function captain::cook() {
  # Check to see if we can stir season or taste anything
  local actions action cmd
  IFS=$';' read -ra actions <<< "$(cook::_get_cooking_actions)"
  for action in "${actions[@]}"; do
    [ "$action" == "None" ] && continue
    # Split the action into an array that can be run as a command
    read -ra cmd <<< "$action"
    if ! "${cmd[@]}"; then
      log::err "Failed captain cook action | action='$action'"
      return 1
    fi
  done

  # Cook while we can
  local oven_nr
  while oven_nr="$(cook::_get_open_oven)"; do
    local action cmd
    if ! action="$(cook::_choose_meal)"; then
      log::err "We do not have the ingrdients to cook anything"
      return 1
    fi
    IFS=' ' read -ra cmd <<< "$action"
    if ! "${cmd[@]}"; then
      log::err "Failed captain cook action | action='$action'"
      return 1
    fi
  done
}

function chore::cook() {
  if ! oven_nr="$(cook::_get_open_oven)"; then
    log::err "Failed to get open oven"
    return 1
  fi

  # Start a meal cooking, wait until we can stir, taste, and season it
  cook::put_in_oven "bone_broth" "$oven_nr"
  sleep $((4*60))
  cook::stir "$oven_nr"
  cook::taste "$oven_nr"
  cook::season "$oven_nr"
}
