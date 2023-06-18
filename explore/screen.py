import pyautogui
import time

screen = {
    'top_left': [455, 350],
    'top_right': [960, 217],
    'bot_left': [477, 950],
    'bot_right': [723, 950]
}
while True:
    location = screen['top_left']
    time.sleep(3)
    pyautogui.click(*location)
    pyautogui.click(*location)
