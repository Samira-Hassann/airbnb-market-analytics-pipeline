
USE AirbnbDW;
GO

IF SCHEMA_ID('SILVER') IS NULL
BEGIN
    EXEC('CREATE SCHEMA SILVER');
END;
GO
/* ==========================================
   airbnb_listings TABLE OF SILVER LAYER 
   ========================================== */
SELECT
    IDENTITY(INT, 1, 1) AS listing_id,

    CAST(NULLIF(LTRIM(RTRIM(city)), '')
        AS NVARCHAR(20)) AS city,

    CAST(NULLIF(LTRIM(RTRIM(listing_url)), '')
        AS NVARCHAR(300)) AS listing_url,

    CAST(NULLIF(LTRIM(RTRIM(listing_title)), '')
        AS NVARCHAR(150)) AS listing_title,

    TRY_CAST(guests AS TINYINT) AS guests,
    TRY_CAST(bedrooms AS TINYINT) AS bedrooms,
    TRY_CAST(beds AS TINYINT) AS beds,
    TRY_CAST(baths AS DECIMAL(3,1)) AS baths,

    TRY_CAST(rating AS DECIMAL(3,2)) AS rating,
    TRY_CAST(reviews AS INT) AS reviews,

    TRY_CAST(cleanliness_rating AS DECIMAL(3,2))
        AS cleanliness_rating,

    TRY_CAST(accuracy_rating AS DECIMAL(3,2))
        AS accuracy_rating,

    TRY_CAST(check_in_rating AS DECIMAL(3,2))
        AS check_in_rating,

    TRY_CAST(communication_rating AS DECIMAL(3,2))
        AS communication_rating,

    TRY_CAST(location_rating AS DECIMAL(3,2))
        AS location_rating,

    TRY_CAST(value_rating AS DECIMAL(3,2))
        AS value_rating,

    TRY_CAST(lat AS DECIMAL(9,6)) AS lat,
    TRY_CAST(lng AS DECIMAL(9,6)) AS lng,

    CAST(NULLIF(LTRIM(RTRIM(room_type)), '')
        AS NVARCHAR(30)) AS room_type,

    is_superhost,

    CAST(NULLIF(LTRIM(RTRIM(property_type)), '')
        AS NVARCHAR(50)) AS property_type,

    TRY_CAST(total_price AS DECIMAL(12,2)) AS total_price,
    TRY_CAST(nights AS SMALLINT) AS nights,

    CAST(
        CASE
            WHEN TRY_CAST(nights AS SMALLINT) > 0
                    AND TRY_CAST(total_price AS DECIMAL(12,2)) IS NOT NULL
            THEN
                TRY_CAST(total_price AS DECIMAL(12,2))
                / NULLIF(TRY_CAST(nights AS SMALLINT), 0)
            ELSE NULL
        END
        AS DECIMAL(12,2)
    ) AS price_per_night,

    CAST(source_table AS NVARCHAR(30)) AS source_table

INTO SILVER.airbnb_listings
FROM STAGING.airbnb_listings;

ALTER TABLE SILVER.airbnb_listings
ADD CONSTRAINT PK_silver_airbnb_listings
    PRIMARY KEY CLUSTERED (listing_id);


/* ==========================================
   VALIDATION OF SILVER LAYER airbnb_listings
   ========================================== */
SELECT COUNT(*) AS silver_row_count
FROM SILVER.airbnb_listings;

SELECT TOP (10) *
FROM SILVER.airbnb_listings
ORDER BY listing_id;



DECLARE @SQL NVARCHAR(MAX) = N'';

SELECT @SQL +=
    CASE WHEN @SQL = N'' THEN N'' ELSE N' UNION ALL ' END +
    N'SELECT
        N''' + TABLE_NAME + N''' AS table_name,
        N''' + COLUMN_NAME + N''' AS column_name,
        COUNT_BIG(*) AS total_rows,
        COUNT_BIG(*) - COUNT_BIG(' + QUOTENAME(COLUMN_NAME) + N') AS null_count
      FROM SILVER.' + QUOTENAME(TABLE_NAME)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SILVER';

EXEC sp_executesql @SQL;

