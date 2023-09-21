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
  status = chore_div.find(class_='progressbar').find_previous_sibling().text.strip()
EOF
}

function bs4_helper::chores::desired_action() {
  python3 -c "
def decode_chore_to_action(chore, status):
  if status == 'Completed & Claimed!':
    return None

  # Parse information. Status is like:
  # Progress: 4 / 4000, Reward: 25 AC
  parts = status.split()
  progress = int(parts[1])
  target = int(parts[3].strip(','))
  remaining = target - progress
  if remaining <= 0:
    return None

  # Test to see if it is a known chore
  words = chore.split()
  if len(words) < 3:
    return None
  directive = f'{words[0]} {\" \".join(words[2:])}'
  # print(f'{chore=} {progress=} {target=} {directive=}')
  if directive == 'Drink Orange Juice':
    return f'drink::orange_juices {remaining}'
  elif directive == 'Drink Lemonade':
    return f'drink::lemonades {remaining}'
  elif directive == 'Drink Apple Cider':
    return f'drink::apple_cider {remaining}'
  elif directive == 'Eat Apples':
    return f'eat::apples {remaining}'
  elif directive == 'Open Items at Locksmith':
    return f'chore::locksmith {remaining}'
  elif directive == 'Sell Items':
    return f'chore::sell {remaining}'
  elif directive == 'Cast Fishing Nets':
    return f'fish::nets {remaining}'
  elif directive == 'Harvest Crops':
    return f'chore::plant {remaining}'
  elif directive == 'Plant Seeds':
    return f'chore::plant {remaining}'
  elif directive == 'Use Stamina':
    return f'drink::apple_cider {int(remaining/500)}'
  elif directive == 'Toss Items into Well':
    return f'gm::wishing_well {remaining}'
  elif directive == 'Donate Items':
    return f'chore::donate {remaining}'
  elif chore == 'Stir a Meal':
    return 'chore::cook'
  elif chore == 'Taste a Meal':
    return f'chore::cook'
  elif chore == 'Season a Meal':
    return f'chore::cook'
  elif chore == 'Crack open The Vault':
    return ':' # No-op - this will get accomplished normally
  elif chore == 'Spin the Wheel of Borgen':
    return 'spinwheel {target}'
  elif len(words) > 3 and f'{words[0]} {words[1]} {words[3]}' == 'Manually Catch Fish':
    return f'chore::fish {words[2]}'

  return f'Unknown'

$(bs4_helper::chores::for_chore_and_status)
  action = decode_chore_to_action(chore, status)
  if action is not None:
    print(f'{chore};{action}')

for claim_me in soup.find_all('a', class_='claimbtn'):
  id = claim_me['data-id']
  action = f'chores::claim {id}'
  print(f'claim;{action}')
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
def decide(chore, status):
  # print(f'{chore=} {status=}')
  if status == 'Completed & Claimed!':
    return 'complete'

  # Parse information. Status is like:
  # Progress: 4 / 4000, Reward: 25 AC
  parts = status.split()
  progress = int(parts[1])
  target = int(parts[3].strip(','))
  # print(f'{progress=} {target=}')

  # Get an answer
  if progress >= target:
    return 'unclaimed'
  return 'incomplete'

# Decide for each chore. Update a state machine
ans = 'complete'
$(bs4_helper::chores::for_chore_and_status)
  d = decide(chore, status)
  if d == 'incomplete':
    ans = d
    break
  elif d == 'unclaimed':
    ans = d
    continue

print(ans)
"
}

function chores::claim() {
  # Parse args
  local id="${1:?ID of daily quest}"

  # Do work
  local output
  if ! output="$(worker "go=claimdaily" "id=$id")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Claimed daily quest rewards | id='$id'" ;;
    "") log::err "Failed to claim daily quest rewards" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function chores::work() {
  local skip="${1:?}"
  ( IFS=$'\n'       # Set the Internal Field Separator to newline
  for chore_action in $(page::chores | bs4_helper::chores::desired_action); do
    if (( skip-- > 0 )); then
      log::warn "We could not figure out how to do this chore, skipping | skip='$chore_action'"
      continue
    fi

    local x=$RANDOM
    log::debug "We got chore_action | chore_action='$chore_action' LOOP_ID='$x'"
    # Destructure output of desired action into chores and actions
    IFS=';' read -r chore action <<< "$chore_action"
    # Split the action into an array that can be run as a command
    IFS=' ' read -ra cmd <<< "$action"

    case "$action" in
      "" | Unknown)
        log::warn "Not sure how to accomplish chore | chore='$chore'"
        return 1 # Fail - we should add support for this chore
        ;;
      ":")
        log::warn "We must wait to accomplish the chore | chore='$chore'"
        return 2 # Fail - is this true?
        ;;
      *)
        log::info "To accomplish chore we do | chore='$chore' action='$action'"
        if ! "${cmd[@]}"; then
          log::debug "chore_action failed | chore_action='$chore_action' LOOP_ID='$x'"
          return 3 # Fail
        fi
        log::debug "chore_action succeeded | chore_action='$chore_action' LOOP_ID='$x'"
        return 40 # success - but there are more chores to do
        ;;
    esac
  done
  return 0 # Done with chores
  ) # Reset the IFS
  return $? # Forward the return value of the subshell
}

function captain::chores() {
  local skip=0
  for _ in {1..10}; do
    log::debug "chore outer loop | val=$((++val))"
    chores::work "$skip"
    case "$?" in
      0) log::info "No more chores for use to look at!"; break ;;
      1|2|3) ((skip++)); log::warn "Failed a chore | skip='$skip'" ;;
      40) log::debug "Made chore progress" ;;
    esac
  done

  if (( skip == 0 )); then
    log::info "Finished all chores :)"
  else
    log::err "Could not complete all chores, look in the logs for what we had to skip"
  fi
}

function chores::debug() {
  page::chores | bs4_helper::chores::desired_action
}
