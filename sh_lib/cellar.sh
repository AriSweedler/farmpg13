function cellar::store_wine() {
  local output
  if ! output="$(worker "go=storewine" "id=280551")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully stored wine" ;;
    *) log::err "Failed to store wine" ; return 1 ;;
  esac
}