SELECT
    (SELECT COUNT_BIG(*)
     FROM STAGING.airbnb_listings) AS staging_rows,

    (SELECT COUNT_BIG(*)
     FROM SILVER.airbnb_listings) AS silver_rows;



SELECT
    listing_url,
    COUNT_BIG(*) AS occurrences
FROM SILVER.airbnb_listings
WHERE listing_url IS NOT NULL
GROUP BY listing_url
HAVING COUNT_BIG(*) > 1
ORDER BY occurrences DESC;




SELECT
    SUM(CASE WHEN guests < 1 THEN 1 ELSE 0 END)
        AS invalid_guests,

    SUM(CASE WHEN bedrooms < 1 THEN 1 ELSE 0 END)
        AS invalid_bedrooms,

    SUM(CASE WHEN beds < 1 THEN 1 ELSE 0 END)
        AS invalid_beds,

    SUM(CASE WHEN baths < 1 THEN 1 ELSE 0 END)
        AS invalid_baths,

    SUM(CASE WHEN rating < 0 OR rating > 5
             THEN 1 ELSE 0 END)
        AS invalid_rating,

    SUM(CASE WHEN reviews < 0 THEN 1 ELSE 0 END)
        AS invalid_reviews,

    SUM(CASE WHEN cleanliness_rating < 0
                   OR cleanliness_rating > 5
             THEN 1 ELSE 0 END)
        AS invalid_cleanliness_rating,

    SUM(CASE WHEN accuracy_rating < 0
                   OR accuracy_rating > 5
             THEN 1 ELSE 0 END)
        AS invalid_accuracy_rating,

    SUM(CASE WHEN check_in_rating < 0
                   OR check_in_rating > 5
             THEN 1 ELSE 0 END)
        AS invalid_check_in_rating,

    SUM(CASE WHEN communication_rating < 0
                   OR communication_rating > 5
             THEN 1 ELSE 0 END)
        AS invalid_communication_rating,

    SUM(CASE WHEN location_rating < 0
                   OR location_rating > 5
             THEN 1 ELSE 0 END)
        AS invalid_location_rating,

    SUM(CASE WHEN value_rating < 0
                   OR value_rating > 5
             THEN 1 ELSE 0 END)
        AS invalid_value_rating,

    SUM(CASE WHEN total_price <= 0
             THEN 1 ELSE 0 END)
        AS invalid_total_price,

    SUM(CASE WHEN nights <= 0
             THEN 1 ELSE 0 END)
        AS invalid_nights,

    SUM(CASE WHEN lat < -90 OR lat > 90
             THEN 1 ELSE 0 END)
        AS invalid_latitude,

    SUM(CASE WHEN lng < -180 OR lng > 180
             THEN 1 ELSE 0 END)
        AS invalid_longitude

FROM SILVER.airbnb_listings;



SELECT
    COUNT_BIG(*) AS invalid_price_per_night
FROM SILVER.airbnb_listings
WHERE nights > 0
  AND total_price IS NOT NULL
  AND (
      price_per_night IS NULL
      OR ABS(
          price_per_night -
          CAST(total_price / NULLIF(nights, 0) AS DECIMAL(12,2))
      ) > 0.01
  );




SELECT
    city,
    COUNT_BIG(*) AS listing_count,
    MIN(total_price) AS min_total_price,
    MAX(total_price) AS max_total_price,
    AVG(total_price) AS avg_total_price
FROM SILVER.airbnb_listings
GROUP BY city
ORDER BY city;


SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SILVER'
  AND TABLE_NAME = 'airbnb_listings'
ORDER BY ORDINAL_POSITION;



SELECT
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT listing_id) AS unique_listing_ids,
    MIN(listing_id) AS min_listing_id,
    MAX(listing_id) AS max_listing_id
FROM SILVER.airbnb_listings;




SELECT TOP (20) *
FROM SILVER.airbnb_listings
ORDER BY listing_id;




/* ==========================================
   AMENITY TABLE OF SILVER LAYER 
   ========================================== */
DROP TABLE IF EXISTS SILVER.LISTING_AMENITY;
GO

