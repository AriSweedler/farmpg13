import functools
import signal
import logging
import sys

sys.path.append("../lib")
from lib.log import log

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
                log("Function timed out")
                result = None

            signal.alarm(0)
            return result

        return wrapper

    return decorator
