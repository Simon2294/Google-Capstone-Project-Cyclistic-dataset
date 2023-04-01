-- Combining all 12 tables of data into a single table:

CREATE TABLE merged_bike_data AS
SELECT * FROM "2022mar"
UNION ALL
SELECT * FROM "2022apr"
UNION ALL
SELECT * FROM "2022may"
UNION ALL
SELECT * FROM "2022jun"
UNION ALL
SELECT * FROM "2022jul"
UNION ALL
SELECT * FROM "2022aug"
UNION ALL
SELECT * FROM "2022sep"
UNION ALL
SELECT * FROM "2022oct"
UNION ALL
SELECT * FROM "2022nov"
UNION ALL
SELECT * FROM "2022dec"
UNION ALL
SELECT * FROM "2023jan"
UNION ALL
SELECT * FROM "2023feb";

-- Checking if there are duplicate rows in the table:

SELECT COUNT(*), ride_id
FROM public.merged_bike_data
GROUP BY ride_id
	HAVING COUNT(*) > 1;

-- Adding the column "ride_length" out of "started_at" and "ended_at" timestamp columns

ALTER TABLE merged_bike_data
ADD COLUMN ride_length INTERVAL GENERATED ALWAYS AS (ended_at - started_at) STORED;

-- Extracting the day of the week of every bike trip out of the column "started_at":

ALTER TABLE merged_bike_data
ADD COLUMN day_of_week VARCHAR(9);

UPDATE merged_bike_data
SET day_of_week =
  CASE extract(dow FROM started_at)
       WHEN 0 THEN 'Sunday'
       WHEN 1 THEN 'Monday'
       WHEN 2 THEN 'Tuesday'
       WHEN 3 THEN 'Wednesday'
       WHEN 4 THEN 'Thursday'
       WHEN 5 THEN 'Friday'
       WHEN 6 THEN 'Saturday'
       END;
	   
-- Extracting the month of every bike trip out of the column "started_at":

ALTER TABLE merged_bike_data 
ADD COLUMN month_name VARCHAR(20);

UPDATE merged_bike_data
SET month_name = 
  CASE EXTRACT(month FROM started_at)
       WHEN 1 THEN 'January'
       WHEN 2 THEN 'February'
       WHEN 3 THEN 'March'
       WHEN 4 THEN 'April'
       WHEN 5 THEN 'May'
       WHEN 6 THEN 'June'
       WHEN 7 THEN 'July'
       WHEN 8 THEN 'August'
       WHEN 9 THEN 'September'
       WHEN 10 THEN 'October'
       WHEN 11 THEN 'November'
       WHEN 12 THEN 'December'
  END;

-- Looking for nulls values: 

SELECT COUNT(*) AS Null_values
FROM merged_bike_data
WHERE start_station_name IS NULL 

SELECT COUNT(*) AS Null_values
FROM merged_bike_data
WHERE start_station_id IS NULL

SELECT COUNT(*) AS Null_values
FROM merged_bike_data
WHERE end_station_name IS NULL

SELECT COUNT(*) AS Null_values
FROM merged_bike_data
WHERE end_station_id IS NULL

SELECT COUNT(*) AS Null_values
FROM merged_bike_data
WHERE end_lat IS NULL

SELECT COUNT(*) AS Null_values
FROM merged_bike_data
WHERE end_lng IS NULL

-- Replacing all the null values of the table with either the string 'unknown' or the value '0':

UPDATE public.merged_bike_data
SET start_station_name = COALESCE(start_station_name, 'unknown'),
    start_station_id = COALESCE(start_station_id, 'unknown'),
    end_station_name = COALESCE(end_station_name, 'unknown'),
    end_station_id = COALESCE(end_station_id, 'unknown'),
    end_lat = COALESCE(end_lat, 0.0),
	end_lng = COALESCE(end_lng, 0.0)
WHERE start_station_name IS NULL
OR start_station_id IS NULL
OR end_station_name IS NULL
OR end_station_id IS NULL
OR end_lat IS NULL
OR end_lng IS NULL;

-- There seem to be some data entry errors in the 'started_at' and 'ended_at' columns, where some 'started_at' values are greater than their corresponding 'ended_at' values, resulting in a negative number in the 'ride_length' column, which does not make sense. I have replaced these cases with zero by setting the start and end of the trip equal to each other: 

UPDATE merged_bike_data
SET ended_at = started_at
WHERE ended_at < started_at;

			-- Calculating basic statistics --
			
-- I have calculated the average, standard deviation, maximum, minimum, mode, and median of the 'ride_length' column. It is evident that the standard deviation is extremely high. This suggests that there may be an outlier problem of some sort. 

