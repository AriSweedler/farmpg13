function page::pigs() {
  farmpg13::page "pigpen.php?id=$FARMRPG_MY_ID"
}

function bs4_helper::pigs::purchasable() {
  python3 -c "from bs4 import BeautifulSoup
import sys
def purchasable_pigs(html):
    soup = BeautifulSoup(html, 'html.parser')
    titles = soup.find_all(class_='content-block-title')
    pig_stats = None
    for title in titles:
      text = title.get_text()
      if text.startswith('Pigs'):
        pig_stats = text.replace('(', ' ').replace(')', ' ').split()
        break

    if pig_stats is None or len(pig_stats) != 4:
      exit(1)

    owned = int(pig_stats[1])
    capacity = int(pig_stats[3])
    purchasable = capacity - owned
    return purchasable

print(purchasable_pigs(sys.stdin.read()))
"
}

function bs4_helper::pigs::get_slaughter_cmds() {
  python3 -c "from bs4 import BeautifulSoup
import sys

def bacon_lvl(lvl):
  if lvl < 5:
    return 0
  return 25 + 10*(lvl - 5)

def slommer(slod):
  for opt in slod.find_all('option'):
    if not opt.get('value'):
      continue
    yield (int(opt.get('value')), int(opt.get('data-amt')))

def butcher(staged_bacon, slom):
  slaughter_cmds = ''
  remaining_inv = $FARMRPG_MAX_INVENTORY - staged_bacon
  for lvl in sorted(slom.keys(), reverse=True):
    if remaining_inv < 50:
      break
    bacon_per_pig = bacon_lvl(lvl)
    max_slaughterable = int(remaining_inv / bacon_per_pig)
    slaughter = min(max_slaughterable, slom[lvl])
    remaining_inv -= slaughter * bacon_per_pig
    slaughter_cmds += f'pigs::slaughter {lvl} {slaughter}\n'
  used_inv = $FARMRPG_MAX_INVENTORY - remaining_inv
  return f'sell::make_space bacon {used_inv}\n{slaughter_cmds}'

def get_staged_bacon(soup):
  prev_dev = soup.find('div', class_='content-block-title', string='Slaughterhouse Totals')
  if prev_dev is None:
    return 0
  div = prev_dev.find_next('div', class_='card-content-inner')
  arr = [item.strip() for item in div.stripped_strings]
  for idx, item in enumerate(arr):
    if 'slaughterhouse to become' in item:
      return int(arr[idx+1])
  return 0

def slaughter_cmds(html):
  soup = BeautifulSoup(html, 'html.parser')
  staged_bacon = get_staged_bacon(soup)
  slaughter_options_div = soup.find('select', class_='levelid')
  slaughter_options_map = dict(slommer(slaughter_options_div))
  return butcher(staged_bacon, slaughter_options_map)

print(slaughter_cmds(sys.stdin.read()))
"
}

function pigs::purchase() {
  # Parse args
  local amt="${1:?Amount of pigs to purchase}"

  if (( amt == 0 )); then
    log::debug "Tried to purchase 0 pigs, returning success"
    return
  fi

  # Do work
  local output
  if ! output="$(worker "go=massaddpigs" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    *"Pigs bought") log::info "Successfully bought pigs | amt='$amt'" ;;
    "You cannot buy that many") log::err "You tried to buy too many pigs | amt='$amt'" ;;
    "") log::err "Failed to buy pigs" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function pigs::feed() {
  local output
  if ! output="$(worker "go=feedallpigs")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully fed all the pigs OwO" ;;
    *) log::err "Failed to feed piggies (L)" ; return 1 ;;
  esac
}

function pigs::slaughter() {
  local lvl amt
  lvl="${1:?Level of pigs to slaughter}"
  amt="${2:?Amount of pigs to slaughter}"

  local output
  if ! output="$(worker "go=slallpigs" "id=$lvl" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Successfully sent pigs to be slaughtered | lvl='$lvl' amt='$amt'" ;;
    "") log::err "Failed to sent pigs to slaughter" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function pigs::purchase::max() {
  local amt
  if ! amt="$(page::pigs | bs4_helper::pigs::purchasable)"; then
    log::err "Could not figure out how many pigs to purchase"
    return 1
  fi
  pigs::purchase "$amt"
}

function captain::pigs() {
  # Buy max pigs
  pigs::purchase::max

  # Sell as much bacon as we can slaughter for
  ( IFS=$'\n'       # Set the Internal Field Separator to newline
  for action in $(page::pigs | bs4_helper::pigs::get_slaughter_cmds); do
    IFS=' ' read -ra cmd <<< "$action"
    log::info "Taking captain::pig action | action='$action'"
    "${cmd[@]}"
  done
  )

  # Feed all the pigs
  pigs::feed

  # Place enough items in feeder to get back to max feed
  feedmill::load
}
