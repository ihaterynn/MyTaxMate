import os
import json
import requests
from bs4 import BeautifulSoup
from datetime import datetime, timezone
from urllib.parse import urljoin, urlparse, parse_qs
import hashlib
import time # For adding delays
import traceback # For detailed error tracing
from dotenv import load_dotenv # Only for local testing if you use a .env file
import mysql.connector # For MySQL connection

# --- Configuration (Best loaded from Environment Variables) ---
load_dotenv()
MYSQL_HOST = os.environ.get("MYSQL_HOST")
MYSQL_USER = os.environ.get("MYSQL_USER")
MYSQL_PASSWORD = os.environ.get("MYSQL_PASSWORD")
MYSQL_DATABASE = os.environ.get("MYSQL_DATABASE")
# Base URL for the listing page, page number will be appended
BASE_LISTING_URL = os.environ.get("BASE_LISTING_URL", "https://www.hasil.gov.my/kenyataan-media/?tajuk=&page=")
NEWS_TABLE_NAME = os.environ.get("NEWS_TABLE_NAME", "tax_news")
MAX_PAGES_TO_SCRAPE = int(os.environ.get("MAX_PAGES_TO_SCRAPE", 5)) # Limit number of pages to scrape
MAX_ARTICLES_TO_SCRAPE = int(os.environ.get("MAX_ARTICLES_TO_SCRAPE", 100)) # Limit total articles to scrape
REQUEST_DELAY_SECONDS = float(os.environ.get("REQUEST_DELAY_SECONDS", 1)) # Delay between requests

# --- Global MySQL Connection ---
mysql_conn = None
mysql_cursor = None

def initialize_mysql():
    global mysql_conn, mysql_cursor
    if MYSQL_HOST and MYSQL_USER and MYSQL_PASSWORD and MYSQL_DATABASE:
        try:
            mysql_conn = mysql.connector.connect(
                host=MYSQL_HOST,
                user=MYSQL_USER,
                password=MYSQL_PASSWORD,
                database=MYSQL_DATABASE
            )
            mysql_cursor = mysql_conn.cursor()
            print("MySQL connection initialized successfully.")
            
            # Create the table if it doesn't exist
            create_table_query = f"""
            CREATE TABLE IF NOT EXISTS {NEWS_TABLE_NAME} (
                id VARCHAR(255) PRIMARY KEY,
                title TEXT NOT NULL,
                url VARCHAR(512) NOT NULL UNIQUE,
                summary TEXT,
                pdf_url VARCHAR(512),
                published_date VARCHAR(255),
                fetched_at DATETIME NOT NULL
            )
            """
            mysql_cursor.execute(create_table_query)
            mysql_conn.commit()
            print(f"Table {NEWS_TABLE_NAME} verified/created.")
            
        except Exception as e:
            print(f"Error initializing MySQL connection: {e}")
            mysql_conn = None
            mysql_cursor = None
    else:
        print("MySQL connection details not found in environment variables.")

# --- Helper: Scrape a single article's detail page ---
def scrape_article_detail_page(detail_url):
    print(f"  Scraping detail page: {detail_url}")
    try:
        headers = {
            'User-Agent': 'MyTaxMateAppScraper/1.0 (+http://yourappdomain.com/scraper-info)'
        }
        time.sleep(REQUEST_DELAY_SECONDS) # Respectful delay
        page = requests.get(detail_url, headers=headers, timeout=20)
        page.raise_for_status()
        soup = BeautifulSoup(page.content, "lxml")

        article_details = {"summary": None, "pdf_url": None}

        # Based on your provided HTML snippet for a detail page:
        # <table><tbody><tr><td><strong>TITLE</strong><br><br>SUMMARY<br><br><a href="...">PDF</a></td></tr></tbody></table>
        content_cell = soup.find("td") # This is very generic; a more specific selector is ideal
                                    # e.g., soup.find("div", class_="article-content").find("td")

        if content_cell:
            # Summary: text parts excluding title and PDF link text
            summary_parts = []
            for elem in content_cell.contents:
                if elem.name == 'strong': continue
                if elem.name == 'a' and "muat turun" in elem.get_text(strip=True).lower(): continue
                if elem.name == 'br': 
                    summary_parts.append("\n") # Newline for <br>
                    continue
                if isinstance(elem, str):
                    summary_parts.append(elem.strip())
            
            full_summary = " ".join(summary_parts).strip()
            article_details["summary"] = "\n".join([line.strip() for line in full_summary.split('\n') if line.strip()]) # Clean multiple newlines

            # PDF download link
            pdf_link_tag = content_cell.find("a", href=True)
            if pdf_link_tag and "muat turun" in pdf_link_tag.get_text(strip=True).lower():
                pdf_relative_url = pdf_link_tag["href"]
                article_details["pdf_url"] = urljoin(detail_url, pdf_relative_url) # Use detail_url as base for robustness
        else:
            print(f"    Could not find main content cell on detail page: {detail_url}")
        return article_details

    except requests.exceptions.RequestException as e:
        print(f"    Error fetching detail page {detail_url}: {e}")
    except Exception as e:
        print(f"    An error occurred scraping detail page {detail_url}: {e}")
    return {"summary": None, "pdf_url": None} # Return default on error