CREATE TABLE SILVER.LISTING_AMENITY
(
    listing_amenity_id INT IDENTITY(1,1) NOT NULL,
    listing_id         INT NOT NULL,
    amenity_raw        NVARCHAR(450) NOT NULL,

    CONSTRAINT PK_LISTING_AMENITY
        PRIMARY KEY CLUSTERED (listing_amenity_id),

    CONSTRAINT FK_LISTING_AMENITY_LISTINGS
        FOREIGN KEY (listing_id)
        REFERENCES SILVER.airbnb_listings(listing_id)
);
GO

/* =====================================================================
   2) Parsing and cleaning 
   ===================================================================== */
;WITH ParsedAmenities AS
(
    SELECT DISTINCT
        sl.listing_id,
        CONVERT(NVARCHAR(450), e.amenity) AS amenity_raw
    FROM STAGING.airbnb_listings AS st

    INNER JOIN SILVER.airbnb_listings AS sl
        ON st.listing_url = sl.listing_url
       AND st.city = sl.city

    CROSS APPLY
    (
        SELECT REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                   CONVERT(NVARCHAR(MAX), st.amenities),
                   N'\u202f', N' '),                    
                   N'\xa0',   N' '),                    
                   NCHAR(160),  N' '),                  
                   NCHAR(8239), N' '),                
                   NCHAR(39) + N'], ', NCHAR(31)),      
                   NCHAR(39) + N', ',  NCHAR(31))       
               AS t1
    ) AS src1

    CROSS APPLY
    (
        SELECT REPLACE(src1.t1, NCHAR(34) + N', ', NCHAR(31)) AS split_text   ,
    ) AS src

    CROSS APPLY STRING_SPLIT(src.split_text, NCHAR(31)) AS parts

    CROSS APPLY (SELECT LTRIM(RTRIM(parts.value)) AS value0) AS a

    CROSS APPLY
    (
        SELECT CASE WHEN LEFT(a.value0, 1) = N'['
                    THEN SUBSTRING(a.value0, 2, LEN(a.value0))
                    ELSE a.value0 END AS value1
    ) AS b

    CROSS APPLY
    (
        SELECT CASE WHEN LEFT(b.value1, 1) IN (NCHAR(39), NCHAR(34))
                    THEN SUBSTRING(b.value1, 2, LEN(b.value1))
                    ELSE b.value1 END AS value2
    ) AS c

    CROSS APPLY
    (
        SELECT CASE WHEN RIGHT(c.value2, 1) = N']'
                    THEN LEFT(c.value2, LEN(c.value2) - 1)
                    ELSE c.value2 END AS value3
    ) AS d

    CROSS APPLY
    (
        SELECT CASE WHEN RIGHT(d.value3, 1) IN (NCHAR(39), NCHAR(34))
                    THEN LEFT(d.value3, LEN(d.value3) - 1)
                    ELSE d.value3 END AS value4
    ) AS d2

    CROSS APPLY
    (
        SELECT LTRIM(RTRIM(
                   REPLACE(REPLACE(REPLACE(d2.value4, N'  ', N' '), N'  ', N' '), N'  ', N' ')
               )) AS amenity
    ) AS e

    WHERE NULLIF(e.amenity, N'') IS NOT NULL
      AND LEN(e.amenity) <= 450
)
INSERT INTO SILVER.LISTING_AMENITY (listing_id, amenity_raw)
SELECT listing_id, amenity_raw
FROM ParsedAmenities;
GO

CREATE UNIQUE INDEX UX_LISTING_AMENITY
ON SILVER.LISTING_AMENITY (listing_id, amenity_raw);
GO

CREATE NONCLUSTERED INDEX IX_LISTING_AMENITY_listing_id
ON SILVER.LISTING_AMENITY (listing_id);
GO

/* =====================================================================
   3) Rules table
      The lowest priority value is applied first.
   ===================================================================== */
DROP TABLE IF EXISTS SILVER.AMENITY_RULE;
GO

CREATE TABLE SILVER.AMENITY_RULE
(
    rule_id      INT IDENTITY(1,1) PRIMARY KEY,
    priority     INT           NOT NULL,
    pattern      NVARCHAR(200) NOT NULL,   -- LIKE pattern
    amenity_name NVARCHAR(100) NOT NULL,
    is_active    BIT           NOT NULL DEFAULT 1
);
GO

