function _donate() {
  # Parse args
  if ! item_id="$(item_obj::num "$1")"; then
    log::err "Failed to get item ID"
    return 1
  fi
  local -r amount="${2:?How many to donate}"

  # Do work
  local output
  if ! output="$(worker "go=donatecomm" "amt=${amount}")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  if [ "$output" == "success" ]; then
    log::info "Donated to community center successfully | item='$1/$item_id' amount='$amount'"
  elif [ "$output" == "notenough" ]; then
    log::err "You do not have enough items to donate | output='$output'"
    return 1
  else
    log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'"
    return 1
  fi
}

function bs4_helper::donate::goal() {
python3 -c "from bs4 import BeautifulSoup
import sys

def get_donation_goal(html_content):
  soup = BeautifulSoup(html_content, 'html.parser')
  goal_declaration = soup.find('div', string='Current Goal')
  goal_card = goal_declaration.find_next(class_='row').find_all('div')[0]

  for line in goal_card.get_text().split('\n'):
    line = line.strip()
    if line == '': continue
    if line == 'GOAL': continue
    final_idx = line.find(' (')
    return line[:final_idx]

html_content = sys.stdin.read()
print(get_donation_goal(html_content))
"
}

function chore::donate() {
  # Parse args
  local -r remaining="${1:?How many to donate?}"

  # Read state
  local item_name item_obj
  item_name="$(farmpg13::page "comm.php" | bs4_helper::donate::goal)"
  if ! item_obj="$(item::new::name "$item_name")"; then
    log::err "Could not figure out what item to donate"
    return 1
  fi
  log::debug "We wanna donate for chores | item_obj='$item_obj' remaining='$remaining'"

  # Do work
  captain::ensure_have "$item_obj" "$remaining"
  _donate "$item_obj" "$remaining"
}
