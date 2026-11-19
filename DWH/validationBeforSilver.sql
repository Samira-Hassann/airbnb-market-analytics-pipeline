USE [AirbnbDW] ;
GO


SELECT TOP (10) *
FROM STAGING.airbnb_listings;


SELECT
    city,
    COUNT_BIG(*) AS total_listings
FROM STAGING.airbnb_listings
GROUP BY city
ORDER BY city;


SELECT COUNT_BIG(*) AS total_listings
FROM STAGING.airbnb_listings;


SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'STAGING'
ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;


DECLARE @SQL NVARCHAR(MAX) = N'';

SELECT @SQL +=
    CASE WHEN @SQL = N'' THEN N'' ELSE N' UNION ALL ' END +
    N'SELECT
        N''' + TABLE_NAME + N''' AS table_name,
        N''' + COLUMN_NAME + N''' AS column_name,
        COUNT_BIG(*) AS total_rows,
        COUNT_BIG(*) - COUNT_BIG(' + QUOTENAME(COLUMN_NAME) + N') AS null_count
      FROM STAGING.' + QUOTENAME(TABLE_NAME)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'STAGING';

EXEC sp_executesql @SQL;




SELECT @SQL +=
    N'
    SELECT
        N''' + REPLACE(TABLE_NAME, '''', '''''') + N''' AS table_name,
        COUNT_BIG(*) AS duplicate_urls
    FROM (
        SELECT listing_url
        FROM STAGING.' + QUOTENAME(TABLE_NAME) + N'
        WHERE listing_url IS NOT NULL
        GROUP BY listing_url
        HAVING COUNT_BIG(*) > 1
    ) AS D
    UNION ALL'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'STAGING'
  AND COLUMN_NAME = 'listing_url';

-- Remove the last UNION ALL
SET @SQL = LEFT(@SQL, LEN(@SQL) - LEN('UNION ALL'));

EXEC sys.sp_executesql @SQL;



DROP TABLE IF EXISTS #DescribeResults;

CREATE TABLE #DescribeResults (  
    table_name NVARCHAR(128),
    column_name NVARCHAR(128),
    [count] BIGINT,
    [mean] FLOAT,
    [std] FLOAT,
    [min] FLOAT,
    Q1 FLOAT,
    median FLOAT,
    Q3 FLOAT,
    [max] FLOAT
);

DECLARE @TableName SYSNAME = N'airbnb_listings';
DECLARE @ColumnName SYSNAME;

DECLARE column_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'STAGING'
  AND TABLE_NAME = 'airbnb_listings'
  AND DATA_TYPE IN (
      'tinyint', 'smallint', 'int', 'bigint',
      'decimal', 'numeric', 'float', 'real',
      'money', 'smallmoney'
  )
ORDER BY ORDINAL_POSITION;

OPEN column_cursor;

FETCH NEXT FROM column_cursor
INTO @ColumnName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
        INSERT INTO #DescribeResults
        SELECT TOP (1)
            @T,
            @C,
            COUNT_BIG(' + QUOTENAME(@ColumnName) + N') OVER(),
            AVG(CAST(' + QUOTENAME(@ColumnName) + N' AS FLOAT)) OVER(),
            STDEV(CAST(' + QUOTENAME(@ColumnName) + N' AS FLOAT)) OVER(),
            MIN(CAST(' + QUOTENAME(@ColumnName) + N' AS FLOAT)) OVER(),
            PERCENTILE_CONT(0.25) WITHIN GROUP
                (ORDER BY ' + QUOTENAME(@ColumnName) + N') OVER(),
            PERCENTILE_CONT(0.50) WITHIN GROUP
                (ORDER BY ' + QUOTENAME(@ColumnName) + N') OVER(),
            PERCENTILE_CONT(0.75) WITHIN GROUP
                (ORDER BY ' + QUOTENAME(@ColumnName) + N') OVER(),
            MAX(CAST(' + QUOTENAME(@ColumnName) + N' AS FLOAT)) OVER()
        FROM STAGING.airbnb_listings;';

    EXEC sys.sp_executesql
        @SQL,
        N'@T NVARCHAR(128), @C NVARCHAR(128)',
        @T = @TableName,
        @C = @ColumnName;

    FETCH NEXT FROM column_cursor
    INTO @ColumnName;
