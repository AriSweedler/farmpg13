from explore.api import explore_and_check_exhausted
from fishing.screen import catch_fish, see_fish
from lib.ensure import ensure
from lib.log import log, set_up_log_handler

worms=400
if __name__ == "__main__":
    set_up_log_handler()
    #ensure(explore_and_check_exhausted)
    while worms >= 0:
        if worms % 5 == 0:
            pass
            ensure(explore_and_check_exhausted)
        catch_fish()
        worms -= 1
