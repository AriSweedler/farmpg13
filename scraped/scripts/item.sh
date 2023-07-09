# Get the 'item' HTML page
#
# Example:
#
#     ./item.sh 40
#
function item() {
  local -r url="https://farmrpg.com/item.php?id=${1:?}"
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

  if (( rc != 0 )); then
    log::err "Failed to brotli decode the output | url='$url' "
    #return 1
  fi

  echo "$output"
}
