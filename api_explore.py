from explore.api import explore_and_check_exhausted
from lib.ensure import ensure
from lib.log import log, set_up_log_handler
import time

def main():
    while True:
        set_up_log_handler()
        ensure(explore_and_check_exhausted)
        # Sleep for 15 seconds
        time.sleep(15)

if __name__ == "__main__":
    main()
