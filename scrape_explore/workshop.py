import json
from bs4 import BeautifulSoup

html_content = ""
with open('scrape_explore/data/workshop.html', 'r') as file:
    html_content = file.read()

# Assuming 'html_content' contains the HTML page content
soup = BeautifulSoup(html_content, 'html.parser')

# Find all elements with both 'data-id' and 'data-name' classes
elements = soup.find_all(attrs={'data-id': True, 'data-name': True})

# Print the elements
answers = dict()
for element in elements:
    data_id = element['data-id']
    data_name = element['data-name']
    answers[data_id] = data_name

# Convert the dictionary to JSON string
print(json.dumps(answers))
