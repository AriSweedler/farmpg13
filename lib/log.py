import datetime
import logging
import sys


def overwrite_last_log():
    # Move the cursor up one
    sys.stdout.write("\033[1F")

    # [2K clears the entire line. It moves the cursor to the beginning of the
    # line and erases any characters on that line.
    sys.stdout.write("\033[2K")
    sys.stdout.flush()


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
        print(f"{msg} - repeated {counted_log_repeatings} times", file=sys.stderr)
    else:
        counted_log_repeatings = 0
        print(msg, file=sys.stderr)
    if msg not in last_msg:
        last_msg = msg


def set_up_log_handler():
    # Create a logging handler (console handler in this example)
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(levelname)s] %(message)s")
    handler.setFormatter(formatter)

    # Set the desired log level (INFO in this example)
    handler.setLevel(logging.INFO)

    # Add the handler to the root logger
    logging.getLogger().addHandler(handler)
