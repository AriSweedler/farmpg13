from typing import Callable


def ensure(fxn: Callable[..., bool]):
    success = False
    while not success:
        success = fxn()
