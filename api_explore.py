from explore.api import explore_and_check_exhausted
from lib.ensure import ensure
from lib.log import log, set_up_log_handler

if __name__ == "__main__":
    set_up_log_handler()
    ensure(explore_and_check_exhausted)
