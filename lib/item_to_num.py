import json
import logging
import sys
from functools import lru_cache
from typing import Dict, NewType

from pyfzf import FzfPrompt

sys.path.append("../lib")
from lib.log import log

Item = NewType("Item", str)
ItemNum = NewType("ItemNum", int)
Location = NewType("Location", str)
LocationNum = NewType("LocationNum", int)


@lru_cache
def item_to_item_num() -> Dict[Item, ItemNum]:
    with open("scraped/item_to_number.json") as file:
        item_to_location = json.load(file)
        logging.debug(item_to_location)
    return item_to_location


@lru_cache
def item_to_loc_map() -> Dict[Item, Location]:
    with open("scraped/item_to_location.json") as file:
        item_to_location = json.load(file)
        logging.debug(item_to_location)
    return item_to_location


@lru_cache
def loc_to_num_map() -> Dict[Location, LocationNum]:
    with open("scraped/location_to_number.json") as file:
        location_to_number = json.load(file)
    return location_to_number


@lru_cache
def pick_item() -> [Item]:
    fzf = FzfPrompt()
    fzf.single_key = True
    ans = fzf.prompt(list(item_to_loc_map().keys()))[0]
    log(ans)
    return ans


def item_to_num(item: Item) -> ItemNum:
    if item == None:
        raise ValueError("The item cannot be 'None'")

    return item_to_item_num()[item]


def item_to_location_num(item: Item) -> LocationNum:
    if item == None:
        raise ValueError("The item cannot be 'None'")

    desired_loc: Location = item_to_loc_map()[item]
    ans: LocationNum = loc_to_num_map()[desired_loc]
    if ans == -1:
        raise ValueError(f"You cannot explore for {item=} yet. Try something else")
    return ans
