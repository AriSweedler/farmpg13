function page::feedmill() {
  farmpg13::page "feedmill.php?id=$FARMRPG_MY_ID"
}

function bs4_helper::feedmill::feed_processing() {
  python3 -c "from bs4 import BeautifulSoup
import sys

def extract_feed_units(html):
    soup = BeautifulSoup(html, 'html.parser')
    prev_dev = soup.find('div', class_='content-block-title', string='About the feed mill')
    ans = prev_dev.find_next('div').find('strong')
    return ans.get_text().replace(',', '')

html_content = sys.stdin.read()
feed_units = extract_feed_units(html_content)
print(feed_units)
"
}

function feedmill::load::_item() {
  # Parse args
  local -r item="${1:?What item to load}"
  local -r amt="${2:?How much to load}"
  if ! captain::ensure_have "$item" "$amt"; then
    log::err "Could not ensure we had enough of the item"
    return 1
  fi

  function encode_feedable_crop() {
    local -r crop="${1:?Crop to encode}"
    case "$crop" in
      corn) echo "45865425578" ;;
      broccoli) echo "45853160650" ;;
      *) log::err "Not a feedable crop (or we do not know the id)" ;;
    esac
  }
  local id
  if ! id=$(encode_feedable_crop "$item") ; then
    log::err "Failed to encode crop as feedmillable"
    return 1
  fi

  # Do work
  local output
  if ! output="$(worker "go=loadfeedmill" "id=$id" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Loaded feed mill successfully | item='$item' amt='$amt'" ;;
    "") log::err "Failed to load feed mill | item='$item' amt='$amt'" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function feedmill::_choose_item() {
  if [ -z "$i_need_feed" ]; then
    log::debug "Naive feeding strategy, ezpz: 1 corn"
    echo "corn;1;2"
  fi

  if (( i_need_feed > 24 )); then
    local need_broccoli=$((i_need_feed / 24))
    echo "broccoli;$need_broccoli;24"
  elif (( i_need_feed > 2 )); then
    local need_corn=$((i_need_feed / 2))
    echo "corn;$need_corn;2"
  else
    log::err "We do not need any more feed"
    return 1
  fi
}

function feedmill::load() {
  log::info "Managing feedmill {{{"

  # Amount
  inventory::clear_cache
  local i_have_feed
  if ! i_have_feed="$(item_obj::inventory "feed")"; then
    log::err "Could not figure out how much feed we have"
    return 1
  fi

  local feed_processing
  if ! feed_processing="$(page::feedmill | bs4_helper::feedmill::feed_processing)"; then
    log::err "Could not figure out how much feed we have"
    return 1
  fi

  # Initialize the 'i_need_feed' var and log it
  local i_need_feed
  projected_feed=$(( i_have_feed + feed_processing ))
  i_need_feed=$((FARMRPG_MAX_INVENTORY - projected_feed - 20))
  if (( i_need_feed < 2 )); then
    log::info "We do not need any more feed! }}} | i_have_feed='$i_have_feed' feed_processing='$feed_processing'"
    return
  else
    log::info "We need some more feed | i_need_feed='$i_need_feed'"
  fi

  # Do work while there is work to be done
  local item_obj amt feed_per_item
  while (( i_need_feed > 2 )); do
    if ! feed_descriptor="$(feedmill::_choose_item)"; then
      log::err "Could not figure out what feed item to choose }}} | i_need_feed='$i_need_feed'"
      return 1
    fi
    IFS=";" read -r item_obj amt feed_per_item <<< "$feed_descriptor"
    feedmill::load::_item "$item_obj" "$amt" || return
    i_need_feed=$((i_need_feed - (feed_per_item*amt)))
  done

  log::info "Feedmill loading was successfully managed }}}"
}
