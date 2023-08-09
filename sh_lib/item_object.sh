function item::new::name() {
  if (( $# != 1 )); then
    log::err "Wrong number of arguments | num_args=$#"
    return 1
  fi

  local normalized
  normalized="$(echo "$@" | tr '[:upper:]- ' '[:lower:]__')"
  if ! output="$(jq -e '.["'"$normalized"'"]' "./scraped/item_to_number.json")"; then
    log::err "Unknown item | item_name='$normalized' output='$output'"
    return 1
  fi
  log::debug "[DEV] We found an item | item_name_name='$normalized' output='$output'"

  printf "%s" "$normalized"
}

function item::new::number() {
  local -r num="${1:?}"
  if ! output="$(jq -e ".${num}" "./scraped/item_to_number.json")"; then
    log::err "Arg is not a number | arg='$num' output='$output'"
    return 1
  fi
  log::debug "The arg is a valid item number | arg='$num' output='$output'"

  local -r item_name=$(jq -r '. as $json | keys[] | select($json[.] == "'"${num}"'")' "./scraped/item_to_number.json")
  if [ -z "$item_name" ]; then
    log::err "Could not find item name for number $num"
    return 1
  fi

  printf "%s" "$item_name"
}

function item_obj::num() {
  local item_name="${1:?}"

  local num
  if ! num="$(jq -r '.["'"$item_name"'"]' "./scraped/item_to_number.json")"; then
    log::err "Could not run jq command to conver item name to num"
    return 1
  fi
  if [ "$num" == "null" ]; then
    log::err "Could not turn item into number | num='$num'"
    return 1
  fi

  printf "%s" "$num"
}

### function main() {
###   log::err "YOU HAD BETTER BE MANUALLY RUNNING THIS SCRIPT"
###   local item item2 nr
###   item="$(item::new::name "potato")"
###   nr="$(item_obj::num "$item")"
###   item2="$(item::new::num "$nr")"
###   log::dev "Your item | item='$item' item2='$item2' nr='$nr'"
### }
### main "$@"
