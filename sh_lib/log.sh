function log::color() {
  case "$1" in
    clear) echo '\e[0m' ;;
    err) echo '\e[31m' ;;
    info) echo '\e[32m' ;;
    warn) echo '\e[33m' ;;
    debug) echo '\e[34m' ;;
    *) echo "Unknown argument | func='${FUNCNAME[0]}' arg='$1'" >&2; exit 1 ;;
  esac
}

LOGFILE="farmpg.log"
function ansi_tee() {
  function remove_ansii() {
    awk '{ gsub(/\033\[[0-9;]*m/, ""); print $0 }'
  }
  cat - >&2
  cat - | remove_ansii >> "$LOGFILE"
}

function log::err() { log::_impl --level "err" -- "$@" | ansi_tee ; }
function log::info() { log::_impl --level "info" -- "$@" | ansi_tee ; }
function log::warn() { log::_impl --level "warn" -- "$@" | ansi_tee ; }
function log::debug() { log::_impl --level "debug" -- "$@" | ansi_tee ; }

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

  # Print
  printf "$(log::color "$level")"
  printf "[farmpg13] "
  printf "[$(date -u +"%Y-%m-%d_%H:%M:%S.%N")] "
  printf "[TODO_function] "
  printf "%s" "$*"
  printf "$(log::color "clear")\n"
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
