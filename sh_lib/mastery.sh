# Get the page for what our masteries are
function page::mastery() {
  farmpg13::page "mastery.php"
}

function bs4_helper::mastery::desired_action() {
  python3 -c "
from bs4 import BeautifulSoup
import sys

soup = BeautifulSoup(sys.stdin.read(), 'html.parser')

for claim_me in soup.find_all('button', class_='claimbtn'):
  id = claim_me['data-id']
  action = f'mastery::claim {id}'
  print(action)
"
}

function mastery::claim() {
  # Parse args
  local id="${1:?ID of daily quest}"

  # Do work
  local output
  if ! output="$(worker "go=claimmastery" "id=$id")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    *"Reward Claimed:"*)
      log::debug "Claimed mastery reward | output='$output'"
      local reward
      reward="$(echo "$output" \
        | sed 's|<br/>|\n|g' \
        | awk -F'[><]' '/img/ {print $3}' \
        | tr '\n' ';')"
      reward="${reward# }"
      log::info "Claimed mastery reward | reward='$reward'"
      ;;
    "") log::err "Failed to claim mastery rewards" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function mastery::claim::all() {
  ( IFS=$'\n'       # Set the Internal Field Separator to newline
  for action in $(page::mastery | bs4_helper::mastery::desired_action); do
    IFS=' ' read -ra cmd <<< "$action"
    "${cmd[@]}"
  done
  )
}
