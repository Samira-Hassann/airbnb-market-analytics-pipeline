# 🏠 Airbnb European Market Analysis: End-to-End Data Warehouse & Power BI Dashboard

An end-to-end data engineering and analytics project: **web scraping Airbnb listings → SQL Server Data Warehouse (Medallion architecture) → interactive Power BI dashboard**.

The project covers **500 listings across 10 European cities** (50 listings per city) and answers questions about pricing, ratings, superhosts, property types, and amenities.

---

## 📌 Project Overview

| Item | Details |
|---|---|
| **Data source** | Airbnb listing pages (scraped) |
| **Scope** | 10 cities × 50 listings = 500 listings |
| **Cities** | Amsterdam, Athens, Barcelona, Berlin, Budapest, Lisbon, London, Paris, Rome, Vienna |
| **Scraping** | Python, Selenium (headless Chrome), Google Colab |
| **Warehouse** | SQL Server (T-SQL), Bronze → Staging → Silver → Gold |
| **Visualization** | Power BI (4-page dashboard) |

---

## 🏗️ Architecture

```
Airbnb Website
      │   (Selenium scraper, one CSV per city)
      ▼
┌─────────────┐   ┌──────────────┐   ┌─────────────┐   ┌────────────────────────┐
│   BRONZE    │ → │   STAGING    │ → │   SILVER    │ → │         GOLD           │
│ raw city    │   │ UNION ALL of │   │ cleaned &   │   │ fact_listings          │
│ tables (10) │   │ all cities + │   │ typed data, │   │ dim_amenity            │
│             │   │ source_table │   │ amenities   │   │ bridge_listing_amenity │
│             │   │              │   │ split out   │   │                        │
└─────────────┘   └──────────────┘   └─────────────┘   └────────────────────────┘
                                                                  │
                                                                  ▼
                                                        Power BI Dashboard
```

### Layers

- **Bronze**: raw, untouched data loaded from the scraped CSV files, one table per city (`BRONZE.amsterdam_listings`, `BRONZE.athens_listings`, ...).
- **Staging**: all 10 city tables combined with `UNION ALL` into `STAGING.airbnb_listings`, with a `source_table` column to keep lineage.
- **Validation (before Silver)**: profiling and data-quality checks: row counts per city, NULL counts per column, duplicate listing URLs, numeric "describe" statistics (mean, std, quartiles), text column profiling, category distributions (`room_type`, `property_type`, `is_superhost`), max lengths and numeric precision checks to choose proper data types.
- **Silver**: cleaned and correctly typed data in `SILVER.airbnb_listings` (with a `listing_id` key and a calculated `price_per_night`) plus `SILVER.LISTING_AMENITY`, where the amenities list is split into one row per listing/amenity.
- **Gold**: analytics-ready star schema:
  - `GOLD.fact_listings`: one row per listing (price, ratings, location, property attributes)
  - `GOLD.dim_amenity`: unique amenities
  - `GOLD.bridge_listing_amenity`: many-to-many link between listings and amenities
  - Primary/foreign keys and indexes on `city`, `price_per_night`, and `amenity_id`
  - Built-in reconciliation checks (row counts, orphan keys, Silver vs. Gold amenity pairs)

---

## 🕷️ Web Scraping

The scraper (`Airbnb_scrapping_notebook.ipynb`) runs in Google Colab using Selenium with headless Chrome. For each listing URL it extracts:

