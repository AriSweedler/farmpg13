function set_farmseed() {
  local item item_nr
  item="${1:?}"
  if ! item_nr="$(item::name_to_num "${item}_seeds")"; then
    log::err "Failed to convert item name to num | item='$item'"
    return 1
  fi

  # Deal with output
  if ! output="$(worker "go=setfarmseedcounts" "id=$item_nr")"; then
    log::err "Failed to invoke worker"
    return 1
  fi
  log::debug "We tried to set farm seed counts | output='$output'"
  if [ "$output" == $'3' ] || [ "$output" == "" ]; then
    # TODO promote this to INFO instead of DEBUG if this is the invoking action
    log::debug "Set farm seed successfully"
  else
    log::warn "Unknown output to setting farm seed | output='$output'"
  fi
}

function harvest() {
  local output
  if ! output="$(worker "go=harvestall" "id=280551")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Harvested all successfully" ;;
    "") log::err "Failed to harvest all | output='$output'" ; return 1;;
    *) log::warn "Unknown output to harvest | output='$output'" ; return 1 ;;
  esac
}

function _normalize_planted() {
  # Exit early if no args
  (( $# == 0 )) && return 1

  # lowercase
  output="$(tr '[:upper:]' '[:lower:]' <<< "$1")"

  # Strip unneeded trailing s
  if [[ "${output: -1}" == "s" ]]; then
    output="${output:0:${#output}-1}"
  fi

  # There's a crop to normalize
  if (( ${#output} > 1 )); then
    case "$output" in
      hop) echo "hops" ;;
      potatoe) echo "potato" ;;
      tomatoe) echo "tomato" ;;
      *) echo "$output" ;;
    esac
    return
  fi

  set -x
  [ "$*" == "DEBUG IN TRACE" ] && true
  set +x
  log::err "Unable to normalize | func='${FUNCNAME[0]}' arg='$1'"
  return 1
}

function plant() {
  local -r item="${1:?}"

  # Set up state
  if ! set_farmseed "$item"; then
    log::err "Failed to set farm seed | item='$item'"
    return 1
  fi

  # Do work
  local output item_response grow_time
  log::debug "About to send plantall req"
  if ! output="$(worker "go=plantall" "id=280551")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Parse response
  case "$output" in
    "|") log::err "Failed to plant | output='$output'" ; return 1;;
    *"|"*) log::debug "Successfully planted | output='$output'" ;;
  esac

  # Parse and then normalize the item
  IFS="|" read -r item_response grow_time <<< "$output"
  if ! nitem="$(_normalize_planted "$item_response")" ; then
    log::err "Failed to normalize item in response | output='$output' item_response='$item_response'"
    return 1
  fi

  # Validate response
  case "$nitem" in
  "$item")
    log::info "Planted all successfully | plant='$nitem' grow_time='$grow_time'"
    echo $(( grow_time + 1 ))
    return 0
    ;;
  ya_hay_plants)
    log::err "There are already plants growing in your farm - we cannot plant more | output='$output'"
    return 1
    ;;
  no_seeds)
    log::err "You do not have any seeds | output='$output' plant='$item'"
    return 1
    ;;
  none)
    log::err "Failed to plant all - we planted none | item='$item' nitem='$nitem' output='$output'"
    return 1
    ;;
  *)
    log::warn "Unknown response to plant req | output='$output' nitem='$nitem' item='$item'"
    return 1
    ;;
  esac
}

function planty() {
  local -r plant="${1:?}"

  if ! item::ensure_have "${plant}_seeds" "$FARMRPG_PLOTS"; then
    log::err "Could not ensure that we have enough seeds | seed='${plant}_seeds' want_to_have='$FARMRPG_PLOTS'"
    return 1
  fi

  local grow_time
  if ! grow_time="$(plant "$plant")"; then
    log::err "Failed to plant | plant='$plant'"
    return 1
  fi

  if [ -z "$grow_time" ]; then
    log::err "No one set 'grow_time' for us"
    return 1
  fi

  sleep "$grow_time"
  log::debug "We are done sleeping"
  harvest
}
