function temple::sacrifice_item() {
  local sac_item amt item_obj
  sac_item="${1:?What item to sacrifice}"

  item_obj="$(item::new::name "$sac_item")"
  if [ -z "$item_obj" ]; then
    log::err "Failed to normalize item name for temple sacrifice"
    return 1
  fi

  if ! amt="$(item_obj::inventory "$item_obj")"; then
    log::err "Could not figure out how much to sacrifice"
    return 1
  fi

  if ! output="$(worker "go=sacrificeitem" "item=$sac_item" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Sacrificed successfully | sac_item='$sac_item' amt='$amt'" ;;
    "") log::err "Failed to sacrifice" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function captain::temple() {
  while (( $(item_obj::inventory "watermelon") < 900 )); do
    captain::ensure_have watermelon 500
    log::info "Donating"
    temple::sacrifice_item "Watermelon"
    temple::sacrifice_item "Yellow Watermelon"
    log::info "Nice donation"
  done
}
