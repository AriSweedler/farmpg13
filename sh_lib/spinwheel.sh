function page::spinwheel() {
  farmpg13::page "spin.php"
}

function bs4_helper::spinwheel::spins_today() {
  python3 -c "from bs4 import BeautifulSoup
import sys

def how_many_spins(html):
    soup = BeautifulSoup(html, 'html.parser')
    prev_dev = soup.find('div', class_='content-block-title', string='How this works')
    arr = [item.strip() for item in prev_dev.find_next('div').stripped_strings]
    yhs = 'You have spun'
    for idx, item in enumerate(arr):
      if item == 'You have spun':
        return arr[idx+1]
    return 0

html_content = sys.stdin.read()
spins = how_many_spins(html_content)
print(spins)
"
}

function spinwheel::one() {
  local output
  if ! output="$(worker "go=spinfirst")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # 8|You got:<br/><img src='/img/items/7264.png?1' class='itemimg'><br/>Mug of Beer (x13)
  # -->
  # Mug of Beer (x13)
  local reward
  reward="$(echo "$output" \
    | awk -F'|' '{print $2}' \
    | sed 's|<br/>|\n|g' \
    | awk 'NR == 3' \
    | sed 's|\s\+$||')"
  log::info "Wheel spin results | reward='$reward'"
}


function spinwheel() {
  log::info "I am going to spin the wheel as many times as I need {{{"
  local -r max_spins="${1-1}"

  local i_have_spun
  if ! i_have_spun="$(page::spinwheel | bs4_helper::spinwheel::spins_today)"; then
    log::err "Failed to figure out how many spins we have spun"
    return 1
  fi

  if (( i_have_spun >= max_spins )); then
    log::info "We have spun the wheel enough already }}}"
    return
  fi

  while (( i_have_spun++ < max_spins )); do
    spinwheel::one
    sleep 10
  done

  log::info "I have finished spinning the wheel }}}"
}
