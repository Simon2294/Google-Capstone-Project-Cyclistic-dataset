-- Uniting all 12 table of data into one single table

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

-- Cheking if there are duplicated rows in the table

SELECT COUNT(*), ride_id
FROM public.merged_bike_data
GROUP BY ride_id
	HAVING COUNT(*) > 1;

-- Adding the column "ride_length" out of "started_at" and "ended_at" timestamp columns

ALTER TABLE merged_bike_data
ADD COLUMN ride_length INTERVAL GENERATED ALWAYS AS (ended_at - started_at) STORED;

-- Extracting the day of the week of every bike trip out of the column "started_at"

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
	   
-- Extracting the month of every bike trip out of the column "started_at"

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

-- Looking for nulls values 

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

-- Replacing all the null values of the table with the word "unknown" or 0

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

-- There must have been some data entry errors with the columns "started_at" and "ended_at". In some cases, "started_at" is bigger than "ended_at", which not makes sense and gives a negative number in the "ride_length" column. I replaced all this cases with a cero, setting both the start and end of a trip equal. 

UPDATE merged_bike_data
SET ended_at = started_at
WHERE ended_at < started_at;

			-- Calculating basic statistics --
			
-- Calculating the average, standard deviation, max, min, mode and median of ride length column. We can quickly apreciatte that the standard deviation is extremely high. We could have an outlier problem of some kind. 

SELECT AVG(ride_length) AS Avg_ride_length,
	ROUND(STDDEV(EXTRACT(epoch FROM ride_length)/60),2) AS std_dev_in_minutes,
	MAX(ride_length) AS Max_ride_length,
	MIN(ride_length) AS Min_ride_length
FROM public.merged_bike_data_backup
WHERE ride_length != '0';

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

-- Checking the top, bigger values of the distribrution, the problem has to do with the 'null' values in the end station and end coordinates columns that we amend them with the 'unknown' word. When this happens, most of the ride lengths are bigger than 1 day and can reach up to 30 days of ride length. This must have been an error when stopping the end of the rides either by the company infrastucture or by users. It seems to be the case that it is common for some bike sharing systems allow users to end their rides at a location of their choice, rather than a designated station, but this skews our results.    

SELECT *
FROM public.merged_bike_data
ORDER BY ride_length DESC
LIMIT 10000;

-- Counting the number of cases where the users left the bikes at an unknown location of their choice. There are aproximately 5938 cases with casual bikes rides bigger than 2 days in much cases. 

SELECT COUNT(*)
FROM public.merged_bike_data
WHERE end_station_name = 'unknown' AND end_lat = '0' AND end_lng = '0'

-- Deleting this type of cases with null ending coordinates and station (5938 cases)

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












