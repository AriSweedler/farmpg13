function item::name_to_num() {
  local -r item_name="$(echo "${1:?}" | tr '-' '_')"
  local -r num="$(jq -r '.["'"$item_name"'"]' "./scrape_explore/item_to_number.json")"
  if [ "$num" == "null" ]; then
    log::err "Could not turn item into number | num='$num'"
    printf "0"
    exit 1
  fi
  # shellcheck disable=SC2059
  printf "$num"
}
