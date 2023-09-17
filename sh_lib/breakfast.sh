function breakfast_boosted() {
  (
  #eat::breakfast_boost
  while true; do
    captain::ensure_have "$PLANT" "$FARMRPG_MAX_INVENTORY"
    # _donate "$PLANT" "$grown"
    sell_max "$PLANT"
  done) &

  # shellcheck disable=SC2064
  trap "kill -9 $! &>/dev/null" RETURN EXIT
  sleep 118
}