END;

CLOSE column_cursor;
DEALLOCATE column_cursor;

SELECT *
FROM #DescribeResults
ORDER BY table_name, column_name;


DROP TABLE IF EXISTS #TextDescribe;

CREATE TABLE #TextDescribe (
    table_name NVARCHAR(128),
    column_name NVARCHAR(128),
    non_null_count BIGINT,
    distinct_values BIGINT,
    most_frequent_value NVARCHAR(4000),
    frequency BIGINT
);



DECLARE text_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'STAGING'
  AND TABLE_NAME = 'airbnb_listings'
  AND DATA_TYPE IN (
      'varchar', 'nvarchar', 'char', 'nchar', 'text', 'ntext'
  )
ORDER BY ORDINAL_POSITION;

OPEN text_cursor;

FETCH NEXT FROM text_cursor INTO @ColumnName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
        INSERT INTO #TextDescribe
        SELECT
            @T,
            @C,
            (
                SELECT COUNT_BIG(' + QUOTENAME(@ColumnName) + N')
                FROM STAGING.airbnb_listings
            ),
            (
                SELECT COUNT(DISTINCT ' + QUOTENAME(@ColumnName) + N')
                FROM STAGING.airbnb_listings
            ),
            (
                SELECT TOP (1)
                    CAST(' + QUOTENAME(@ColumnName) + N' AS NVARCHAR(4000))
                FROM STAGING.airbnb_listings
                WHERE ' + QUOTENAME(@ColumnName) + N' IS NOT NULL
                GROUP BY ' + QUOTENAME(@ColumnName) + N'
                ORDER BY COUNT_BIG(*) DESC
            ),
            (
                SELECT MAX(freq)
                FROM (
                    SELECT COUNT_BIG(*) AS freq
                    FROM STAGING.airbnb_listings
                    WHERE ' + QUOTENAME(@ColumnName) + N' IS NOT NULL
                    GROUP BY ' + QUOTENAME(@ColumnName) + N'
                ) AS F
            );';

    EXEC sys.sp_executesql
        @SQL,
        N'@T NVARCHAR(128), @C NVARCHAR(128)',
        @T = @TableName,
        @C = @ColumnName;

    FETCH NEXT FROM text_cursor INTO @ColumnName;
END;

CLOSE text_cursor;
DEALLOCATE text_cursor;

SELECT *
FROM #TextDescribe
ORDER BY table_name, column_name;




SELECT
    listing_url,
    COUNT_BIG(*) AS total_occurrences,
    COUNT(DISTINCT city) AS number_of_cities
FROM STAGING.airbnb_listings
WHERE listing_url IS NOT NULL
GROUP BY listing_url
HAVING COUNT(DISTINCT city) > 1
ORDER BY number_of_cities DESC, total_occurrences DESC;


SELECT room_type, COUNT(*) AS COUNTT 
FROM [STAGING].[airbnb_listings] 
GROUP BY room_type;

SELECT [property_type], COUNT(*) AS COUNTT 
FROM [STAGING].[airbnb_listings] 
GROUP BY [property_type];

SELECT [is_superhost], COUNT(*) AS COUNTT 
FROM [STAGING].[airbnb_listings] 
GROUP BY [is_superhost];



SELECT *
FROM [STAGING].[airbnb_listings] 
WHERE room_type = 'Room';

SELECT [listing_url] , COUNT(*) AS COUNTT
FROM [STAGING].[airbnb_listings] 
GROUP BY [listing_url]
HAVING COUNT(*) >1;




SELECT *
FROM [STAGING].[airbnb_listings] 
WHERE room_type = 'Room';


SELECT 'city' AS column_name,
       MAX(LEN(city)) AS max_character_length,
       MAX(DATALENGTH(city)) AS max_size_bytes,
       SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) AS null_count
FROM STAGING.airbnb_listings

UNION ALL

SELECT 'listing_url',
       MAX(LEN(listing_url)),
       MAX(DATALENGTH(listing_url)),
       SUM(CASE WHEN listing_url IS NULL THEN 1 ELSE 0 END)
FROM STAGING.airbnb_listings

UNION ALL

SELECT 'listing_title',
       MAX(LEN(listing_title)),
       MAX(DATALENGTH(listing_title)),
       SUM(CASE WHEN listing_title IS NULL THEN 1 ELSE 0 END)
