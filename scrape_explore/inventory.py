import json
from bs4 import BeautifulSoup

html_content = ""
with open('scrape_explore/data/inventory.html', 'r') as file:
    html_content = file.read()

soup = BeautifulSoup(html_content, 'html.parser')

link_elements = soup.select('a.item-link')
answers = dict()
for link_element in link_elements:
    href = link_element['href']
    id_value = href.split('=')[1]

    item_after_element = link_element.select_one('div.item-after')
    value = str(item_after_element.get_text())
    print("ID:", id_value)
    print("Value:", value)
    print()
    answers[id_value] = value

# Convert the dictionary to JSON string
print(json.dumps(answers))
