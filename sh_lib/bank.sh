function bank::deposit() {
  # Parse args
  local amt="${1:?amt to deposit}"

  # Do work
  local output
  if ! output="$(worker "go=depositsilver" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Successfully deposited silver | amt='$amt'" ;;
    "") log::err "Failed to deposit silver" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function bank::withdraw() {
  # Parse args
  local amt="${1:?amt to withdraw}"

  # Do work
  local output
  if ! output="$(worker "go=withdrawalsilver" "amt=$amt")"; then
    log::err "Failed to invoke worker"
    return 1
  fi

  # Deal with output
  case "$output" in
    success) log::info "Successfully withdrew silver | amt='$amt'" ;;
    "") log::err "Failed to withdraw silver" ; return 1;;
    *) log::warn "Unknown output to '${FUNCNAME[0]}' | output='$output'" ; return 1 ;;
  esac
}

function bank::manager::helper() {
  farmpg13::page "bank.php" | python3 -c "
from bs4 import BeautifulSoup
import sys

def get_desired_amount(html):
    soup = BeautifulSoup(html, 'html.parser')
    prev_dev = soup.find('div', class_='content-block-title', string='About the bank')
    div = prev_dev.find_next('div', class_='card-content-inner')
    percent, max_interest, *_ = div.find_all('strong')
    percent = int(percent.get_text().strip('%')) / 100
    max_interest = int(max_interest.get_text().replace(',', ''))
    desired_amount = int((1/percent) * max_interest)
    return desired_amount

def get_current_amount(html):
    soup = BeautifulSoup(html, 'html.parser')
    next_div = soup.find('a', href='bankuserhistory.php')
    s = next_div.find_previous('strong')
    return int(s.get_text().replace(',', '').strip(' Silver'))

def action(put_in_amt):
  if put_in_amt < 0:
    return f'bank::withdraw {-1*put_in_amt}'
  elif put_in_amt > 0:
    return f'bank::deposit {put_in_amt}'
  else:
    return 'log::info bank is good'

html_content = sys.stdin.read()
desired_amount = get_desired_amount(html_content)
current_amount = get_current_amount(html_content)
print(action(desired_amount - current_amount))
"
}

function bank::manager() {
  eval "$(bank::manager::helper)"
}

#<div class="content-block-title">About the bank</div>
#<div class="card">
#<div class="card-content">
#<div class="card-content-inner">
#                    The bank allows you to deposit your Silver so that it can gain interest when you are not playing.
#                    Right now, Silver will grow by <strong>1%</strong> every day.
#                    The most you can earn each day from interest is <strong>8,000,000</strong> Silver.
#                    This will occur in <strong>22h 1m 37s</strong>.
#                    </div>