FROM STAGING.airbnb_listings

UNION ALL

SELECT 'room_type',
       MAX(LEN(room_type)),
       MAX(DATALENGTH(room_type)),
       SUM(CASE WHEN room_type IS NULL THEN 1 ELSE 0 END)
FROM STAGING.airbnb_listings

UNION ALL

SELECT 'property_type',
       MAX(LEN(property_type)),
       MAX(DATALENGTH(property_type)),
       SUM(CASE WHEN property_type IS NULL THEN 1 ELSE 0 END)
FROM STAGING.airbnb_listings

UNION ALL

SELECT 'source_table',
       MAX(LEN(source_table)),
       MAX(DATALENGTH(source_table)),
       SUM(CASE WHEN source_table IS NULL THEN 1 ELSE 0 END)
FROM STAGING.airbnb_listings

UNION ALL

SELECT 'amenities',
       MAX(LEN(amenities)),
       MAX(DATALENGTH(amenities)),
       SUM(CASE WHEN amenities IS NULL THEN 1 ELSE 0 END)
FROM STAGING.airbnb_listings;



SELECT bedrooms, COUNT(*) AS COUNTS 
FROM STAGING.airbnb_listings 
GROUP BY bedrooms 
ORDER BY bedrooms;



SELECT beds, COUNT(*) AS COUNTS 
FROM STAGING.airbnb_listings 
GROUP BY beds 
ORDER BY beds;

SELECT baths, COUNT(*) AS COUNTS 
FROM STAGING.airbnb_listings 
GROUP BY baths 
ORDER BY baths;

SELECT nights, COUNT(*) AS COUNTS 
FROM STAGING.airbnb_listings 
GROUP BY nights 
ORDER BY nights;



WITH NumericValues AS
(
    SELECT v.column_name, v.num_value
    FROM STAGING.airbnb_listings AS s
    CROSS APPLY
    (
        VALUES
            ('guests', s.guests),
            ('bedrooms', s.bedrooms),
            ('beds', s.beds),
            ('baths', s.baths),
            ('rating', s.rating),
            ('reviews', s.reviews),
            ('cleanliness_rating', s.cleanliness_rating),
            ('accuracy_rating', s.accuracy_rating),
            ('check_in_rating', s.check_in_rating),
            ('communication_rating', s.communication_rating),
            ('location_rating', s.location_rating),
            ('value_rating', s.value_rating),
            ('lat', s.lat),
            ('lng', s.lng),
            ('total_price', s.total_price),
            ('nights', s.nights)
    ) AS v(column_name, num_value)
),
TextValues AS
(
    SELECT
        column_name,
        num_value,
        CONVERT(VARCHAR(100), num_value) AS value_text
    FROM NumericValues
    WHERE num_value IS NOT NULL
),
Parts AS
(
    SELECT
        column_name,
        num_value,
        CASE
            WHEN LEFT(value_text, 1) = '-'
                THEN SUBSTRING(value_text, 2, 100)
            ELSE value_text
        END AS unsigned_text
    FROM TextValues
),
CleanParts AS
(
    SELECT
        column_name,
        num_value,
        CASE
            WHEN CHARINDEX('E', UPPER(unsigned_text)) > 0
                THEN NULL
            ELSE unsigned_text
        END AS plain_text
    FROM Parts
),
DigitCounts AS
(
    SELECT
        column_name,
        num_value,
        CASE
            WHEN CHARINDEX('.', plain_text) > 0
                THEN CHARINDEX('.', plain_text) - 1
            ELSE LEN(plain_text)
        END AS integer_digits,
        CASE
            WHEN CHARINDEX('.', plain_text) > 0
                THEN LEN(plain_text) - CHARINDEX('.', plain_text)
            ELSE 0
        END AS decimal_digits
    FROM CleanParts
    WHERE plain_text IS NOT NULL
)
SELECT
    column_name,
    MAX(integer_digits) AS max_integer_digits,
    MAX(decimal_digits) AS max_decimal_digits,
    SUM(CASE WHEN num_value <> FLOOR(num_value)
             THEN 1 ELSE 0 END) AS decimal_values_count,
    COUNT(*) AS non_null_count
FROM DigitCounts
GROUP BY column_name
ORDER BY column_name;

