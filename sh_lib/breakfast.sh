function breakfast_boosted() {
  local plots=$FARMRPG_PLOTS
  (
  local plant_obj seed_obj
  plant_obj="$(item::new::name "carrot")"
  if ! seed_obj="$(item_obj::seed "$plant_obj")"; then
    log::err "Failed to convert item_obj to seed | item_obj='$item_obj'"
    return 1
  fi

  #eat::breakfast_boost
  while true; do
    captain::ensure_have "$PLANT" "$FARMRPG_MAX_INVENTORY"
    # _donate "$PLANT" "$grown"
    sell_max "$PLANT" "$grown"
  done) &

  # shellcheck disable=SC2064
  trap "kill -9 $! &>/dev/null" RETURN EXIT
  sleep 118
}
