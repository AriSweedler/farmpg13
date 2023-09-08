function captain::pigs() {
  # TODO:
  # Buy max pigs
  # Figure out how many pigs we can sell (respect inventory)
  # Sell bacon

  # Feed all the pigs
  gm::feed_pigs

  # Place enough items in feeder to get back to max feed
  feedmill::load
}

function gm::feed_pigs() {
  local output
  if ! output="$(worker "go=feedallpigs")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully fed all the pigs OwO" ;;
    *) log::err "Failed to feed piggies (L)" ; return 1 ;;
  esac
}