INSERT INTO SILVER.AMENITY_RULE (priority, pattern, amenity_name) VALUES
(5,   '% view',                  'View'),
-- Internet
(10,  'Pocket wifi%',            'Pocket wifi'),
(11,  '%wifi%',                  'Wifi'),
(12,  'Ethernet%',               'Ethernet connection'),
-- Entertainment
(20,  '%sound system%',          'Sound system'),
(21,  '%speaker%',               'Sound system'),
(22,  '%HDTV%',                  'TV'),
(23,  'TV%',                     'TV'),
(24,  '% inch TV%',              'TV'),
(25,  'Game console%',           'Game console'),
(26,  'Exercise equipment%',     'Exercise equipment'),
(27,  '%games%',                 'Games'),
-- Kitchen
(30,  'Coffee maker%',           'Coffee maker'),
(31,  '%microwave%',             'Microwave'),
(32,  '%oven%',                  'Oven'),
(33,  '%stove%',                 'Stove'),
(34,  'Mini fridge%',            'Mini fridge'),
(35,  '%refrigerator%',          'Refrigerator'),
(36,  'Dishwasher%',             'Dishwasher'),
-- Bathroom
(40,  '%shower gel%',            'Shower gel'),
(41,  '%shampoo%',               'Shampoo'),
(42,  '%conditioner%',           'Conditioner'),
(43,  '%body soap%',             'Body soap'),
(44,  'Hair dryer%',             'Hair dryer'),
-- Laundry
(50,  '%washer%',                'Washer'),
(51,  '%dryer%',                 'Dryer'),
-- Climate
(60,  '%air conditioning%',      'Air conditioning'),
(61,  'AC -%',                   'Air conditioning'),
(62,  'Window AC%',              'Air conditioning'),
(63,  '%heating%',               'Heating'),
(64,  '%heater%',                'Heating'),
(65,  'Indoor fireplace%',       'Indoor fireplace'),
-- Parking
(70,  'EV charger%',             'EV charger'),
(71,  '%parking%',               'Parking'),
(72,  '%garage%',                'Parking'),
-- Family
(80,  '%high chair%',            'High chair'),
(81,  '%crib%',                  'Crib'),
(82,  'Baby bath%',              'Baby bath'),
(83,  'Baby monitor%',           'Baby monitor'),
(84,  'Changing table%',         'Changing table'),
(85,  'Children_s books%',       'Children''s books and toys'),
(86,  'Children_s dinnerware%',  'Children''s dinnerware'),
(87,  'Children_s bikes%',       'Children''s bikes'),
(88,  'Children_s playroom%',    'Children''s playroom'),
-- Leisure / Outdoor
(90,  '%pool table%',            'Pool table'),
(91,  '%pool%',                  'Pool'),
(92,  '%hot tub%',               'Hot tub'),
(93,  '%sauna%',                 'Sauna'),
(94,  '%gym%',                   'Gym'),
(95,  '%BBQ%',                   'BBQ grill'),
(96,  '%beach access%',          'Beach access'),
(97,  '%resort access%',         'Resort access'),
(98,  '%patio or balcony%',      'Patio or balcony'),
(99,  '%backyard%',              'Backyard'),
(100, '%outdoor kitchen%',       'Outdoor kitchen'),
-- Services & Storage
(110, 'Housekeeping%',           'Housekeeping'),
(111, 'Clothing storage%',       'Clothing storage'),
(112, 'Cleaning available%',     'Cleaning available during stay'),
(113, '%lockbox%',               'Lockbox'),
(114, 'Keypad%',                 'Keypad'),
(115, 'Smart lock%',             'Smart lock'),
-- Safety
(120, '%alarm%',                 'Alarm'),
(121, '%security cameras%',      'Security cameras');
GO

SELECT COUNT(*) AS rules_count FROM SILVER.AMENITY_RULE;   
GO


DROP TABLE IF EXISTS SILVER.AMENITY_MAPPING;
GO

