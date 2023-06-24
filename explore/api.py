import hashlib
import os
import sys
from functools import lru_cache

import requests

sys.path.append("../lib")
from lib.item_to_num import (Item, Location, item_to_location_num, item_to_num,
                             pick_item)
from lib.log import log


# Get the value of the environment variable
@lru_cache
def figure_explored_item():
    item = os.environ.get("EXPLORED_ITEM")
    explore_loc_num = 1
    if item is None or item == "choose":
        item = pick_item()
    return item


def api_explore_loc(explore_loc_num: int):
    url = f"https://farmrpg.com/worker.php?go=explore&id={explore_loc_num}"
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/112.0",
        "Accept": "*/*",
        "Accept-Language": "en-US,en;q=0.5",
        "Accept-Encoding": "gzip, deflate, br",
        "Referer": "https://farmrpg.com/index.php",
        "Origin": "https://farmrpg.com",
        "DNT": "1",
        "Connection": "keep-alive",
        "Cookie": "pac_ocean=FCCF5301; HighwindFRPG=IFqdJZwFRqmnzeaViYoVFg%3D%3D%3Cstrip%3Ee4ba7241425d3e0d14f6e4ba1e0241c993c18f9654e6281e2b2ff8e0c66bbf4cba0a3095929d860bc337f96e700a9ef4f4a45fa02de212a62918d250cd44ca3b",
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "no-cors",
        "Sec-Fetch-Site": "same-origin",
        "Sec-GPC": "1",
        "Content-Length": "0",
        "TE": "trailers",
        "X-Requested-With": "XMLHttpRequest",
    }
    return requests.post(url, headers=headers)


last_digest = ""
def item_to_loc(item: Item) -> Location:
    explore_loc_num = item_to_num(item)
    return explore_loc_num


def explore_and_check_exhausted():
    # What item do we wanna explore for?
    item = figure_explored_item()
    if item == "do_not_explore":
        return True

    # Where should we go exploring for it?
    loc_num = item_to_location_num(item)

    # Send the request
    response = api_explore_loc(loc_num)

    # Parse if we're gassed outta the response
    global last_digest
    digest = hashlib.sha256(response.text.encode("utf-8")).hexdigest()
    if last_digest == digest:
        return True  # We are exhausted
    last_digest = digest
    log(f"Explored hoping for {item}/{loc_num}")
    return False  # We are not exhausted yet
