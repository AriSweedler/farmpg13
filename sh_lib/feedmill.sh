function feed_mill::load() {
  # Parse args
  local -r item="${1:?What item to load}"
  local -r amt="${2:?How many corns to load}"
  if ! captain::ensure_have "$item" "$amt"; then
    log::err "Could not ensure we had enough of the item"
    return 1
  fi

  function encode_feedable_crop() {
    local -r crop="${1:?Crop to encode}"
    case "$crop" in
      corn) echo "45865425578" ;;
      broccoli) echo "45853160650" ;;
      *) log::err "Not a feedable crop (or we do not know the id)" ;;
    esac
  }
  local id
  if ! id=$(encode_feedable_crop "$item") ; then
    log::err "Failed to encode crop as feedmillable"
    return 1
  fi

  # Do work
  local output
  if ! output="$(worker "go=loadfeedmill" "id=$id" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Loaded feed mill successfully" ;;
    "") log::err "Failed to load feed mill" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}
