LOGFILE="farmpg13.log"
function log::err() {
  log::_impl --level "err" -- "$@"
}

function log::info() {
  log::_impl --level "info" -- "$@"
}

function log::warn() {
  log::_impl --level "warn" -- "$@"
}

function log::debug() {
  log::_impl --level "debug" -- "$@"
}

# shellcheck disable=SC2028
function log::_color() {
  case "$1" in
    clear) echo '\e[0m' ;;
    err) echo '\e[31m' ;;
    info) echo '\e[32m' ;;
    warn) echo '\e[33m' ;;
    debug) echo '\e[34m' ;;
    *) echo "Unknown argument | func='${FUNCNAME[0]}' arg='$1'" >&2; exit 1 ;;
  esac
}

function _remove_ansii() {
  awk '{ gsub(/\033\[[0-9;]*m/, ""); print $0 }'
}

# shellcheck disable=SC2059
function log::_impl() {
  # Parse args
  local level
  # TODO put this macro into my snippet library
  # $while_args_left_do_case_in
  # $while_args_left_done
  while (( $# > 0 )); do case "$1" in
    --level) level="$2"; shift 2 || exit 40 ;;
    --) shift 1 && break ;;
    *) echo "Unknown argument in ${FUNCNAME[0]}: '$1'" >&2; exit 1 ;;
  esac ; done

  # Create the log
  local log_msg
  log_msg="$(
    printf "$(log::_color "$level")"
    printf "[$level] "
    printf "[farmpg13] "
    printf "[$(date -u +"%Y-%m-%d_%H:%M:%S.%N")] "
    printf "[$(log::_caller)] "
    printf "%s" "$*"
    printf "$(log::_color "clear")\n"
  )"

  # Handle the log
  echo "$log_msg" | _remove_ansii >> "$LOGFILE"
  if [ "$level" == "debug" ]; then
    return
  fi
  log_msg="$(log::_handle_prev_msg_state "$log_msg" "$@")"
  echo "$log_msg" >&2
}

function log::_handle_prev_msg_state() {
  local -r log_msg="${1:?}"
  shift 1

  local prev_msg_file
  if ! prev_msg_file="$(log::_init_prev_msg)"; then
    echo "ERROR:: Failed to init prev_msg_file='$prev_msg_file'" >&2
    exit 1
  fi

  # If it is a repeated message, then overwrite the last log
  local ans="$log_msg"
  touch "$prev_msg_file" "$prev_msg_file.repeated"
  LOG_REPEAT=$(cat "$prev_msg_file.repeated")
  if [ "$(cat "$prev_msg_file")" == "$*" ]; then
    ans="$log_msg - repeated $((++LOG_REPEAT)) times"
    log::overwrite_last_log
  else
    LOG_REPEAT=0
  fi
  printf "%s" "$LOG_REPEAT" > "$prev_msg_file.repeated"

  # Update state
  printf "%s" "$*" > "$prev_msg_file"

  # Return
  printf "%s" "$ans"
}

function log::_caller() {
  local stackdepth=0
  while log::_unstackable "${FUNCNAME[$stackdepth]}"; do
    ((stackdepth++))
  done
  echo "${FUNCNAME[$stackdepth]}"
}

function log::_unstackable() {
  grep -q "log::" <<< "$1" && return 0
  grep -q "::_" <<< "$1" && return 0
  grep -q "^_" <<< "$1" && return 0
  return 1
}

# shellcheck disable=SC2059
function log::field() {
  local -r field="${1?}"
  function hay_non_ascii() {
    [ -z "$*" ] && return 2
    if [[ "$*" == *[![:ascii:]]* ]]; then
      return 1
    else
      return 0
    fi
  }
  hay_non_ascii "$field"
  case $? in
  0) printf "%s" "$field" ;;
  1)
    printf "NOT_ASCII"
    # set -x
    # [ "$field" == "DEBUG IN TRACE" ] && true
    # set +x
    ;;
  2) printf "NULL" ;;
  esac
}

function log::_init_prev_msg() {
  local prev_msg_dir="./.prev_msg"
  if ! mkdir -p "$prev_msg_dir"; then
    echo "ERROR:: Failed to create prev_msg_dir='$prev_msg_dir'" >&2
    exit 1
  fi
  echo "$prev_msg_dir/$(tty | tr '/' '_')"
}

function log::overwrite_last_log() {
  # Move the cursor up one line
  printf "\033[1F"

  # Clear the entire line
  printf "\033[2K"
}
