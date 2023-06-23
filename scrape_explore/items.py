import json
from pyfzf import FzfPrompt

# Read the JSON file as a JSON object
with open("scrape_explore/items.json") as file:
    item_to_location = json.load(file)

with open("scrape_explore/location_to_number.json") as file:
    location_to_number = json.load(file)

fzf = FzfPrompt()
fzf.single_key = True
selected_option = fzf.prompt(list(item_to_location.keys()))[0]
desired_loc = item_to_location[selected_option]
ans = location_to_number[desired_loc]
print(ans)
