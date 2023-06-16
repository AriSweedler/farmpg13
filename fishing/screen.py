import time
import numpy as np
from PIL import ImageGrab
import cv2
import pyautogui

def try_click(rgb_range, s):
    # Capture and mask the screen (based on colors) to define a target
    screen = cv2.cvtColor(np.array(ImageGrab.grab(bbox=(s[0], s[1], s[2], s[3]))), cv2.COLOR_RGBA2RGB)
    target = cv2.inRange(screen, *rgb_range)

    # Compute where to click, then launch the click
    compute_and_click(target, s)


waitings = 0
def compute_and_click(target, screen_bounds):
    global waitings
    nonzero_indices = np.nonzero(target)
    if len(nonzero_indices[0]) < 100:
        print(f"Could not find where to click - {waitings=}", end='\r')
        waitings += 1
        return False

    yis, xis = nonzero_indices
    x = screen_bounds[0] + np.mean(xis)
    y = screen_bounds[1] + np.mean(yis)

    # Do the click
    if waitings != 0:
        print()
    print(f"We wanna clicky! at ({int(x)}, {int(y)})")
    for i in [1, -1, 0]:
        dx = 30*(i)
        click_x = x + dx
        click_y = y
        pyautogui.click(click_x, click_y)
    waitings = 0
    return True


if __name__ == "__main__":
    fish_color_range = [(30, 40, 50), (50, 60, 70)]
    fish_screen_range = [260, 721, 670, 955]
    bob_color_range = [(0, 0, 240), (10, 40, 255)]
    bob_screen_range = [262, 829, 580, 927]
    while True:
        try_click(fish_color_range, fish_screen_range)
        for i in range(2):
            try_click(bob_color_range, bob_screen_range)
