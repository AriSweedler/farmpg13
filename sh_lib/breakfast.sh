function breakfast_boosted() {
  local plots=$FARMRPG_PLOTS
  (
  harvest
  #eat::breakfast_boost
  local -r PLANT="carrot"
  local grown=0
  while true; do
    plant "$PLANT" &>/dev/null || buy "${PLANT}_seeds" 999
    sleep 0.01
    harvest
    sleep 0.02
    grown=$(( grown + plots ))
    log::info "BB helped us grow the plant | grown='$grown' plant='$PLANT'"
    if (( grown > 600 )); then
      # _donate "$PLANT" "$grown"
      sell "$PLANT" "$grown"
      buy "${PLANT}_seeds" "$grown"
      grown=0
    fi
  done) &

  # shellcheck disable=SC2064
  trap "kill -9 $! &>/dev/null" RETURN EXIT
  sleep 118
}
