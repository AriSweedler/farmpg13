function vault::status() {
  farmpg13::page "crack.php" | python3 -c "
import sys
from bs4 import BeautifulSoup

html = sys.stdin.read()
soup = BeautifulSoup(html, 'html.parser')
elements = soup.select('.card-content-inner')

for element in elements:
    inner_divs = element.find_all('div', {'class': 'col-25'})
    col = 1
    for div in inner_divs:
        data_type = div['data-type']
        value = ''.join(filter(str.isdigit, div.get_text().strip()))
        print(f'{col};{data_type};{value}')
        col %= 4
        col += 1
"
}

function vault::generate_guess() {
  python3 -c "
import sys

def valid_guesses(input_data):
    # Valid numbers are digits 0-9
    valid_numbers = [str(i) for i in range(10)]
    # Get all the elements of 'input_data' where the second value is 'G'.
    # Eliminate them from guesses
    grey_guesses = set([i[2] for i in input_data if i[1] == 'G'])
    valid_numbers = [i for i in valid_numbers if i not in grey_guesses]

    col_guess = [[], [], [], []]
    for col in range(4):
      blue_guesses_col = set(i[2] for i in input_data if i[1] == 'B' and i[0] == col)
      if len(blue_guesses_col) != 0:
        col_guess[col] = [blue_guesses_col[:]]
        continue
      yell_guesses_col = set(i[2] for i in input_data if i[1] == 'Y' and i[0] == col)
      col_guess[col] = [i for i in valid_numbers if i not in yell_guesses_col]

    return col_guess

def generate_guess(valid_guesses):
  ans = [-1, -1, -1, -1]
  for col_i in range(4):
    for i in valid_guesses[col_i]:
      if i not in ans:
        ans[col_i] = i
  return ans

input_data = [line.strip().split(';') for line in sys.stdin]
print(''.join(generate_guess(valid_guesses(input_data))))
"
}

function vault::guess_code() {
  # Parse args
  local -r code="${1:?}"

  # Validate args
  if [[ ${#code} -ne 4 ]]; then
    log::err "Code must be length 4 | code='$code'"
    return 1
  fi
  if [[ "${code}" =~ [^0-9] ]]; then
    log::err "Code must be digits | code='$code'"
    return 1
  fi

  # Do work
  if ! output="$(worker "go=trycrackcode" "code=$code")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Parse output
  case "$output" in
    *"VAULT UNLOCKED"*)
      log::info "Unlocked vault! | code='$code' num_guesses='$num_guesses'"
      return 0
      ;;
  esac

  log::debug "Tried to crack code | output='$output'"
  log::debug "Vault status | status='$(vault::status)'"
  vault::status
  return 2
}

function vault::crack() {
  log::warn "NOT IMPLEMENTED"
  return

  local guess num_guesses=0
  while (( num_guesses++ < FARMRPG_VAULT_GUESSES )); do
    vstatus="$(vault::status)"
    log::info "status | vstatus='$vstatus'"
    # Pick a guess
    if ! guess="$(vault::status | vault::generate_guess)"; then
      local status="$(vault::status)"
      log::err "Failed to generate a guess $(date)| status='$status'"
      return 1
    fi

    # Send the guess
    local output
    output="$(vault::guess_code "$guess")"
    case $? in
      0) log::info "Cracked the vault!" return ;;
      1) log::err "Failed to guess a code | guess='$guess'"; return 1 ;;
      2) log::warn "Wrong code. Keep guessing"; continue ;;
    esac
  done
}
