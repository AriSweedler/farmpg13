# Get an item's recipe
# Pipe HTML from an item's page through this script
from bs4 import BeautifulSoup
import json
import sys

html_content = sys.stdin.read()
soup = BeautifulSoup(html_content, "html.parser")
element = soup.find(attrs={'data-clipboard-text': True})

if element:
    inner_text = element.get_text()
    print(inner_text.replace(' ', '_').lower())
else:
    print("Element with 'data-clipboard-text' attribute not found.")
    exit(1)

