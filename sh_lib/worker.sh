function worker() {

  # Parse args
  function _build_url_query_params() {
    local ans="" arg arg_sep="?"
    # TODO put this macro into my snippet library # $for_arg_in_args
    # $for_arg_in_args
    # $done_args_in_args
    while (( $# > 0 )); do
      arg="$1"; shift 1
      ans="${ans}${arg_sep}${arg/ /%20}"
      arg_sep="&"
    done

    # TODO put this macro into my snippet library # $return_stdout
    echo "$ans"
  }
  local -r base="https://farmrpg.com/worker.php"
  local -r action="$1"
  local -r query_params="$(_build_url_query_params "$@")"
  shift $#
  local -r url="${base}${query_params}"

  log::debug "About to send req to farmrpg | url='$url'"
  local -r output="$(\
    local -r tmp_file="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f $tmp_file" EXIT
    curl \
      -X POST "$url" \
      --silent \
      --output "$tmp_file" \
      -H "$FARMRPG_USER_AGENT_HEADER" \
      -H "Accept: */*" \
      -H "Accept-Language: en-US,en;q=0.5" \
      -H "Accept-Encoding: identity" \
      -H "Referer: https://farmrpg.com/" \
      -H "X-Requested-With: XMLHttpRequest" \
      -H "Origin: https://farmrpg.com" \
      -H "DNT: 1" \
      -H "Connection: keep-alive" \
      -H "$FARMRPG_COOKIE_HEADER" \
      -H "Sec-Fetch-Dest: empty" \
      -H "Sec-Fetch-Mode: cors" \
      -H "Sec-Fetch-Site: same-origin" \
      -H "Sec-GPC: 1" \
      -H "Content-Length: 0" \
      -H "TE: trailers"
    local -r rc=$?
    cat "$tmp_file"
    cat "$tmp_file" > output.txt
    return $rc
  )"
  local rc="$?"
  if (( rc != 0 )); then
    log::err "Failed to send curl req | url='$url'"
    return 1
  fi
  log::debug "Sent req | output='$(log::field "$output")'"

  worker::handle_inventory_cache "$action"
  echo "$output"
}

function worker::action::is_mutating() {
  local -r action="${1:?}"
  case "$action" in

    # Mutating
    buyitem |\
    castnet |\
    collectallmailitems |\
    collectallpetitems |\
    cookitem |\
    cookready |\
    craftitem |\
    donatecomm |\
    drinkgj |\
    drinkoj |\
    drinkojs |\
    drinkxojs |\
    eatapple |\
    eatxapples |\
    explore |\
    feedallpigs |\
    fishcaught |\
    givemailitem |\
    harvestall |\
    loadfeedmill |\
    plantall |\
    playallcw |\
    sacrificeitem |\
    sellalluserfish |\
    sellitem |\
    spinfirst |\
    storewine |\
    tossmanyintowell |\
    usemultitem) return 0 ;;

    # NOT mutating
    addcwitem |\
    claimdaily |\
    claimmastery |\
    incuallraptors |\
    petallchickens |\
    petallcows |\
    removeallcw |\
    rest |\
    seasonmeal |\
    selectbait |\
    setfarmseedcounts |\
    stirmeal |\
    tastemeal |\
    trycrackcode |\
    work) return 1 ;;

    *) log::warn "Unknown action, cannot determine if we should update the inventory cache or not | action='$action'"
  esac
}

function worker::handle_inventory_cache() {
  local -r action="${1#go=}"
  if worker::action::is_mutating "$action"; then
    inventory::clear_cache
  fi
}
