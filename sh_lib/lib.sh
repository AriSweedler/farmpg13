function rapid_tap_delay() {
  printf "%.3f\n" "$(echo "scale=3; ($((RANDOM % 20))+$((RANDOM % 20))+20) / 1000" | bc)"
}