- **Basics**: title, city, property type, room type, guests, bedrooms, beds, baths
- **Location**: latitude and longitude (from the page's JSON-LD)
- **Reviews**: overall rating, review count, and six sub-ratings (cleanliness, accuracy, check-in, communication, location, value)
- **Host**: superhost flag
- **Pricing**: total price and number of nights for a fixed check-in/check-out window
- **Amenities**: full list of available amenities (parsed from embedded page JSON, with a regex fallback)

Techniques used: JSON-LD parsing, embedded JSON search, regex fallbacks, explicit waits, scrolling to trigger lazy-loaded content, and pop-up handling.

> ⚠️ **Disclaimer**: This project is for educational and portfolio purposes only. Please respect Airbnb's Terms of Service and robots.txt when scraping.

---

## 📊 Power BI Dashboard

The dashboard (`Airbnb Dashboard.pbix`) has four pages, each with City and Property Type (or Amenity) slicers.

### 1. Overview
![Overview](dashboard_screans/page%201.png)

### 2. Price Analysis
![Price Analysis](dashboard_screans/page%202.png)

### 3. Ratings & Quality
![Ratings & Quality](dashboard_screans/page%203.png)

### 4. Amenities
![Amenities](dashboard_screans/page%204.png)

---

## 🔍 Key Insights

- 💰 **Average price per night is $292.54** and the **median is $259.90**, with prices ranging from about $66 to over $1,130.
- 🏙️ **London ($429.10)** and **Amsterdam ($386.60)** have the highest median prices, while **Budapest ($146.00)** and **Athens ($156.20)** are the most affordable.
- ⭐ The **average rating is 4.89**, with **Athens (4.95)** leading and **Barcelona (4.81)** lowest among the cities.
- 🌟 **25.4%** of listings are hosted by superhosts, and their median price is slightly higher than regular hosts.
- 🛏️ Price grows strongly with size: the median price of **5-bedroom** listings (~$650) is more than **2.5×** that of 2-bedroom listings (~$238).
- 🏢 **Entire rental units** dominate the sample (369 of 500), while **townhouses** and **entire homes** have the highest median prices.
- 🛋️ Listings have **42 amenities on average**. Wifi appears in every listing, and amenities like **exercise equipment, sun loungers, sound systems, and BBQ grills** are linked with prices 30%+ above the overall median.

---

## 🗂️ Repository Structure

```
DWH/
├── Bronze.sql                  # Create database and BRONZE schema
├── STAGING.sql                 # Combine all city tables into STAGING.airbnb_listings
├── validationBeforSilver.sql   # Data profiling & quality checks
├── Silver.sql                  # Cleaning, typing, amenity split
├── Gold.sql                    # Star schema (fact, dimension, bridge) + validation
dashboard_screans/
├── page_1.png
├── page_2.png
├── page_3.png
└── page_4.png
samples_data/
├── airbnb_rome_listings.csv
└── airbnb_vienna_listings.csv
Airbnb Dashboard.pbix           # Power BI report
Airbnb_scrapping_notebook.ipynb # Selenium scraper (Google Colab)
```

---

## ▶️ How to Run

1. **Scrape the data**: open `Airbnb_scrapping_notebook.ipynb` in Google Colab, set your listing URLs and check-in/check-out dates, and run it to generate one CSV per city. (Sample files are in `samples_data/`.)
2. **Create the warehouse**: in SQL Server, run `Bronze.sql`, then import each city CSV into its `BRONZE.<city>_listings` table.
3. **Build the layers** in this order:
   1. `STAGING.sql`
   2. `validationBeforSilver.sql` (review the results)
   3. `Silver.sql`
   4. `Gold.sql`
4. **Open the dashboard**: open `Airbnb Dashboard.pbix` in Power BI Desktop and point the data source to your `AirbnbDW` database (GOLD schema).

---

## 🛠️ Tech Stack

`Python` · `Selenium` · `Google Colab` · `SQL Server / T-SQL` · `Medallion Architecture` · `Star Schema` · `Power BI` · `DAX`

---

## 🚀 Future Improvements

- Scrape more listings per city and multiple date ranges to capture seasonality
- Automate the pipeline with SQL Server Agent or Azure Data Factory
- Add a city/date dimension and a host dimension
- Add price prediction using amenities, ratings, and property features

---

## 👤 Author

**[Your Name]**
🔗 [Samira Hassan](https://www.linkedin.com/in/samira-hassan-00699a219) · 💻 [GitHub](https://github.com/Samira-Hassann)

⭐ If you found this project useful, consider giving the repo a star!
