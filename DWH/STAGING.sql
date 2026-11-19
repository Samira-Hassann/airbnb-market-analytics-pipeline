USE AirbnbDW;
GO

IF SCHEMA_ID('STAGING') IS NULL
BEGIN
    EXEC('CREATE SCHEMA STAGING');
END;
GO

USE AirbnbDW;
GO

DROP TABLE IF EXISTS STAGING.airbnb_listings;
GO

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities,
    CAST('amsterdam_listings' AS NVARCHAR(100)) AS source_table
INTO STAGING.airbnb_listings
FROM BRONZE.amsterdam_listings

UNION ALL

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities, 'athens_listings'
FROM BRONZE.athens_listings

UNION ALL

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities, 'barcelona_listings'
FROM BRONZE.barcelona_listings

UNION ALL

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities, 'berlin_listings'
FROM BRONZE.berlin_listings

UNION ALL

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities, 'budapest_listings'
FROM BRONZE.budapest_listings

UNION ALL

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities, 'lisbon_listings'
FROM BRONZE.lisbon_listings

UNION ALL

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities, 'london_listings'
FROM BRONZE.london_listings

UNION ALL

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities, 'paris_listings'
FROM BRONZE.paris_listings

UNION ALL

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities, 'rome_listings'
FROM BRONZE.rome_listings

UNION ALL

SELECT city, listing_url, listing_title, guests, bedrooms, beds, baths,
       rating, reviews, cleanliness_rating, accuracy_rating,
       check_in_rating, communication_rating, location_rating,
       value_rating, lat, lng, room_type, is_superhost, property_type,
       total_price, nights, amenities, 'vienna_listings'
FROM BRONZE.vienna_listings;
GO

SELECT
    city,
    COUNT_BIG(*) AS total_listings
FROM STAGING.airbnb_listings
GROUP BY city
ORDER BY city;

SELECT COUNT_BIG(*) AS total_listings
FROM STAGING.airbnb_listings;

SELECT TOP (10) *
FROM STAGING.airbnb_listings;