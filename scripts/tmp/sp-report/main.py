import os
import requests


# Load environment variables from .env file
import markdown2
from dotenv import load_dotenv

load_dotenv()

CONFLUENCE_BASE_URL = os.getenv("CONFLUENCE_BASE_URL")
CONFLUENCE_USERNAME = os.getenv("CONFLUENCE_USERNAME")
CONFLUENCE_API_TOKEN = os.getenv("CONFLUENCE_API_TOKEN")
BASE_PAGE_ID = os.getenv("BASE_PAGE_ID")
SPACE_KEY = os.getenv("SPACE_KEY")


def get_markdown_files(directory):
    """Retrieve all markdown (.md) files from a directory."""
    return [f for f in os.listdir(directory) if f.endswith('.md')]

def read_markdown_file(filepath):
    """Read the content of a markdown file."""
    with open(filepath, 'r', encoding='utf-8') as file:
        return file.read()

def convert_markdown_to_storage_format(markdown_content):
    """Convert markdown content to Confluence's storage format (HTML)."""
    # For simplicity, use a library like markdown2
    import markdown2
    return markdown2.markdown(markdown_content)

def get_page_id_if_exists(title, SPACE_KEY):
    """Check if a page with the given title exists in the Confluence space."""
    url = f"{CONFLUENCE_BASE_URL}/content"
    params = {"title": title, "spaceKey": SPACE_KEY}
    auth = (CONFLUENCE_USERNAME, CONFLUENCE_API_TOKEN)
    response = requests.get(url, params=params, auth=auth)
    if response.status_code == 200 and response.json().get('size') > 0:
        return response.json()['results'][0]['id']
    return None

def create_or_update_page(title, content, parent_id=None):
    """Create or update a Confluence page."""
    page_id = get_page_id_if_exists(title, SPACE_KEY)
    storage_format = convert_markdown_to_storage_format(content)

    if page_id:
        # Update the page
        url = f"{CONFLUENCE_BASE_URL}/content/{page_id}"
        payload = {
            "version": {"number": get_current_page_version(page_id) + 1},
            "title": title,
            "type": "page",
            "body": {
                "storage": {
                    "value": storage_format,
                    "representation": "storage",
                }
            }
        }
    else:
        # Create a new page
        url = f"{CONFLUENCE_BASE_URL}/content"
        payload = {
            "title": title,
            "type": "page",
            "space": {"key": SPACE_KEY},
            "ancestors": [{"id": parent_id}] if parent_id else [],
            "body": {
                "storage": {
                    "value": storage_format,
                    "representation": "storage",
                }
            }
        }

    auth = (CONFLUENCE_USERNAME, CONFLUENCE_API_TOKEN)
    response = requests.post(url, json=payload, auth=auth) if not page_id else requests.put(url, json=payload, auth=auth)

    if response.status_code in [200, 201]:
        print(f"Page '{title}' {'updated' if page_id else 'created'} successfully.")
    else:
        print(f"Failed to {'update' if page_id else 'create'} page '{title}': {response.status_code} {response.text}")

def get_current_page_version(page_id):
    """Get the current version of a Confluence page."""
    url = f"{CONFLUENCE_BASE_URL}/content/{page_id}"
    auth = (CONFLUENCE_USERNAME, CONFLUENCE_API_TOKEN)
    response = requests.get(url, auth=auth)
    if response.status_code == 200:
        return response.json()['version']['number']
    else:
        raise Exception(f"Unable to retrieve page version: {response.status_code} {response.text}")

def main():
    directory = '/Users/mrityunjoydey/Documents/util/scripts/tmp/sp-report/sp_docs'

    if not os.path.isdir(directory):
        print("Invalid directory.")
        return

    markdown_files = get_markdown_files(directory)

    for md_file in markdown_files:
        filepath = os.path.join(directory, md_file)
        content = read_markdown_file(filepath)
        title = os.path.splitext(md_file)[0]  # Use file name (without extension) as title

        create_or_update_page("SP analysis of " + title, content, parent_id=BASE_PAGE_ID)

if __name__ == "__main__":
    main()