# --- Main Web Scraping Logic for Listing Page(s) ---
def scrape_tax_news(base_listing_url):
    print(f"Starting scrape for base listing: {base_listing_url} (up to {MAX_PAGES_TO_SCRAPE} pages, max {MAX_ARTICLES_TO_SCRAPE} articles)")
    all_scraped_articles = []
    
    for page_num in range(1, MAX_PAGES_TO_SCRAPE + 1):
        current_listing_url = f"{base_listing_url}{page_num}"
        print(f"Scraping listing page: {current_listing_url}")
        articles_on_this_page = 0

        try:
            headers = {
                'User-Agent': 'MyTaxMateAppScraper/1.0 (+http://yourappdomain.com/scraper-info)'
            }
            time.sleep(REQUEST_DELAY_SECONDS) # Respectful delay
            page = requests.get(current_listing_url, headers=headers, timeout=15)
            page.raise_for_status()
            soup = BeautifulSoup(page.content, "lxml")

            # CRITICAL: Refine this selector based on LHDN's actual HTML for the listing table
            # Find the table rows. This is a guess - verify with browser dev tools.
            # Example: news_table = soup.find("table", class_="kenyataan-media-table")
            # table_rows = news_table.find_all("tr") if news_table else []
            table_rows = soup.find_all("tr") 

            if not table_rows and page_num > 1: # If not first page and no rows, likely end of pages
                print("  No table rows found, assuming end of news pages.")
                break
            if not table_rows:
                print("  No table rows found on this page. Check selectors or page structure.")
                continue # Try next page or break if it's an error

            for row_index, row in enumerate(table_rows):
                # Check if we've already reached our max total articles
                if len(all_scraped_articles) >= MAX_ARTICLES_TO_SCRAPE:
                    print(f"Reached max article limit of {MAX_ARTICLES_TO_SCRAPE}")
                    break
                    
                cells = row.find_all("td")
                if len(cells) == 2: # Expecting Date and Title cells
                    date_str = cells[0].get_text(strip=True)
                    title_cell = cells[1]
                    link_tag = title_cell.find("a")

                    if link_tag and link_tag.get("href"):
                        title = link_tag.get_text(strip=True)
                        relative_detail_url = link_tag.get("href")
                        absolute_detail_url = urljoin("https://www.hasil.gov.my/", relative_detail_url)

                        # Placeholder for robust date parsing (CRITICAL)
                        parsed_published_date = None
                        try:
                            # Mapping for Malay month names to English month abbreviations
                            # This handles the common short forms found on the website.
                            malay_to_eng_month = {
                                'jan': 'Jan', 'feb': 'Feb', 'mac': 'Mar', 'apr': 'Apr',
                                'mei': 'May', 'jun': 'Jun', 'jul': 'Jul', 'ogo': 'Aug', # 'Ogo' for 'Ogos'
                                'sep': 'Sep', 'okt': 'Oct', 'nov': 'Nov', 'dis': 'Dec'
                            }
                            parts = date_str.split() # e.g., ['14', 'Mei', '2025']
                            if len(parts) == 3:
                                day, malay_month, year_str = parts
                                eng_month_abbr = malay_to_eng_month.get(malay_month.lower()[:3]) # Use lower and first 3 chars for robustness

                                if eng_month_abbr and year_str.isdigit() and day.isdigit():
                                    # Reconstruct date string with English month for parsing
                                    formatted_date_str = f"{day} {eng_month_abbr} {year_str}"
                                    dt_object = datetime.strptime(formatted_date_str, "%d %b %Y")
                                    
                                    # --- YEAR FILTER ---
                                    if dt_object.year != 2025:
                                        print(f"    Skipping article from year {dt_object.year}: {title}")
                                        continue # Skip to the next article

                                    parsed_published_date = dt_object.isoformat()
                                else:
                                    raise ValueError("Could not map Malay month or invalid date parts")
                            else:
                                raise ValueError("Date string not in expected 'DD Mmm YYYY' format")
                        except ValueError as ve:
                            print(f"    Could not parse date: {date_str} ({ve}). Storing raw.")
                            # Store raw date or None if parsing fails completely
                            parsed_published_date = date_str # Or None, depending on DB schema
                            # If we store raw, we can't filter by year accurately here,
                            # but we'll keep the article for now.
                            # Alternatively, you could choose to skip if date parsing fails:
                            # print(f"    Skipping article due to date parsing failure: {title}")
                            # continue

                        # Get UniqueID for article ID from detail URL
                        parsed_url_query = parse_qs(urlparse(absolute_detail_url).query)
                        unique_id_param = parsed_url_query.get('UniqueId', [None])[0]
                        article_id = unique_id_param if unique_id_param else hashlib.md5(absolute_detail_url.encode()).hexdigest()
                        
                        # Check if this article URL has already been processed (e.g., if it was on a previous page due to updates)
                        # This check is against 'all_scraped_articles' which only covers the current run.
                        # For true duplicate prevention across runs, check the DB in save_articles_to_mysql.
                        if any(a["url"] == absolute_detail_url for a in all_scraped_articles):
                            print(f"  Skipping already processed URL (from this run): {absolute_detail_url}")
                            continue

                        # Scrape the detail page for summary and PDF
                        detail_page_data = scrape_article_detail_page(absolute_detail_url)

                        all_scraped_articles.append({
                            "id": article_id,
                            "title": title,
                            "url": absolute_detail_url,
                            "summary": detail_page_data.get("summary"),
                            "pdf_url": detail_page_data.get("pdf_url"),
                            "published_date": parsed_published_date, # ISO format string or raw string
                            "fetched_at": datetime.now(timezone.utc).isoformat()
                        })
                        articles_on_this_page += 1
                    # else: print("  Skipping row in listing, missing link or href.")
                # elif row_index > 0: # Avoid logging for potential header rows if len(cells) != 2
                    # print(f"  Skipping row in listing, expected 2 cells, found {len(cells)}. ")
           
            if articles_on_this_page == 0 and page_num > 0: # If not first page and no articles scraped
                 print(f"  No new articles found on page {page_num}. Assuming end of content or issue with selectors for this page.")
                 # break # Stop if a non-first page yields no new articles
        except requests.exceptions.RequestException as e:
            print(f"Error fetching listing page {current_listing_url}: {e}")
            # break # Optional: stop if a listing page fails
        except Exception as e:
            print(f"An error occurred scraping listing page {current_listing_url}: {e}")
            # break
       
        if articles_on_this_page == 0 and page_num > 1: # More robust check to stop pagination
            print(f"Stopping pagination because no articles were extracted from page {page_num}.")
            break

    print(f"Total articles scraped from all pages: {len(all_scraped_articles)}")
    return all_scraped_articles

