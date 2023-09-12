LOGFILE="log/farmpg13.log"
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

function log::loud_once() {
  if log::_loud_once::unseen "$@"; then
    log::debug "$@"
  else
    log::warn "$@"
  fi
}

function log::dev() {
  log::_impl --level "dev" -- "[DEVELOPMENT]" "$@"
}

# shellcheck disable=SC2028
function log::_color() {
  case "$1" in
    clear) echo '\e[0m' ;;
    err) echo '\e[31m' ;;
    info) echo '\e[32m' ;;
    warn) echo '\e[33m' ;;
    debug) echo '\e[34m' ;;
    dev) echo '\e[36m' ;;
    *) echo "Unknown argument | func='${FUNCNAME[0]}' arg='$1'" >&2; return 1 ;;
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
    *) echo "Unknown argument in ${FUNCNAME[0]}: '$1'" >&2; return 1 ;;
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

  # Rotate the log if it is getting too big.
  # Create the .log file after this
  # Keep .1.old - .5.old as backups
  if [ -s "$LOGFILE" ] && (( $(wc -l "$LOGFILE" | awk '{print $1}') > 10000 )); then
    mv "$LOGFILE" "$LOGFILE.0.old"
    for i in {4..0}; do
      mv "$LOGFILE.$i.old" "$LOGFILE.$((i+1)).old"
    done
  fi

  # Handle the log
  echo "$log_msg" | _remove_ansii >> "$LOGFILE"
  if [ "$level" == "debug" ]; then
    [ "$DEBUG" != "true" ] && return
  fi
  log_msg="$(log::_handle_prev_msg_state "$log_msg" "$@")"
  echo "$log_msg" >&2
}

function log::_loud_once::unseen() {
  local -r log_msg="${1:?}"
  shift 1

  local loud_once_file
  if ! loud_once_file="$(log::_init_loud_file)"; then
    echo "ERROR:: Failed to init 'loud once' file" >&2
    return 1
  fi

  # If the message shows up in the 'loud once' file, then we do not have to be loud again
  [ -f "$loud_once_file" ] && grep -q "$log_msg" <<< "$(cat "$loud_once_file")"
  local rc=$?
  if (( rc != 0 )); then
    echo "$log_msg" >> "$loud_once_file"
  fi
  return $rc
}

function log::_init_loud_file() {
  dir="./.loud_once_file"
  mkdir -p "$dir"
  # shellcheck disable=SC2012
  while (( $(ls -1 "$dir" | wc -l) > 10 )); do
    rm "$dir/$(ls -1tr "$dir" | head -1)"
  done

  loud_once_file="$dir/log_logs.$$"
  # shellcheck disable=SC2064
  touch "$loud_once_file"
  echo "$loud_once_file"
}

function log::_handle_prev_msg_state() {
  local -r log_msg="${1:?}"
  shift 1

  local prev_msg_file
  if ! prev_msg_file="$(log::_init_prev_msg)"; then
    echo "ERROR:: Failed to init prev_msg_file='$prev_msg_file'" >&2
    return 1
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
  hay_non_ascii "$(sed -e "s/Cat.s Meow/Cat's Meow/g" <<< "$field")"
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
    return 1
  fi
  echo "$prev_msg_dir/$(tty | tr '/' '_')"
}

function log::overwrite_last_log() {
  # Move the cursor up one line
  printf "\033[1F"

  # Clear the entire line
  printf "\033[2K"
}
