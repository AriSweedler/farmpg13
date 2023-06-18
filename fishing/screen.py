import time
import numpy as np
from PIL import ImageGrab
import cv2
import pyautogui
import datetime
import logging


def overwrite_last_log():
    import sys

    # Move the cursor up one
    sys.stdout.write("\033[1F")

###     # [1K clears the line from the beginning of the line up to the current cursor position. It erases any characters from the start of the line to the current cursor position.
    # [2K clears the entire line. It moves the cursor to the beginning of the line and erases any characters on that line.
    sys.stdout.write("\033[2K")
    sys.stdout.flush()
###     # Move the cursor up one and then to the start of the line
###     print("\033[F\r", end="")


last_msg = ""
counted_log_repeatings = 0


def log(msg):
    global counted_log_repeatings
    global last_msg

    # Syntactic sugar
    def is_log_a_repeat(msg, last_msg):
        return msg == last_msg
    # End syntactic sugar

    # Determine if we are on THIS line or PREV line
    log_is_repeat = is_log_a_repeat(msg, last_msg)

    # start message
    if log_is_repeat:
        overwrite_last_log()

    # Time
    current_time = datetime.datetime.now()
    formatted_time = current_time.strftime("%H:%M:%S.%f")
    print(f"[{formatted_time}]", end=" ", file=sys.stderr)

    # msg
    if log_is_repeat:
        counted_log_repeatings += 1
        print(f"{counted_log_repeatings=} times: {msg}", file=sys.stderr)
    else:
        counted_log_repeatings = 0
        print(msg, file=sys.stderr)
    if msg not in last_msg:
        last_msg = msg

def try_click(rgb_range, s):
    # Capture and mask the screen (based on colors) to define a target
    screen = cv2.cvtColor(
        np.array(ImageGrab.grab(bbox=(s[0], s[1], s[2], s[3]))), cv2.COLOR_RGBA2RGB
    )
    target = cv2.inRange(screen, *rgb_range)

    # Compute where to click, then launch the click
    return compute_and_click(target, s)


waitings = 0


def compute_and_click(target, screen_bounds):
    global waitings
    nonzero_indices = np.nonzero(target)
    if len(nonzero_indices[0]) < 100:
        logging.debug(f"Could not find where to click - {waitings=}", end='\r')
        waitings += 1
        return False

    yis, xis = nonzero_indices
    x = screen_bounds[0] + np.mean(xis)
    y = screen_bounds[1] + np.mean(yis)

    # Do the click
    if waitings != 0:
        logging.debug("Waiting on the click")
    logging.debug(f"We wanna clicky! at ({int(x)}, {int(y)})")
    for i in [1, -1, 0]:
        dx = 30 * (i)
        click_x = x + dx
        click_y = y
        pyautogui.click(click_x, click_y)
    waitings = 0
    return True


stamina = 0
state = "bot_left"


def move(quadrant):
    # Find location of move
    global state
    if state == quadrant:
        logging.debug("Didn't move, staying put")
        return
    state = quadrant
    screen = {
        "top_left": [455, 350],
        "top_right": [1300, 350],
        "bot_left": [455, 950],
        "bot_right": [1300, 950],
    }
    location = screen[quadrant]

    # Do the move
    pyautogui.click(*location)
    wait_update_delay()
    logging.warning("We moved")


def tl_click_explore():
    global stamina
    global EXPLORE_COST
    pyautogui.click(500, 440)
    stamina -= EXPLORE_COST


def is_bob_present():
    bob_color_range = [(0, 0, 240), (10, 40, 255)]
    bob_screen_range = [262, 829, 580, 927]
    s = bob_screen_range
    logging.debug("BEGIN_MESSAGE 0001: Checking if bob is present")

    # Capture and mask the screen (based on colors) to define a target
    screen = cv2.cvtColor(
        np.array(ImageGrab.grab(bbox=(s[0], s[1], s[2], s[3]))), cv2.COLOR_RGBA2RGB
    )
    target = cv2.inRange(screen, *bob_color_range)
    if len(np.nonzero(target)[0]) < 100:
        logging.debug("CONTINUE_MESSAGE 0001: Checking if bob is present. It is not")
        return False
    logging.debug("CONTINUE_MESSAGE 0001: Checking if bob is present. It is")
    return True

def is_stamina_left():
    stamina_reading_color_range = [(0, 0, 240), (10, 40, 255)]
    stamina_reading_screen_range = [515, 431, 538, 448]
    s = stamina_reading_screen_range

    # Capture and mask the screen (based on colors) to define a target
    screen = cv2.cvtColor(
        np.array(ImageGrab.grab(bbox=(s[0], s[1], s[2], s[3]))), cv2.COLOR_RGBA2RGB
    )
    target = cv2.inRange(screen, *stamina_reading_color_range)
    cv2.imshow("Masked Target", target)
    if len(np.nonzero(target)[0]) < 100:
        logging.debug("CONTINUE_MESSAGE 0001: Checking if bob is present. It is not")
        return False
    logging.debug("CONTINUE_MESSAGE 0001: Checking if bob is present. It is")
    return True


