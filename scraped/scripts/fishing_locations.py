# Pipe the HTML page for your fishing abilities through this script and get a
# JSON object containing a map of location to number
from bs4 import BeautifulSoup
import json
import sys

html_content = sys.stdin.read()
soup = BeautifulSoup(html_content, 'html.parser')

fishing_locations = soup.find(string='Fishing Locations')
link_elements = fishing_locations.find_all_next('a', class_="item-link")

ans = dict()
for link_element in link_elements:
    href = link_element.get('href')

    # If href contains 'item.php' then set the ID to -1
    if href.find('id') == -1:
        continue
    loc_id = href.split('=')[1]
    if href.find('item.php') != -1:
        loc_id = -1

    # Get the location name. Lowercase it and turn ' ' into '_'s
    item_title = link_element.find_next('div', class_='item-title')
    location_name = item_title.contents[0].lower().replace(' ', '_')

    # Format ans
    ans[location_name] = loc_id

# Convert the list of href attributes to a JSON string
print(json.dumps(ans))
