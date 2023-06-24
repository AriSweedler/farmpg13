from explore.api import explore_and_check_exhausted
from fishing.screen import catch_fish
from lib.ensure import ensure
from lib.log import log, set_up_log_handler

if __name__ == "__main__":
    set_up_log_handler()
    while True:
        ensure(explore_and_check_exhausted)
        for _ in range(10): catch_fish()