SELECT
    r.amenity_raw,
    r.amenity_clean,
    COALESCE(m.amenity_name, r.amenity_clean)      AS amenity_name,
    CASE WHEN m.amenity_name IS NULL THEN 0 ELSE 1 END AS matched_by_rule
INTO SILVER.AMENITY_MAPPING
FROM
(
    SELECT d.amenity_raw,
           LTRIM(RTRIM(
               CASE WHEN p.pos > 0 THEN LEFT(d.amenity_raw, p.pos - 1) ELSE d.amenity_raw END
           )) AS amenity_clean
    FROM (SELECT DISTINCT amenity_raw FROM SILVER.LISTING_AMENITY) AS d
    CROSS APPLY
    (
        SELECT ISNULL(MIN(x), 0) AS pos
        FROM (VALUES (CHARINDEX(N': ', d.amenity_raw)),
                     (CHARINDEX(N' - ', d.amenity_raw)),
                     (CHARINDEX(N' ' + NCHAR(8211) + N' ', d.amenity_raw)),
                     (CHARINDEX(N' with ', d.amenity_raw))) AS t(x)
        WHERE x > 0
    ) AS p
) AS r
OUTER APPLY
(
    SELECT TOP (1) ru.amenity_name
    FROM SILVER.AMENITY_RULE AS ru
    WHERE ru.is_active = 1
      AND r.amenity_clean LIKE ru.pattern
    ORDER BY ru.priority
) AS m;
GO

ALTER TABLE SILVER.AMENITY_MAPPING ALTER COLUMN amenity_raw NVARCHAR(450) NOT NULL;
GO
ALTER TABLE SILVER.AMENITY_MAPPING
    ADD CONSTRAINT PK_AMENITY_MAPPING PRIMARY KEY (amenity_raw);
GO

IF COL_LENGTH('SILVER.LISTING_AMENITY', 'amenity_name') IS NULL
    ALTER TABLE SILVER.LISTING_AMENITY ADD amenity_name NVARCHAR(200) NULL;
GO

UPDATE a
SET    a.amenity_name = m.amenity_name
FROM   SILVER.LISTING_AMENITY AS a
JOIN   SILVER.AMENITY_MAPPING AS m
       ON m.amenity_raw = a.amenity_raw;
GO

ALTER TABLE SILVER.LISTING_AMENITY ALTER COLUMN amenity_name NVARCHAR(200) NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_LISTING_AMENITY_name
ON SILVER.LISTING_AMENITY (amenity_name);
GO


/* ==========================================
   VALIDATION OF SILVER LAYER LISTING_AMENITY
   ========================================== */
   SELECT COUNT(*)                     AS total_amenity_rows      FROM SILVER.LISTING_AMENITY;
SELECT COUNT(DISTINCT listing_id)   AS listings_with_amenities FROM SILVER.LISTING_AMENITY;
SELECT COUNT(DISTINCT amenity_raw)  AS distinct_raw            FROM SILVER.LISTING_AMENITY;
SELECT COUNT(DISTINCT amenity_name) AS distinct_after_mapping  FROM SILVER.LISTING_AMENITY;

SELECT COUNT(*) AS listings_without_amenities
FROM SILVER.airbnb_listings AS s
WHERE NOT EXISTS (SELECT 1 FROM SILVER.LISTING_AMENITY a WHERE a.listing_id = s.listing_id);

