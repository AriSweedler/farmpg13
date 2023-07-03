function pig::feed_one() {
  # Parse args
  local -r pig_nr="${1:?Starting pig}"

  # Do work
  local output
  if ! output="$(worker "go=feedpig" "num=${pig_nr}")"; then
    log::err "Failed to invoke worker"
    exit 1
  fi

  # Validate output
  if [ "$output" == "success" ]; then
    log::info "Successfully fed pig | pig_nr='$pig_nr'"
  elif [ "$output" == "alreadytoday" ]; then
    log::err "You already fed this pig today | pig_nr='$pig_nr'"
    exit 1
  else
    log::warn "Unknown output to pig::feed_one | output='$output'"
    exit 1
  fi
}

function feed_pigs() {
  local -r start="${1:?First pig to feed}"
  local -r amount="${2:?Number of pigs to feed}"
  for ((i = start; i <= start + amount; i++)); do
    pig::feed_one "$i"
  done
  log::info "Fed pigs | amount='$amount'"
}
