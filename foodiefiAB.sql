-- case study #3

-- due to long fact table with approx 1000 rows, table and data input is given from the case study

-- A. Customer Journey 
-- Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.

-- List of the sample subscribers : (1,2,11,13,15,16,18,19)
SELECT s.*, 
    CASE WHEN p.plan_id = 0 THEN s.start_date + 7 
        WHEN p.plan_id = 4 THEN NULL
        WHEN p.plan_id = 3 THEN s.start_date + 365
    ELSE s.start_date + 30 END end_date
FROM plans p 
    JOIN subscriptions s
    ON p.plan_id = s.plan_id
    WHERE s.customer_id IN (1,2,11,13,15,16,18,19)
ORDER BY s.customer_id
-- brief description will be written later in markdown doc

-- preview data
SELECT * FROM plans

SELECT * FROM subscriptions
LIMIT 30

-- B. Data Analysis Questions
-- B.1 How many customers has Foodie-Fi ever had?
SELECT 
    COUNT(*) total_rows,
    COUNT(DISTINCT customer_id) total_customer
FROM subscriptions;

-- B.2 What is the monthly distribution of trial plan start_date values for our dataset - 
-- use the start of the month as the group by value

SELECT
    TO_CHAR(start_date,'Month') month_subscribed,
    COUNT(*) total_subscriber
FROM subscriptions 
WHERE plan_id = 0
GROUP BY 1
ORDER BY 2 DESC;

-- B.3 What plan start_date values occur after the year 2020 for our dataset? 
-- Show the breakdown by count of events for each plan_name

SELECT 
    CAST(DATE_PART('year' , s.start_date) AS integer) year_plan_started,
    p.plan_name, 
    count(s.*) count_plan_started
FROM subscriptions s
INNER JOIN plans p
    ON p.plan_id = s.plan_id
WHERE DATE_PART('year' , s.start_date ) > 2020
GROUP BY year_plan_started, p.plan_name;

-- B.4 What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT 
    SUM(CASE WHEN plan_id = 4 THEN 1 
        ELSE 0 END) total_churn,
    ROUND(100*SUM(CASE WHEN plan_id = 4 THEN 1 
        ELSE 0 END) / COUNT(DISTINCT customer_id),1) percentage_churn
FROM subscriptions;

SELECT
    COUNT(DISTINCT customer_id) total_churn,
    ROUND(
        COUNT(*)/(SELECT COUNT
                       (DISTINCT customer_id) FROM subscriptions),1) percentage_churn
FROM subscriptions
WHERE plan_id = 4 ; 
-- not sure why it shows 30.0 for both instead of 30.7 :(

-- B.5 How many customers have churned straight after their initial free trial?
-- what percentage is this rounded to 1 decimal place?
-- assumption is that free trial always starts first. customer cannot get free trial once you subscribe
-- then the free trial always starts on row 1, and 'straight' means the churned should be in row 2
-- group by 'churn' and row number '2' as condition

-- check customers who did free trial, we need to separate customers that directly subscribe without trial
SELECT COUNT(customer_id) count_customer
FROM subscriptions
WHERE plan_id = 0
-- turned out every customers, always tried free trial before subscribing. Thus, the assumption above is valid. 

WITH cte_row_sub AS ( 
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date) as row_num
    FROM subscriptions
)
SELECT SUM(CASE 
           WHEN plan_id = 4 AND row_num = 2 THEN 1 
           ELSE 0 END           
       ) straight_churn,
       ROUND(100*SUM(CASE 
           WHEN plan_id = 4 AND row_num = 2 THEN 1 
           ELSE 0 END           
       ) / COUNT (DISTINCT customer_id) ,1) percent_straight_churn
FROM cte_row_sub
-- I am still unsure why it doesnt show the decimal :( 

-- B.6 What is the number and percentage of customer plans after their initial free trial?
-- row_num must be 2 and the plan_id is not 0
WITH cte_row_sub AS ( 
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date) as row_num
    FROM subscriptions
)
SELECT 
       p.plan_id,
       p.plan_name,
       COUNT(*) count_customer,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER(),1) percentage
FROM cte_row_sub cte
INNER JOIN plans p
    ON p.plan_id = cte.plan_id
WHERE cte.row_num = 2 AND cte.plan_id <>0
GROUP BY 1, 2
ORDER BY 1;

-- B.7 What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
-- calculate how many counting rows per each customer, need to find the latest plan for each customer
-- we can sort descending and calculate 1st row from the most recent. When descending and filter, the
-- condition of the start_date must be put directly, otherwise we will get the 1st row_number that is
-- greater than 2020-12-31

WITH cte AS ( 
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) as row_num
    FROM subscriptions
    WHERE start_date <= '2020-12-31'
) 
SELECT
    p.plan_id,
    p.plan_name,
    COUNT(*) count_customer,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER(),1) percentage
FROM cte c
INNER JOIN plans p
    ON p.plan_id = c.plan_id
WHERE c.row_num = 1
GROUP BY 1,2
ORDER BY 1;

