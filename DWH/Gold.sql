
USE AirbnbDW;
GO

IF SCHEMA_ID('GOLD') IS NULL
BEGIN
    EXEC('CREATE SCHEMA GOLD');
END;
GO


DROP TABLE IF EXISTS GOLD.bridge_listing_amenity;
DROP TABLE IF EXISTS GOLD.fact_listings;
DROP TABLE IF EXISTS GOLD.dim_amenity;
GO



SELECT
    listing_id,
    city,
    listing_url,
    listing_title,
    guests,
    bedrooms,
    beds,
    baths,
    rating,
    reviews,
    cleanliness_rating,
    accuracy_rating,
    check_in_rating,
    communication_rating,
    location_rating,
    value_rating,
    lat,
    lng,
    room_type,
    is_superhost,
    property_type,
    total_price,
    nights,
    price_per_night,
    source_table
INTO GOLD.fact_listings
FROM SILVER.airbnb_listings;
GO

ALTER TABLE GOLD.fact_listings
ADD CONSTRAINT PK_GOLD_fact_listings
PRIMARY KEY CLUSTERED (listing_id);
GO



CREATE TABLE GOLD.dim_amenity
(
    amenity_id INT IDENTITY(1,1) NOT NULL,
    amenity_name NVARCHAR(200) NOT NULL,

    CONSTRAINT PK_GOLD_dim_amenity
        PRIMARY KEY CLUSTERED (amenity_id),

    CONSTRAINT UQ_GOLD_dim_amenity_name
        UNIQUE (amenity_name)
);
GO

INSERT INTO GOLD.dim_amenity (amenity_name)
SELECT DISTINCT amenity_name
FROM SILVER.LISTING_AMENITY
WHERE amenity_name IS NOT NULL
  AND LTRIM(RTRIM(amenity_name)) <> N'';
GO



CREATE TABLE GOLD.bridge_listing_amenity
(
    listing_id INT NOT NULL,
    amenity_id INT NOT NULL,

    CONSTRAINT PK_GOLD_bridge_listing_amenity
        PRIMARY KEY CLUSTERED (listing_id, amenity_id),

    CONSTRAINT FK_GOLD_bridge_listing
        FOREIGN KEY (listing_id)
        REFERENCES GOLD.fact_listings(listing_id),

    CONSTRAINT FK_GOLD_bridge_amenity
        FOREIGN KEY (amenity_id)
        REFERENCES GOLD.dim_amenity(amenity_id)
);
GO

INSERT INTO GOLD.bridge_listing_amenity
(
    listing_id,
    amenity_id
)
SELECT DISTINCT
    la.listing_id,
    da.amenity_id
FROM SILVER.LISTING_AMENITY AS la
INNER JOIN GOLD.dim_amenity AS da
    ON la.amenity_name = da.amenity_name
INNER JOIN GOLD.fact_listings AS fl
    ON la.listing_id = fl.listing_id;
GO



CREATE NONCLUSTERED INDEX IX_GOLD_fact_listings_city
ON GOLD.fact_listings(city);
GO

CREATE NONCLUSTERED INDEX IX_GOLD_fact_listings_price
ON GOLD.fact_listings(price_per_night);
GO

CREATE NONCLUSTERED INDEX IX_GOLD_bridge_amenity_id
ON GOLD.bridge_listing_amenity(amenity_id);
GO


SELECT
    'SILVER.airbnb_listings' AS table_name,
    COUNT_BIG(*) AS total_rows
FROM SILVER.airbnb_listings

UNION ALL

SELECT
    'GOLD.fact_listings',
    COUNT_BIG(*)
FROM GOLD.fact_listings

UNION ALL

SELECT
    'SILVER.LISTING_AMENITY',
    COUNT_BIG(*)
FROM SILVER.LISTING_AMENITY

UNION ALL

SELECT
    'GOLD.dim_amenity',
    COUNT_BIG(*)
FROM GOLD.dim_amenity

UNION ALL

SELECT
    'GOLD.bridge_listing_amenity',
    COUNT_BIG(*)
FROM GOLD.bridge_listing_amenity;
GO



SELECT
    COUNT_BIG(*) AS total_listings,
    COUNT_BIG(DISTINCT listing_id) AS unique_listing_ids
FROM GOLD.fact_listings;

SELECT COUNT_BIG(*) AS invalid_listing_references
FROM GOLD.bridge_listing_amenity AS b
LEFT JOIN GOLD.fact_listings AS f
    ON b.listing_id = f.listing_id
WHERE f.listing_id IS NULL;

SELECT COUNT_BIG(*) AS invalid_amenity_references
FROM GOLD.bridge_listing_amenity AS b
LEFT JOIN GOLD.dim_amenity AS a
    ON b.amenity_id = a.amenity_id
WHERE a.amenity_id IS NULL;
GO



SELECT TOP (10) *
FROM GOLD.fact_listings
ORDER BY listing_id;

SELECT TOP (20) *
FROM GOLD.dim_amenity
ORDER BY amenity_id;

SELECT TOP (20) *
FROM GOLD.bridge_listing_amenity
ORDER BY listing_id, amenity_id;
GO


SELECT
    COUNT_BIG(*) AS silver_rows,
    COUNT_BIG(DISTINCT
        CONCAT(
            listing_id,
            '|',
            amenity_name
        )
    ) AS distinct_listing_amenity_pairs
FROM SILVER.LISTING_AMENITY
WHERE amenity_name IS NOT NULL;


SELECT
    COUNT_BIG(*) AS silver_rows_without_gold_match
FROM SILVER.LISTING_AMENITY AS la
LEFT JOIN GOLD.dim_amenity AS da
    ON la.amenity_name = da.amenity_name
LEFT JOIN GOLD.bridge_listing_amenity AS b
    ON b.listing_id = la.listing_id
   AND b.amenity_id = da.amenity_id
WHERE da.amenity_id IS NULL
   OR b.listing_id IS NULL;


   WITH SilverPairs AS
(
    SELECT DISTINCT
        listing_id,
        amenity_name
    FROM SILVER.LISTING_AMENITY
    WHERE amenity_name IS NOT NULL
      AND LTRIM(RTRIM(amenity_name)) <> N''
),
GoldPairs AS
(
    SELECT
        b.listing_id,
        d.amenity_name
    FROM GOLD.bridge_listing_amenity AS b
    INNER JOIN GOLD.dim_amenity AS d
        ON b.amenity_id = d.amenity_id
)
SELECT
    (SELECT COUNT_BIG(*) FROM SilverPairs)
        AS silver_distinct_pairs,

    (SELECT COUNT_BIG(*) FROM GoldPairs)
        AS gold_pairs,

    (
        SELECT COUNT_BIG(*)
        FROM SilverPairs AS s
        LEFT JOIN GoldPairs AS g
            ON s.listing_id = g.listing_id
           AND s.amenity_name = g.amenity_name
        WHERE g.listing_id IS NULL
    ) AS missing_pairs_in_gold;