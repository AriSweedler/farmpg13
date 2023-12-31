function _default_env() {
  local -r key="${1:?}"
  local -r val="${!key}"
  local -r default="${2:?}"
  if [ -n "$val" ]; then
    log::warn "Environment variable is set | $key='$val'"
    eval "export $key='$val'"
  else
    log::debug "Environment variable is not set. Using default | key='$key' default='$default'"
    eval "export $key='$default'"
  fi
}

_default_env "FARMRPG_PLOTS" 36
_default_env "FARMRPG_MAX_INVENTORY" 1490
_default_env "FARMRPG_CRAFTING_BOOST" "1.25"
_default_env "FARMRPG_CRAFTWORKS_SLOTS" "2"
_default_env "FARMRPG_VAULT_GUESSES" "5"
_default_env "FARMRPG_FARMING_BOOST" "1.5"
_default_env "FARMRPG_MY_ID" "280551"
_default_env "FARMRPG_MAX_WINE" "150"
_default_env "FARMRPG_MAX_WINE_SILVER" "15,000,000 Silver"
_default_env "FARMRPG_COOKIE_HEADER" "Cookie: pac_ocean=DA46F9EC; HighwindFRPG=IFqdJZwFRqmnzeaViYoVFg%3D%3D%3Cstrip%3E%24argon2id%24v%3D19%24m%3D7168%2Ct%3D4%2Cp%3D1%24ejNWLmtORUpWZzY2QTE5dQ%24r7YpaAYlZoMX1WwL0saZ3fEmiNfhYwW82P60ac2v9A4"
_default_env "FARMRPG_USER_AGENT_HEADER" "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/112.0"
_default_env "FARMRPG_INVENTORY_CACHE" "/Users/ari/Desktop/farmrpg/scraped/inventory.json"
unset _default_env
log::debug "Environment is initialized"
