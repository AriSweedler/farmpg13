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

function valut::generate_guess() {
  log::dev "TODO"
  exit 1

  python3 -c "
import sys

def generate_guess(input_data):
    # Valid numbers are digits 0-9
    valid_numbers = [str(i) for i in range(10)]
    # Get all the elements of 'input_data' where the second value is 'G'
    grey_guesses = set([i[2] for i in input_data if i[1] == 'G'])
    yell_guesses = set([(i[0], i[2]) for i in input_data if i[1] == 'Y'])
    blue_guesses = set([(i[0], i[2]) for i in input_data if i[1] == 'B'])
    # Remove the grey guesses from the list of valid numbers
    valid_numbers = [i for i in valid_numbers if i not in grey_guesses]
    return input_data

input_data = [line.strip().split(';') for line in sys.stdin]
print(generate_guess(input_data))
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
  log::debug "Tried to crack code | output='$output'"
  log::debug "Vault status | status='$(vault::status)'"
  vault::status
}

function vault::crack() {
  local guess num_guesses=0
  while (( num_guesses < FARMRPG_VAULT_GUESSES )); do
    # Pick a guess
    if ! guess="$(vault::status | vault::generate_guess)"; then
      local status="$(vault::status)"
      log::err "Failed to generate a guess | status='$status'"
      return 1
    fi

    # Send the guess
    if ! output="$(vault::guess_code "$guess")"; then
      log::err "Failed to guess a code | guess='$guess'"
      return 1
    fi

    # Parse output
    case "$output" in
      *"VAULT UNLOCKED"*)
        log::info "Unlocked vault! | code='$code' num_guesses='$num_guesses'"
        return
        ;;
    esac
  done
}
