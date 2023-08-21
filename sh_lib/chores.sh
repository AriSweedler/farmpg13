# Get the page for what our chores are
function page::chores() {
  farmpg13::page "daily.php"
}

function bs4_helper::chores::for_chore_and_status() {
cat << EOF
from bs4 import BeautifulSoup
import sys

soup = BeautifulSoup(sys.stdin.read(), 'html.parser')

chore_divs = soup.find_all(class_='item-title', style='font-size:15px;')
for chore_div in chore_divs:
  chore = chore_div.find('br').previous_sibling.strip()
  status = chore_div.find('br').next_sibling.text.strip()
EOF
}

function bs4_helper::chores::undone() {
  python3 -c "
$(bs4_helper::chores::for_chore_and_status)
  if status == 'Completed & Claimed!':
    continue
  elif status == 'Completed':
    continue
  else
    print(chore)
"
}

# TODO worry about the undone ones
function bs4_helper::chores::list() {
  python3 -c "
$(bs4_helper::chores::for_chore_and_status)
  print(chore)
"
}

# Returns an enum:
#
#     incomplete
#     unclaimed
#     complete
#
function bs4_helper::chores::status() {
  python3 -c "
ans = 'complete'
$(bs4_helper::chores::for_chore_and_status)
  if status == 'Completed & Claimed!':
    continue
  elif status == 'Completed':
    ans = 'unclaimed'
  else:
    print('incomplete')
    exit(0)
print(ans)
"
}

function blah() {
  page::chores | bs4_helper::chores::status
}

function chores::do() {
  local -r chore="${1:?}"
  log::debug "Trying to do chore | chore='$chore'"

  local action number
  case "$chore" in
    "Drink"*"Orange Juice")
      action="drinkojs"
      number=$(grep -oE '[0-9]+' <<< "$chore")
      ;;
    "Open"*"Items at Locksmith")
      action="open_locksmith"
      number=$(grep -oE '[0-9]+' <<< "$chore")
      ;;
    "Eat"*"Apples")
      action="eatxapples"
      number=$(grep -oE '[0-9]+' <<< "$chore")
      ;;

    "Harvest 100 Crops" |\
    "Sell 750 Items" |\
    "ZZZ") log::info "A normal day of work will complete this chore" ; return ;;
    *) log::err "Uncertain how to do this chore | chore='$chore'" ;;
  esac

  log::info "We need to do the action | action='$action' number='$number'"
  echo "$action" "$number"
}

function chores::claim::one() {
  # Parse args
  local -r chore_id="${1:?}"

  # Do work
  local output
  if ! output="$(worker "go=claimdaily" "id=$chore_id")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Validate output
  case "$output" in
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'"
  esac
}

function chores::claim::all() {
  # https://farmrpg.com/worker.php?go=claimdaily&id=20008668
  :
}

function captain::chores() {
  local status
  status="$(page::chores | bs4_helper::chores::status)"
  log::
  case "$status" in
    incomplete) log::info "We have some chores to do" ;;
    unclaimed) chores::claim_all ;;
    complete) return 0 ;;
    *) log::err "Unknown chores status | status='$status'" ; return 1 ;;
  esac

  ( IFS=$'\n'       # Set the Internal Field Separator to newline
  for chore in $(page::chores | bs4_helper::chores::list); do
    chores::do "$chore"
  done
  )
  captain::chores
}
