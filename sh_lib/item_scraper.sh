# Used to get the:
# * recipe when piped to 'scraped/scripts/recipe.py'
# * name when piped to 'scraped/scripts/item.sh'
function page::item() {
  local -r item_id="${1:?Item id}"
  log::info "Getting page for item | item_id='$item_id'"
  farmpg13::page "item.php?id=$item_id"
}

# Input: $item_id
# Output: echo "$item_name;$recipe"
function scrape::item::one() {
  local -r item_id="${1:?Item id}"

  local page
  if ! page="$(page::item "$item_id")"; then
    log::err "Failed to cURL item page | item_id='$item_id'"
    return 1
  fi

  local item_name recipe
  if ! item_name="$(python3 "scraped/scripts/item_to_name.py" <<< "$page")"; then
    log::err "Failed to get name for item | item_id='$item_id'"
    return 1
  fi
  if ! recipe="$(python3 "scraped/scripts/item_to_recipe.py" <<< "$page")"; then
    log::err "Failed to get recipe for item | item='$item_name/$item_id'"
    return 1
  fi

  # Return
  echo "$item_name;$recipe"
}

function json::add_key_val() {
  local -r file="${1:?JSON file to add to}"
  local -r key="${2:?key}"
  local -r value="${3:?value}"

  # Ensure JSON file exists
  if [ ! -f "$file" ]; then
    log::err "JSON file not found | file='$file'"
    return 1
  fi

  # Use jq to add the key-value pair to the JSON file. Support
  # 1) null
  # 2) objects
  # 3) regular strings
  if [ "$value" == "null" ]; then
    jq --arg k "$key" \
      '. + { ($k): null }' \
      < "$file" > "$file.new"
  elif grep -q '{' <<< "$value"; then
    jq --arg k "$key" --arg v "$(echo "$value" | tr "'" '"')" \
      '. + { ($k): $v|fromjson }' \
      < "$file" > "$file.new"
  else
    jq --arg k "$key" --arg v "$value" \
      '. + { ($k): $v }' \
      < "$file" > "$file.new"
  fi
  local rc=$?
  if (( rc != 0 )); then
    log::err "jq command to add kv to json failed"
    return 1
  fi

  # Atomically swap
  mv "$file.new" "$file"
  log::debug "Added key with value to file | file='$file' key='$key' value='$value'"
}

# Run this to update:
# * item_number_to_recipe.json
# * item_to_number.json
function scrape::item::all() {
  # Get the relevant files
  local JSON_id_recipe JSON_name_id
  JSON_id_recipe="./scraped/item_number_to_recipe.json"
  JSON_name_id="./scraped/item_to_number.json"

  # Reset them
  echo '{}' > "$JSON_id_recipe"
  echo '{}' > "$JSON_name_id"

  # Scrape each item and fill out the data
  local item_descr
  for item_id in {1..1000}; do
    # Scrape information
    if ! item_descr="$(scrape::item::one "$item_id")"; then
      log::warn "No item description | item_id='$item_id'"
      continue
    fi

    # Split fields, then record it into the JSON files
    IFS=";" read -r item_name recipe <<< "$item_descr"
    json::add_key_val "$JSON_name_id" "$item_name" "$item_id"
    json::add_key_val "$JSON_id_recipe" "$item_id" "$recipe"
  done
}