SELECT amenity_raw
FROM SILVER.LISTING_AMENITY
WHERE LEFT(amenity_raw, 1)  IN (N'[', N']', N'''', N'"')
   OR RIGHT(amenity_raw, 1) IN (N'[', N']', N'''', N'"')
   OR amenity_raw LIKE N'%\u%'
   OR amenity_raw LIKE N'%\x%';

SELECT TOP (20) LEN(amenity_raw) AS len, amenity_raw
FROM SILVER.LISTING_AMENITY
ORDER BY LEN(amenity_raw) DESC;

SELECT
    CAST(100.0 * SUM(CASE WHEN m.matched_by_rule = 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS rule_coverage_pct,
    COUNT(DISTINCT a.amenity_name) AS distinct_amenities_after
FROM SILVER.LISTING_AMENITY AS a
JOIN SILVER.AMENITY_MAPPING AS m ON m.amenity_raw = a.amenity_raw;


SELECT m.amenity_name, COUNT(DISTINCT a.listing_id) AS listings
FROM SILVER.LISTING_AMENITY AS a
JOIN SILVER.AMENITY_MAPPING AS m ON m.amenity_raw = a.amenity_raw
WHERE m.matched_by_rule = 0
GROUP BY m.amenity_name
ORDER BY listings DESC;

SELECT amenity_name, COUNT(*) AS raw_variants
FROM SILVER.AMENITY_MAPPING
GROUP BY amenity_name
HAVING COUNT(*) > 1
ORDER BY raw_variants DESC;


SELECT amenity_name, COUNT(DISTINCT listing_id) AS listings
FROM SILVER.LISTING_AMENITY
GROUP BY amenity_name
ORDER BY listings DESC;

SELECT COUNT_BIG(*) AS missing_amenity_names
FROM SILVER.LISTING_AMENITY
WHERE amenity_name IS NULL
   OR LTRIM(RTRIM(amenity_name)) = N'';


SELECT
    listing_id,
    amenity_raw,
    COUNT_BIG(*) AS occurrences
FROM SILVER.LISTING_AMENITY
GROUP BY listing_id, amenity_raw
HAVING COUNT_BIG(*) > 1;



SELECT
    a.listing_id,
    a.amenity_raw,
    a.amenity_name
FROM SILVER.LISTING_AMENITY AS a
LEFT JOIN SILVER.airbnb_listings AS l
    ON a.listing_id = l.listing_id
WHERE l.listing_id IS NULL;


SELECT *
FROM SILVER.AMENITY_MAPPING
WHERE amenity_raw IS NULL
   OR amenity_clean IS NULL
   OR LTRIM(RTRIM(amenity_clean)) = N''
   OR amenity_name IS NULL
   OR LTRIM(RTRIM(amenity_name)) = N''
   OR matched_by_rule IS NULL;




SELECT
    a.listing_id,
    a.amenity_raw,
    a.amenity_name AS listing_amenity_name,
    m.amenity_name AS mapping_amenity_name
FROM SILVER.LISTING_AMENITY AS a
LEFT JOIN SILVER.AMENITY_MAPPING AS m
    ON a.amenity_raw = m.amenity_raw
WHERE m.amenity_raw IS NULL
   OR a.amenity_name <> m.amenity_name
   OR a.amenity_name IS NULL;



SELECT
    l.city,
    COUNT_BIG(*) AS listings_without_amenities
FROM SILVER.airbnb_listings AS l
WHERE NOT EXISTS
(
    SELECT 1
    FROM SILVER.LISTING_AMENITY AS a
    WHERE a.listing_id = l.listing_id
)
GROUP BY l.city
ORDER BY l.city;


SELECT
    amenity_name,
    COUNT_BIG(*) AS raw_variants
FROM SILVER.AMENITY_MAPPING
WHERE matched_by_rule = 0
GROUP BY amenity_name
ORDER BY raw_variants DESC;



SELECT
    OBJECT_SCHEMA_NAME(parent_object_id) AS schema_name,
    OBJECT_NAME(parent_object_id) AS table_name,
    name AS constraint_name,
    type_desc
FROM sys.objects
WHERE parent_object_id IN
(
    OBJECT_ID('SILVER.airbnb_listings'),
    OBJECT_ID('SILVER.LISTING_AMENITY'),
    OBJECT_ID('SILVER.AMENITY_MAPPING')
)
AND type IN ('PK', 'F', 'UQ')
ORDER BY table_name, type_desc;


SELECT
    OBJECT_NAME(object_id) AS table_name,
    name AS index_name,
    type_desc,
    is_unique,
    is_primary_key
FROM sys.indexes
WHERE object_id IN
(
    OBJECT_ID('SILVER.airbnb_listings'),
    OBJECT_ID('SILVER.LISTING_AMENITY'),
    OBJECT_ID('SILVER.AMENITY_MAPPING')
)
AND index_id > 0
ORDER BY table_name, index_name;
GO


