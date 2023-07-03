function craft() {
  # Parse args
  # Parse args
  if ! item_id="$(item::name_to_num "$1")"; then
    log::err "Failed to get item ID"
    exit 1
  fi
  local quantity="${2:?How many to craft}"
  quantity=$((quantity * 4 / 5))
  if (( quantity == 0 )); then
    log::err "wtf lol"
    exit 1
  fi
  log::debug "Crafting 80% of desired output because of perks | quantity='$2' adjusted='$quantity'"

  # Do work
  local output
  if ! output="$(worker "go=craftitem" "id=${item_id}" "qty=${quantity}")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi

  # Validate output
  if [ "$output" == "success" ]; then
    log::info "Successfully crafted | item='$1/$item_id' quantity='$quantity'"
  elif [ "$output" == "cannotafford" ]; then
    log::err "Missing a resource necessary to craft this"
    exit 1
  else
    log::warn "Unknown output to craft | output='$output' output='$output'"
    set -x
    [ "$output" == "DEBUG IN TRACE" ] && true
    set +x
    exit 1
  fi
}