import hashlib
import requests
EXPLORE_COST = 3
last_digest = ""
def request_explore_is_exhausted():
    # Send the request
    logging.warning("Trying to request an explore")
    url = 'https://farmrpg.com/worker.php?go=explore&id=2'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/112.0',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate, br',
        'Referer': 'https://farmrpg.com/index.php',
        'Origin': 'https://farmrpg.com',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Cookie': 'pac_ocean=FCCF5301; HighwindFRPG=IFqdJZwFRqmnzeaViYoVFg%3D%3D%3Cstrip%3Ee4ba7241425d3e0d14f6e4ba1e0241c993c18f9654e6281e2b2ff8e0c66bbf4cba0a3095929d860bc337f96e700a9ef4f4a45fa02de212a62918d250cd44ca3b',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'no-cors',
        'Sec-Fetch-Site': 'same-origin',
        'Sec-GPC': '1',
        'Content-Length': '0',
        'TE': 'trailers',
        'X-Requested-With': 'XMLHttpRequest'
    }
    response = requests.post(url, headers=headers)

    # Parse if we're gassed outta the response
    global last_digest
    digest = hashlib.sha256(response.text.encode('utf-8')).hexdigest()
    print(f"{digest=} and {last_digest=} for exploring")
    if last_digest == digest:
        return True
    last_digest = digest
    print(f"updated {last_digest=} for exploring")
    return False


def buy_worms():
    logging.debug("I WILL MOVE TO BOT RIGHT")
    move('bot_right')
    logging.debug("I WILL BUY WORMS")
    br_click_to_say_ok()
    logging.debug("OK")
    br_click_to_buy_worms()
    logging.debug("WORMS BOUGHT")
    br_click_to_confirm_buying_worms()
    logging.debug("WORMS CONFIRMED")

    global worms
    worms += INITIAL_WORMS
    
def wait_update_delay():
    UPDATE_DELAY = 0.8
    time.sleep(UPDATE_DELAY)

def br_click_to_buy_worms():
    pyautogui.click(1456, 824)
    wait_update_delay()

def br_click_to_confirm_buying_worms():
    pyautogui.click(1260, 966)
    wait_update_delay()

def br_click_to_say_ok():
    pyautogui.click(1250, 924)
    wait_update_delay()

def bl_click_fish():
    fish_color_range = [(30, 40, 50), (50, 60, 70)]
    fish_screen_range = [260, 721, 670, 955]
    caught = try_click(fish_color_range, fish_screen_range)
    if caught:
        logging.warning("Trying to catch fish. Success")
    else:
        logging.warning("Trying to catch fish. No fish")
    return caught


def ensure(fxn):
    success = False
    while not success:
        success = fxn()


################################################################################
class ScopeGuard:
    def __init__(self, callback):
        self.callback = callback

    def __enter__(self):
        pass

    def __exit__(self, exc_type, exc_value, traceback):
        self.callback()


def curry(func, *args):
    result = func(*args)


################################################################################

################################################################################
import signal
import functools

class TimeoutError(Exception):
    pass

def timeout(seconds):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            def timeout_handler(signum, frame):
                raise TimeoutError(f"Function timed out: {seconds=}")

            signal.signal(signal.SIGALRM, timeout_handler)
            signal.alarm(seconds)

            try:
                logging.debug("Function did not time out, trying to run it")
                result = func(*args, **kwargs)
            except TimeoutError:
                logging.warning("Function timed out")
                result = None

            signal.alarm(0)
            return result

        return wrapper

    return decorator
################################################################################

@timeout(1)
def wait_bob():
    bob_color_range = [(0, 0, 240), (10, 40, 255)]
    bob_screen_range = [262, 829, 580, 927]
    while not is_bob_present():
        logging.warning("Waiting for bob")
    return True

@timeout(5)
def bl_click_bob():
    bob_color_range = [(0, 0, 240), (10, 40, 255)]
    bob_screen_range = [262, 829, 580, 927]

    # Check if the bob is there. Should we even move?
    bob_is_present = wait_bob()
    while bob_is_present:
        logging.warning("Trying to catch a fish by hitting the bob")
        try_click(bob_color_range, bob_screen_range)
        bob_is_present = is_bob_present()

    global stamina
    global worms
    stamina += 5
    worms -= 1
    if worms == 0:
        buy_worms()
    logging.warning(f"Caught a fish. {stamina=}")
    wait_update_delay()


def set_up_log_handler():
    # Create a logging handler (console handler in this example)
    handler = logging.StreamHandler()
    formatter = logging.Formatter('[%(levelname)s] %(message)s')
    handler.setFormatter(formatter)

    # Set the desired log level (INFO in this example)
    handler.setLevel(logging.INFO)

    # Add the handler to the root logger
    logging.getLogger().addHandler(handler)

INITIAL_WORMS = 5
worms = INITIAL_WORMS
if __name__ == "__main__":
    set_up_log_handler()
    bob_screen_range = [262, 829, 580, 927]
    while True:
        ensure(bl_click_fish)
        bl_click_bob()
        ensure(request_explore_is_exhausted)
