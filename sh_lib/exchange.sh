# Spiders for cutlass
### go=exchtradeaccept
### id=17
function exchange::trade() {
  local id="${1:?}"

  # Do work
  local output
  if ! output="$(worker "go=exchtradeaccept" "id=$id")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Successfully traded at the exchange center" ;;
    already) log::err "You have already made this trade" ; return 1 ;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function exchange::xp() {
  if ! exchange::xp::_is_ok; then
    log::warn "Looks like we have already exchanged XP today"
    return
  fi
  # Do work
  local output
  if ! output="$(worker "go=convertxps")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Converted XP to Silver" ; return 1 ;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function exchange::xp::_is_ok {
  farmpg13::page "exchange.php" | python3 -c "
from bs4 import BeautifulSoup
import sys

def has_exchange_happened_today(html_content):
  soup = BeautifulSoup(html_content, 'html.parser')
  div = soup.find_all(class_='card')[-1].find(class_='item-after')
  return div.get_text() == 'Complete'

if has_exchange_happened_today(sys.stdin.read()):
  exit(1) # doing an exchange is NOT ok
"
}