-- B.8 How many customers have upgraded to an annual plan in 2020?
-- need to assume that 'have upgraded' means the customer did upgraded to annual plan,
-- regardless after that they churned or not, and disregard whatever the customer subscribed
-- before the annual plan. 

SELECT
    COUNT(DISTINCT customer_id) number_annual_plan
FROM subscriptions
WHERE (start_date BETWEEN '2020-01-01' AND '2020-12-31') AND plan_id = 3;

-- B.9 How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
-- first thing first, every customers always do trial before subscribe. therefore we filter the plan_id = 0 and plan_id =3
WITH cte AS (
SELECT *
    FROM subscriptions
    WHERE plan_id IN (0,3)
    ORDER BY customer_id
), cte_added_row AS(
SELECT *,
    ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) as row_num
FROM cte
), cte_remove AS (
SELECT *
FROM cte_added_row
    WHERE customer_id IN (
        SELECT customer_id FROM cte_added_row WHERE row_num = 2) 
), cte_days_diff AS (
    SELECT 
        t1.customer_id, 
        t1.start_date, 
        t1.start_date - t2.start_date days_to_annual_plan,
        t1.row_num
    FROM cte_added_row t1
    JOIN cte_added_row t2 ON t2.customer_id = t1.customer_id AND t2.row_num = 2
WHERE t1.row_num = 1
)
SELECT ROUND(AVG(days_to_annual_plan),2) average_days
    FROM cte_days_diff 
    
-- after a while I realize that there is an easier solution:
WITH cte_plan3 AS ( 
SELECT 
    customer_id,
    start_date
FROM subscriptions
WHERE plan_id = 3
), cte_plan0 AS (
SELECT
    customer_id,
    start_date
FROM subscriptions
WHERE plan_id = 0
)
SELECT
    ROUND(AVG(t1.start_date - t2.start_date),2)average_days
FROM cte_plan3 t1
LEFT JOIN cte_plan0 t2
    ON t1.customer_id = t2.customer_id;


-- My own bonus question: How many days on average does it take for a customer to an annual plan from the previous plan start date?
WITH cte AS ( 
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) as row_num
    FROM subscriptions
    WHERE customer_id IN (
        SELECT customer_id FROM subscriptions WHERE plan_id = 3
        )
), cte_annual_latest AS (
SELECT *, 
    CASE WHEN row_num = 1 AND plan_id = 3 THEN 1  ELSE 0 END check_row 
FROM cte
), 
cte_days_diff AS (
    SELECT 
        t1.customer_id, 
        t1.start_date, 
        t1.start_date - t2.start_date days_to_annual_plan,
        t1.row_num
    FROM cte_annual_latest t1
    JOIN cte_annual_latest t2 ON t2.customer_id = t1.customer_id AND t2.row_num = 2 -- annual plan always happens on the row# 1
WHERE t1.row_num =1 AND t1.check_row=1
)
SELECT ROUND(AVG(days_to_annual_plan),2) average_days
    FROM cte_days_diff;

-- B.10 Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH cte_plan3 AS ( 
SELECT 
    customer_id,
    start_date
FROM subscriptions
WHERE plan_id = 3
), cte_plan0 AS (
SELECT
    customer_id,
    start_date
FROM subscriptions
WHERE plan_id = 0
), cte_days_diff AS (
SELECT
    FLOOR(((t1.start_date - t2.start_date)::NUMERIC(8,2)/30)) point_value -- adding this as point of reference
        -- since we want to make the range 30 days then it is divided by 30
        -- approach with WIDTH_BUCKET can be done: WIDTH_BUCKET(t1.start_date - t2.start_date, 0, 360, 12)
FROM cte_plan3 t1
LEFT JOIN cte_plan0 t2 
    ON t1.customer_id = t2.customer_id
ORDER BY 1
)
SELECT 
    CONCAT((point_value*30), '-', (point_value+1)*30, ' days') days_period,
    COUNT(*) number_customers
FROM cte_days_diff
GROUP BY point_value
ORDER BY point_value;
    
-- B.11 How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
-- we need to filter to substract start_date and find the positive difference
-- between plan_id 2 and 1. Assume they only downgraded once. 

WITH cte_plan2 AS ( 
SELECT 
    customer_id,
    start_date
FROM subscriptions
WHERE plan_id = 2 AND start_date BETWEEN '2020-01-01' AND '2020-12-31'
), cte_plan1 AS (
SELECT
    customer_id,
    start_date
FROM subscriptions
WHERE plan_id = 1 AND start_date BETWEEN '2020-01-01' AND '2020-12-31'
), cte_days_diff AS (
SELECT
    t1.customer_id, 
    (t2.start_date - t1.start_date) days_diff,
    CASE WHEN (t2.start_date - t1.start_date) >=0 THEN 1 ELSE 0 END downgrade_sign
FROM cte_plan1 t1
INNER JOIN cte_plan2 t2
    ON t1.customer_id = t2.customer_id
ORDER BY t1.customer_id
)
SELECT count(*) FROM cte_days_diff
WHERE downgrade_sign = 1

