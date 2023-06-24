import logging

import cv2
import numpy as np
import pyautogui
from PIL import ImageGrab


def get_screen(screen_bounds):
    return cv2.cvtColor(
        np.array(
            ImageGrab.grab(
                bbox=(
                    screen_bounds[0],
                    screen_bounds[1],
                    screen_bounds[2],
                    screen_bounds[3],
                )
            )
        ),
        cv2.COLOR_RGBA2RGB,
    )

def visualize_target(rgb_range, s):
    # Capture and mask the screen (based on colors) to define a target
    target = cv2.inRange(get_screen(s), *rgb_range)
    cv2.imshow("target", target)

    key = cv2.waitKey(1)
    if key == 27:  # Exit on Esc key press
        return


def try_click_target(rgb_range, s):
    # Capture and mask the screen (based on colors) to define a target
    target = cv2.inRange(get_screen(s), *rgb_range)

    # Compute where to click, then launch the click
    nonzero_indices = np.nonzero(target)
    if len(nonzero_indices[0]) < 100:
        return False

    yis, xis = nonzero_indices
    x = s[0] + np.mean(xis)
    y = s[1] + np.mean(yis)

    # Do the click
    logging.debug(f"We wanna clicky! at ({int(x)}, {int(y)})")
    for i in [1, -1, 0]:
        dx = 30 * (i)
        click_x = x + dx
        click_y = y
        pyautogui.click(click_x, click_y)
    return True
