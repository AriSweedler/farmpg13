import time
import numpy as np
from PIL import ImageGrab
import cv2
import pyautogui

SCREEN_X=260
SCREEN_Y=744
SCREEN_BX=670
SCREEN_BY=980

def click_either(*args):
    for arg in args:
        try_click(arg)


def try_click(rgb_range):
    # Capture and mask the screen (based on colors) to define a target
    screen = cv2.cvtColor(np.array(ImageGrab.grab(bbox=(SCREEN_X, SCREEN_Y, SCREEN_BX, SCREEN_BY))), cv2.COLOR_RGBA2RGB)
    target = cv2.inRange(screen, *rgb_range)

    # Compute where to click, then launch the click
    compute_and_click(target)


def compute_click(target):
    nonzero_indices = np.nonzero(target)
    if len(nonzero_indices[0]) < 100:
        print("Could not find where to click")
        return False

    yis, xis = nonzero_indices
    x = SCREEN_X + np.mean(xis)
    y = SCREEN_Y + np.mean(yis)

    # Do the click
    for dx in [-20, 0, 20]:
        click_x = x + dx
        click_y = y
        print(f"We wanna clicky! at ({click_x}, {click_y})")
        pyautogui.click(click_x, click_y)
    return True


if __name__ == "__main__":
    fish_range = [(30, 40, 50), (50, 60, 70)]
    bob_range = [(0, 0, 240), (50, 50, 255)]
    while True:
        click_either(fish_range, bob_range)
