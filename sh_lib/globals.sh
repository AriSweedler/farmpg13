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

_default_env "FARMRPG_PLOTS" 32
_default_env "FARMRPG_MAX_INVENTORY" 602
_default_env "FARMRPG_CRAFTING_BOOST" "1.25"
_default_env "FARMRPG_COOKIE_HEADER" "Cookie: pac_ocean=FCCF5301; HighwindFRPG=IFqdJZwFRqmnzeaViYoVFg%3D%3D%3Cstrip%3Ee4ba7241425d3e0d14f6e4ba1e0241c993c18f9654e6281e2b2ff8e0c66bbf4cba0a3095929d860bc337f96e700a9ef4f4a45fa02de212a62918d250cd44ca3b"
_default_env "FARMRPG_USER_AGENT_HEADER" "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/112.0"
unset _default_env
