# Get a recipe by piping the HTML from an item's page through this script
#
# Example:
#
#     ./bin/cli item 72 | python3 scrape_explore/recipe.py
#
from bs4 import BeautifulSoup
import json
import sys

html_content = sys.stdin.read()
soup = BeautifulSoup(html_content, "html.parser")

# Find the section of the item where the crafting is
crafting_recipe_div = soup.find(lambda tag: tag.text == "Crafting Recipe")
if crafting_recipe_div == None:
    print("null")
    exit(1)

# Get the chunk of elements that contain the recipe entries
list_block_div = crafting_recipe_div.find_next_sibling("div", class_="list-block")

# Extract them
li_elements = list_block_div.find_all("li")
result = {}
for li_element in li_elements:
    id_value = li_element.a["href"].split("=")[1]
    item_after = li_element.find("div", class_="item-after").text.strip()
    result[id_value] = int(item_after[:-1])

# Print the resulting dictionary
print(result)
