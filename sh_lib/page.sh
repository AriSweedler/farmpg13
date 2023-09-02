function farmpg13::page() {
  local -r url="https://farmrpg.com/${1:?}"
  local -r tmp_file="${2:-$(mktemp)}"
  local -r output="$(\
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
  # Print the first 50 chars including newlines
  log::debug "Sent req | output='$(log::field "$output" | head -c 250 | tr -d '\n')'"
  # Return to stdout
  echo "$output"
}

# Get the page for the panel of crops that we are currently growing.
function page::panel_crops() {
  farmpg13::page "panel_crops.php?cachebuster=380824"
}
