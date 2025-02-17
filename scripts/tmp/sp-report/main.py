import os
import requests

# Constants for Confluence API for Personal Account
# CONFLUENCE_BASE_URL = "https://mrityunjoydey1999.atlassian.net/wiki/rest/api"
# CONFLUENCE_USERNAME = "mrityunjoydey1999@gmail.com"
# CONFLUENCE_API_TOKEN = "ATATT3xFfGF0E4eEhQX0hDfVibGkpz4FR2v8kW7u3dq1mVRCfpnfxUlmjAZ6CcW3roJPxQyYT0FI1fMcStmvb3PUQnnJLxZixBimyvKLro1qtVY6mXEzjXD4tKZ-IzZnnQWQgZg8uTXbS4auG9ll9PgNnN_4_l2pAB9HOKBvyiXOnvMp0Za7fzk=0C1CFD3C"
# BASE_PAGE_ID = "65987"  # The parent page where these pages will be nested
# SPACE_KEY = '~63de2eb4a5d0c826306b27fb'

# Constants for Confluence API for Slice Account
CONFLUENCE_BASE_URL = "https://slicepay.atlassian.net/wiki/rest/api"
CONFLUENCE_USERNAME = "mrityunjoy.dey@sliceit.com"
CONFLUENCE_API_TOKEN = "ATATT3xFfGF06oOEXR9lGcEeBL8WBkrdX1jRGzfbczu7oKq7yhb_HbbgEso9xViCOXFebovVonC6xnA_7DLloReifUS4rm_0uXyqmSqCSvk9PBCWPrrff6umwxY_6VFvCEUN_kg83W2jW5l9rngEbgp8cNyePIqSWIBleh3mklk_hOICGiJtIbs=5717ED51"
BASE_PAGE_ID = "3409905432"  # The parent page where these pages will be nested
SPACE_KEY = 'CBS'

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
