function temple::necessary_donations() {
  local item_obj item_nr
  item_obj="${1:?}"
  if ! item_nr="$(item_obj::num "$item_obj")"; then
    log::err "Couldn't get sacrificial ID"
    return 1
  fi

  farmpg13::page "templeitem.php?id=$item_nr" | python3 -c "
from bs4 import BeautifulSoup
import sys

def temple_status(html):
    soup = BeautifulSoup(html, 'html.parser')
    first_content = soup.find(class_='card-content-inner').get_text().strip()
    if 'You have sacrificed enough' in first_content:
      return 0
    return soup.find(style='font-size:11px').get_text().strip('()').replace(',', '').split()[0]

html_content = sys.stdin.read()
print(temple_status(html_content))
"
}

function temple::sacrifice_item() {
  local sac_item item_obj
  sac_item="${1:?What item to sacrifice}"

  item_obj="$(item::new::name "$sac_item")"
  if [ -z "$item_obj" ]; then
    log::err "Failed to normalize item name for temple sacrifice"
    return 1
  fi

  local amt_possible
  if ! amt_possible="$(item_obj::inventory "$item_obj")"; then
    log::err "Could not figure out how much to sacrifice"
    return 1
  fi

  local amt_acceptable
  if ! amt_acceptable="$(temple::necessary_donations "$item_obj")"; then
    log::err "Could not figure out how many more we should donate"
    exit 1
  fi
  if (( amt_acceptable == 0 )); then
    log::warn "We don't need to donate anymore"
    return 1
  fi

  function min() {
    (( $1 < $2 )) && echo "$1" || echo "$2"
  }
  local amt
  amt="$(min "$amt_possible" "$amt_acceptable")"

  # Do work
  if ! output="$(worker "go=sacrificeitem" "item=$sac_item" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Sacrificed successfully | sac_item='$sac_item' amt='$amt'" ;;
    "") log::err "Failed to sacrifice" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function captain::temple() {
  while true; do
    captain::ensure_have potato 500
################################################################################
    # We run in an infinite loop here. So we just wanna make sure that things
    # we're using (for crafting and cooking and such) don't run out
    #
    # TODO make 'temple' a kuber action.
    # TODO make 'captain::crop' a kuber action - choose what to plant.
    captain::ensure_have mushroom 800
    captain::ensure_have onion 1200
################################################################################
    log::info "Donating"
    temple::sacrifice_item "Potato" || return $?
    log::info "Nice donation"
  done
}
