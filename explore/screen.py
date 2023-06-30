import time

import pyautogui


def tl_click_explore():
    global EXPLORE_COST
    pyautogui.click(500, 440)

screen = {
    'top_left': [455, 350],
    'top_right': [960, 217],
    'bot_left': [477, 950],
    'bot_right': [723, 950]
}
while True:
    location = screen['top_left']
    pyautogui.click(*location)