# --- MySQL Data Storage ---
def save_articles_to_mysql(articles):
    # First, save to local JSON file as backup
    backup_file = "scraped_articles_backup.json"
    with open(backup_file, "w", encoding="utf-8") as f:
        json.dump(articles, f, ensure_ascii=False, indent=2)
    print(f"Saved {len(articles)} articles to local backup file: {backup_file}")
    
    if not mysql_conn or not mysql_cursor:
        print("MySQL connection not initialized. Cannot save articles to MySQL.")
        return 0

    saved_count = 0
    newly_saved_urls = set()

    for article_data in articles:
        try:
            # Check for existing article by URL to prevent duplicates
            url = article_data['url']
            check_query = f"SELECT id FROM {NEWS_TABLE_NAME} WHERE url = %s"
            
            try:
                mysql_cursor.execute(check_query, (url,))
                existing_article = mysql_cursor.fetchone()
                
                if existing_article:
                    print(f"Article already exists in DB, skipping: {url}")
                    continue
            except Exception as check_e:
                print(f"Error checking for existing article: {check_e}")
                traceback.print_exc()
            
            # Prepare insert data
            insert_data = {
                "id": article_data.get("id"),
                "title": article_data.get("title"),
                "url": article_data.get("url"),
                "summary": article_data.get("summary"),
                "pdf_url": article_data.get("pdf_url"),
                "published_date": article_data.get("published_date"),
                "fetched_at": datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
            }
            
            # Handle potential NULL values
            if not insert_data.get('id'):
                insert_data['id'] = hashlib.md5(insert_data['url'].encode()).hexdigest()
            
            # Create the insert query
            insert_query = f"""
            INSERT INTO {NEWS_TABLE_NAME} 
            (id, title, url, summary, pdf_url, published_date, fetched_at) 
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            
            values = (
                insert_data['id'],
                insert_data['title'],
                insert_data['url'],
                insert_data['summary'],
                insert_data['pdf_url'],
                insert_data['published_date'],
                insert_data['fetched_at']
            )
            
            try:
                mysql_cursor.execute(insert_query, values)
                mysql_conn.commit()
                print(f"Successfully saved article: {insert_data['title'][:30]}...")
                saved_count += 1
                newly_saved_urls.add(url)
            except Exception as insert_e:
                print(f"Error inserting article: {insert_e}")
                mysql_conn.rollback()
                traceback.print_exc()
                
        except Exception as e:
            print(f"Exception while saving article '{article_data.get('title', 'Unknown Title')}': {e}")
            traceback.print_exc()
    
    print(f"Finished MySQL save. Total new articles saved in this run: {saved_count}")
    print(f"Reminder: All {len(articles)} articles were saved to local backup file: {backup_file}")
    return saved_count

# --- Function Compute Handler ---
def handler(event, context):
    """
    This is the entry point for Alibaba Cloud Function Compute.
    'event' can be from a trigger (e.g., time-based, API Gateway).
    'context' provides runtime information.
    """
    print("Function execution started.")
    initialize_mysql() # Ensure connection is ready

    if not mysql_conn or not mysql_cursor:
        return {"statusCode": 500, "body": json.dumps({"error": "MySQL connection failed to initialize."})}
    if not BASE_LISTING_URL:
        return {"statusCode": 500, "body": json.dumps({"error": "BASE_LISTING_URL not configured."})}

    scraped_articles = scrape_tax_news(BASE_LISTING_URL)

    if scraped_articles:
        num_saved = save_articles_to_mysql(scraped_articles)
        # Close MySQL connection
        if mysql_cursor:
            mysql_cursor.close()
        if mysql_conn:
            mysql_conn.close()
        return {
            "statusCode": 200,
            "body": json.dumps({"message": f"Scraping complete. Fetched {len(scraped_articles)} articles. Saved {num_saved} new articles."})
        }
    else:
        # Close MySQL connection
        if mysql_cursor:
            mysql_cursor.close()
        if mysql_conn:
            mysql_conn.close()
        return {
            "statusCode": 200, 
            "body": json.dumps({"message": "No articles were scraped or an error occurred during scraping."})
        }

# --- For Local Testing (Optional) ---
if __name__ == "__main__":
    print("--- Running Scraper Locally ---")
    # For local testing, create a .env file with MySQL connection details
    # MYSQL_HOST="your_mysql_host"
    # MYSQL_USER="your_mysql_user"
    # MYSQL_PASSWORD="your_mysql_password"
    # MYSQL_DATABASE="your_mysql_database"
    # BASE_LISTING_URL="https://www.hasil.gov.my/kenyataan-media/?tajuk=&page="
    # NEWS_TABLE_NAME="tax_news"
    # MAX_PAGES_TO_SCRAPE="2" # For faster local testing
    # MAX_ARTICLES_TO_SCRAPE="5" # For faster local testing
    # REQUEST_DELAY_SECONDS="1"
    load_dotenv() # Load .env for local run

    # Re-initialize with loaded env vars if running __main__ directly
    MYSQL_HOST = os.environ.get("MYSQL_HOST")
    MYSQL_USER = os.environ.get("MYSQL_USER")
    MYSQL_PASSWORD = os.environ.get("MYSQL_PASSWORD")
    MYSQL_DATABASE = os.environ.get("MYSQL_DATABASE")
    BASE_LISTING_URL = os.environ.get("BASE_LISTING_URL", "https://www.hasil.gov.my/kenyataan-media/?tajuk=&page=")
    NEWS_TABLE_NAME = os.environ.get("NEWS_TABLE_NAME", "tax_news")
    MAX_PAGES_TO_SCRAPE = int(os.environ.get("MAX_PAGES_TO_SCRAPE", 1)) # Default to just 1 page for local testing 
    MAX_ARTICLES_TO_SCRAPE = int(os.environ.get("MAX_ARTICLES_TO_SCRAPE", 5)) # Default to just 5 articles for local testing
    REQUEST_DELAY_SECONDS = float(os.environ.get("REQUEST_DELAY_SECONDS", 1))

    result = handler(None, None)
    print("--- Local Run Result ---")
    print(result)
