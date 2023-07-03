function set_farmseed() {
  local item item_nr
  item="${1:?}"
  if ! item_nr="$(item::name_to_num "${item}_seeds")"; then
    log::err "Failed to convert item name to num | item='$item'"
    exit 1
  fi

  # Deal with output
  if ! output="$(worker "go=setfarmseedcounts" "id=$item_nr")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi
  log::debug "We tried to set farm seed counts | output='$output'"
  if [ "$output" == $'3' ]; then
    # TODO promote this to INFO instead of DEBUG if this is the invoking action
    log::debug "Set farm seed successfully"
  elif [ "$output" == "" ]; then
    log::err "Failed to set farm seed"
    exit 1
  else
    log::warn "Unknown output to setting farm seed | output='$output'"
  fi
}

function harvest() {
  local output
  if ! output="$(worker "go=harvestall" "id=280551")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi

  # Deal with output
  if [ "$output" == $'\003\003\200success\003' ]; then
    log::info "Harvested all successfully"
  elif [ "$output" == "" ]; then
    log::err "Failed to harvest all | output='$output'"
    exit 1
  else
    log::warn "Unknown output to harvest | output='$output'"
  fi
}

function _normalize_planted() {
  (( $# == 0 )) && return
  if [[ "${output: -1}" == "s" ]] && (( ${#output} > 1 )); then
    local length ans
    length=${#output}
    ans="$(echo "${output:0:length-1}" | tr '[:upper:]' '[:lower:]')"
    case "$ans" in
      hop) echo "hops" ;;
      potatoe) echo "potato" ;;
      *) echo "$ans" ;;
    esac
    return
  fi

  set -x
  [ "$*" == "DEBUG IN TRACE" ] && true
  set +x
  log::err "Unable to normalize | func='${FUNCNAME[0]}' arg='$1'"
  exit 1
}

function plant() {
  local -r item="${1:?}"

  # Set up state
  if ! set_farmseed "$item"; then
    log::err "Failed to set farm seed | item='$item'"
    exit 1
  fi

  # Do work
  local output item_response grow_time
  log::debug "About to send plantall req"
  if ! output="$(worker "go=plantall" "id=280551")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi

  # Parse response
  IFS="|" read -r item_response grow_time <<< "$output"
  if ! nitem="$(_normalize_planted "$item_response")" ; then
    log::err "Failed to normalize item in response | output='$output' item_response='$item_response'"
    exit 1
  fi

  # Validate response
  case "$nitem" in
  "$item")
    log::info "Planted all successfully | plant='$nitem' grow_time='$grow_time'"
    export GROW_TIME=$(( grow_time + 1 ))
    ;;
  ya_hay_plants)
    log::err "There are already plants growing in your farm - we cannot plant more | output='$output'"
    exit 1
    ;;
  no_seeds)
    log::err "You do not have any seeds | output='$output' plant='$item'"
    return 1
    ;;
  none)
    log::err "Failed to plant all - we planted none | item='$item' nitem='$nitem' output='$output'"
    exit 1
    ;;
  *)
    log::warn "Unknown response to plant req | output='$output' nitem='$nitem' item='$item'"
    set -x
    [ "$item_response" == "DEBUG IN TRACE" ] && true
    set +x
    ;;
  esac
}

function planty() {
  local -r plant="${1:?}"
  local item_nr

  if ! buy "${plant}_seeds" "$FARMRPG_PLOTS"; then
    log::err "Failed to buy seeds for plant | plant='$plant'"
    exit 1
  fi
  if ! plant "$plant"; then
    log::err "Failed to plant | plant='$plant'"
    exit 1
  fi
  (
    sleep "$GROW_TIME"
    log::debug "We are done sleeping"
    harvest
    planty "$plant"
  ) &
  harvester_pid="$!"
  log::info "Sleeping until the plant is grown | GROW_TIME='$GROW_TIME' harvester_pid='$harvester_pid'"
}
