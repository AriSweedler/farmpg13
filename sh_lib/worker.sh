function worker() {

  # Parse args
  function _build_url_query_params() {
    local ans="" arg arg_sep="?"
    # TODO put this macro into my snippet library # $for_arg_in_args
    # $for_arg_in_args
    # $done_args_in_args
    while (( $# > 0 )); do
      arg="$1"; shift 1
      ans="${ans}${arg_sep}${arg}"
      arg_sep="&"
    done

    # TODO put this macro into my snippet library # $return_stdout
    echo "$ans"
  }
  local -r base="https://farmrpg.com/worker.php"
  local -r url="${base}$(_build_url_query_params "$@")"
  shift $#

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
    exit 1
  fi
  log::debug "Sent req | output='$(log::field "$output")'"

  if (( rc != 0 )); then
    log::err "Failed to brotli decode the output | url='$url' "
    #exit 1
  fi
  echo "$output"
}

function inventory() {
  local -r base="https://farmrpg.com/inventory.php"
  local -r output="$(\
    local -r tmp_file="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f $tmp_file" EXIT
    curl \
      -X POST "$base" \
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
    exit 1
  fi
  log::debug "Sent req | output='$(log::field "$output")'"

  if (( rc != 0 )); then
    log::err "Failed to brotli decode the output | url='$url' "
    #exit 1
  fi

  echo "$output" | python3 "./scraped/scripts/inventory.py"
  # echo "$output" | python3 "./scraped/scripts/inventory.py" > "./scraped/scripts/inventory.json"
}
