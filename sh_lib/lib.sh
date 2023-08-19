function rapid_tap_delay() {
  printf "%.3f\n" "$(echo "scale=3; ($((RANDOM % 20))+$((RANDOM % 20))+20) / 1000" | bc)"
}

function is_in_array() {
  local target="$1"
  shift
  for val in "${@}"; do
      [ "$val" == "$target" ] && return 0
  done
  return 1  # Target value not found in the array
}

