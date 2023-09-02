function page::cellar() {
  farmpg13::page "cellar.php?id=$FARMRPG_MY_ID"
}

function cellar::store_wine::one() {
  local output
  if ! output="$(worker "go=storewine" "id=$FARMRPG_MY_ID")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  case "$output" in
    success) log::info "Successfully stored wine" ;;
    *) log::err "Failed to store wine" ; return 1 ;;
  esac
}

function cellar::store_wine::all() {
  # Store as much wine as we can
  local bottles_in_cellar
  bottles_in_cellar="$(page::cellar | grep -o 'In Cellar (.*)' | awk -F '[()]' '{print $2}')"
  while (( bottles_in_cellar++ < FARMRPG_MAX_WINE )); do
    cellar::store_wine::one
  done
}

function cellar::sell_wine::id() {
  # Parse args
  local -r id="${1:?}"

  # Do work
  local output
  if ! output="$(worker "go=sellwine" "id=$id")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Parse output
  local price
  price="$(echo "$FARMRPG_MAX_WINE_SILVER" | tr -d ', Silver')"
  case "$output" in
    $price) log::info "Sold a bottle of wine | price='$price'" ;;
    *) log::err "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function cellar::sell_wine::all() {
  # Extract as much wine as we can
  local extract_me
  for id in $(page::cellar | grep -o ".*$FARMRPG_MAX_WINE_SILVER.*" | grep -o 'data-id=".*"' | awk -F '"' '{print $2}'); do
    cellar::sell_wine::id "$id"
  done
}

function captain::cellar() {
  log::info "Selling all wine worth max value | max_wine_value='$FARMRPG_MAX_WINE_SILVER'"
  cellar::sell_wine::all
  log::info "Making sure we have max win in cellar | max_wine='$FARMRPG_MAX_WINE'"
  cellar::store_wine::all
  log::info "Celler is in optimal state"
}