SELECT AVG(ride_length) AS Avg_ride_length,
	ROUND(STDDEV(EXTRACT(epoch FROM ride_length)/60),2) AS std_dev_in_minutes,
	MAX(ride_length) AS Max_ride_length,
	MIN(ride_length) AS Min_ride_length
FROM public.merged_bike_data
WHERE ride_length != '0';

SELECT day_of_week, COUNT(*) AS number_of_rides
FROM public.merged_bike_data
GROUP BY day_of_week
ORDER BY number_of_rides DESC;

SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY ride_length) AS median
FROM public.merged_bike_data;

-- Looking at the quartiles distribution of ride_length

SELECT PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY ride_length) AS q1,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ride_length) AS q2,
       PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY ride_length) AS q3,
       MAX(ride_length) AS max_ride_length
FROM public.merged_bike_data;

-- Checking the top, bigger values of the distribution:    

SELECT *
FROM public.merged_bike_data
ORDER BY ride_length DESC
LIMIT 10000;

-- I have counted the number of cases where users left their bikes at an unknown location of their choice, and found approximately 5,938 such cases: 

SELECT COUNT(*)
FROM public.merged_bike_data
WHERE end_station_name = 'unknown' AND end_lat = '0' AND end_lng = '0'

-- Deleting this type of cases with null ending coordinates and station (5938 cases):

DELETE FROM public.merged_bike_data
WHERE end_station_name = 'unknown' AND end_lat = '0' AND end_lng = '0'

					--- Casual vs Member analysis --- 

-- Calculating basic statistics of each customer type

SELECT member_casual, AVG(ride_length) AS Avg_ride_length
FROM public.merged_bike_data
GROUP BY member_casual;

-- Calculating the number of rides by member type

SELECT member_casual, COUNT(*) AS number_of_rides
FROM public.merged_bike_data
GROUP BY member_casual;

-- Calculating the number of rides made by member type and by day of week

SELECT member_casual, day_of_week, COUNT(*) AS number_of_rides
FROM public.merged_bike_data
GROUP BY member_casual, day_of_week
ORDER BY member_casual, number_of_rides DESC;

-- Comparing the mean ride length of members type by day of week

SELECT member_casual, day_of_week, AVG(ride_length) AS avg_ride_length
FROM public.merged_bike_data
GROUP BY member_casual, day_of_week
ORDER BY member_casual, avg_ride_length DESC;

-- Comparing the number of rides by members type in different bike types

SELECT member_casual, rideable_type, COUNT(*) AS number_of_rides 
FROM public.merged_bike_data
GROUP BY member_casual, rideable_type
ORDER BY member_casual, rideable_type DESC;

-- Comparing the ride length by members type in different bike types

SELECT member_casual, rideable_type, AVG(ride_length) 
FROM public.merged_bike_data
GROUP BY member_casual, rideable_type
ORDER BY member_casual, AVG(ride_length) DESC;

-- Calculating the peak ride hours

SELECT TO_CHAR(started_at, 'HH12:00:00AM') AS start_hour_12h, COUNT(*) AS num_rides
FROM public.merged_bike_data
GROUP BY start_hour_12h
ORDER BY num_rides DESC;

-- Calculating the peak ride hours by customer type 

SELECT TO_CHAR(started_at, 'HH12:00:00AM') AS start_hour_12h, member_casual, COUNT(*) AS num_rides
FROM public.merged_bike_data
GROUP BY start_hour_12h, member_casual
ORDER BY start_hour_12h, num_rides DESC;

-- Calculating the most popular start and end station by user type

SELECT start_station_name, member_casual, COUNT(*) AS num_rides
FROM public.merged_bike_data
WHERE start_station_name != 'unknown' AND member_casual = 'casual'
GROUP BY start_station_name, member_casual
ORDER BY num_rides DESC
LIMIT 10;

SELECT start_station_name, member_casual, COUNT(*) AS num_rides
FROM public.merged_bike_data
WHERE start_station_name != 'unknown' AND member_casual = 'member'
GROUP BY start_station_name, member_casual
ORDER BY num_rides DESC
LIMIT 10;

SELECT end_station_name, member_casual, COUNT(*) AS num_rides
FROM public.merged_bike_data
WHERE end_station_name != 'unknown'AND member_casual = 'casual'
GROUP BY end_station_name, member_casual
ORDER BY num_rides DESC
LIMIT 10;

SELECT end_station_name, member_casual, COUNT(*) AS num_rides
FROM public.merged_bike_data
WHERE end_station_name != 'unknown'AND member_casual = 'member'
GROUP BY end_station_name, member_casual
ORDER BY num_rides DESC
LIMIT 10;

-- Calculating the monthly number of rides by member type 

SELECT member_casual, month_name, COUNT(*) AS number_of_rides
FROM public.merged_bike_data
GROUP BY member_casual, month_name
ORDER BY member_casual, number_of_rides DESC;












