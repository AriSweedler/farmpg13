import argparse

import requests
from bs4 import BeautifulSoup


def main(url):
    # Print the location that we're exploring
    location = url.strip("/").split("/")[-1]
    # print("#" * 80)
    # print(f"#{location=}")

    # Send a request to the specified location
    response = requests.get(url)

    # Parse the HTML content
    soup = BeautifulSoup(response.content, "html.parser")

    # Find all the 'a' tags and extract the 'href' attributes
    hrefs = [a["href"] for a in soup.find_all("a", href=True)]
    for href in hrefs:
        if "/i/" not in href:
            continue
        item=href.strip("/").split("/")[-1]
        #print(f'{{"item": "{item}", "location": "{location}"}},')
        print(f'"{item}": "{location}",')
        # print(href)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script description")
    parser.add_argument("url", help="URL argument")

    args = parser.parse_args()
    main(args.url)


### # locations=(
### /l/small-cave/
### /l/small-spring/
### /l/highland-hills/
### /l/cane-pole-ridge/
### /l/misty-forest/
### /l/black-rock-canyon/
### /l/forest/
### /l/mount-banon/
### /l/ember-lagoon/
### /l/whispering-creek/
### /l/jundland-desert/
### )
###
### for loc in $locations; do
###   python3 scrape_explore/main.py https://buddy.farm/$loc
### done
