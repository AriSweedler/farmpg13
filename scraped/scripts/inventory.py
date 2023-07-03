# Pipe the HTML page for your inventory through this script and get a JSON
# object containing all that information.
#
# This is done with the sh cli with the 'inventory' function
from bs4 import BeautifulSoup
import json
import sys

html_content = sys.stdin.read()
soup = BeautifulSoup(html_content, 'html.parser')

link_elements = soup.select('a.item-link')
answers = dict()
for link_element in link_elements:
    href = link_element['href']
    id_value = href.split('=')[1]

    item_after_element = link_element.select_one('div.item-after')
    value = int(item_after_element.get_text())
    answers[id_value] = value

# Convert the dictionary to JSON string
print(json.dumps(answers))
