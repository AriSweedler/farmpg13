import os
from explore.api import explore_and_check_exhausted
from fishing.screen import catch_fish, see_fish
from lib.ensure import ensure
from lib.log import log, set_up_log_handler

def normal_fishing_loop():
    worms=0
    while True:
        # Periodically explore
        if worms % 5 == 0:
            ensure(explore_and_check_exhausted)

        # Buy worms when we need to
        if worms <= 20:
            os.system('./bin/cli buy worms 999')
            worms = 500

        # Catch a fish
        catch_fish()
        worms -= 1

def main():
    set_up_log_handler()

    while os.environ.get('FARMPG_VISUALIZE'):
        see_fish()

    normal_fishing_loop()

if __name__ == "__main__":
    main()
