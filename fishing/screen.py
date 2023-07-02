import datetime
import logging
import sys
import time

import cv2
import numpy as np

sys.path.append("../lib")
from lib.ensure import ensure
from lib.log import log
from lib.screen import get_screen, try_click_target
from lib.timeout import timeout

#FISH_COLOR_RANGE = [(10, 30, 40), (255, 255, 100)] # Everything else
#FISH_COLOR_RANGE = [(40, 20, 0), (80, 30, 30)] # Lake Minerva
FISH_COLOR_RANGE = [(30, 44, 50), (40, 54, 60)] # Crystal River
FISH_SCREEN_RANGE = [260, 670, 670, 900]

def is_bob_present():
    bob_color_range = [(0, 0, 240), (10, 40, 255)]
    bob_screen_range = [262, 829, 580, 927]
    s = bob_screen_range
    logging.debug("Checking if bob is present")

    # Capture and mask the screen (based on colors) to define a target
    target = cv2.inRange(get_screen(bob_screen_range), *bob_color_range)
    if len(np.nonzero(target)[0]) < 100:
        logging.debug("Checking if bob is present. It is not")
        return False
    logging.debug("Checking if bob is present. It is")
    return True

def hook_fish():
    log("Trying to hook a fish")
    global FISH_COLOR_RANGE
    global FISH_SCREEN_RANGE
    return try_click_target(FISH_COLOR_RANGE, FISH_SCREEN_RANGE)


@timeout(1)
def wait_bob():
    while True:
        if is_bob_present():
            return True


@timeout(5)
def bl_click_bob():
    bob_color_range = [(0, 0, 240), (10, 40, 255)]
    bob_screen_range = [262, 829, 580, 927]

    # Check if the bob is there. Should we even move?
    bob_is_present = True
    while bob_is_present:
        log("Trying to reel a fish by hitting the bob")
        try_click_target(bob_color_range, bob_screen_range)
        bob_is_present = is_bob_present()
    log("The bob is no longer present")


def catch_fish():
    while True:
        if not hook_fish():
            continue
        if not wait_bob():
            continue
        break
    bl_click_bob()


from lib.screen import visualize_target
def see_fish():
    log("Trying to see a fish")
    global FISH_COLOR_RANGE
    global FISH_SCREEN_RANGE
    return visualize_target(FISH_COLOR_RANGE, FISH_SCREEN_RANGE)
