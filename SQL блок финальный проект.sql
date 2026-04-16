CREATE DATABASE Customers_transactions;
SET SQL_SAFE_UPDATES = 0;
UPDATE Customers SET Gender = NULL WHERE Gender = '';
UPDATE Customers SET Age = NULL WHERE Age = '';
ALTER TABLE Customers MODIFY Age INT NULL;

SELECT * FROM Customers;

CREATE TABLE Transactions
(date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2));

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS_final.csv"
INTO TABLE Transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(@date_new, @Id_check, @ID_client, @Count_products, @Sum_payment)
SET 
date_new = @date_new,
Id_check = @Id_check,
ID_client = @ID_client,
Count_products = @Count_products,
Sum_payment = CAST(TRIM(REPLACE(@Sum_payment, ';', '')) AS DECIMAL(10,2));


WITH monthly AS (
    SELECT 
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS ym,
        COUNT(*) AS cnt_ops,
        SUM(Sum_payment) AS total_sum,
        AVG(Sum_payment) AS avg_check
    FROM Transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY ID_client, ym
),

clients_12_months AS (
    SELECT ID_client
    FROM monthly
    GROUP BY ID_client
    HAVING COUNT(DISTINCT ym) = 12
)

SELECT 
    m.ID_client,
    COUNT(*) AS total_operations,
    SUM(m.total_sum) AS total_amount,
    AVG(m.avg_check) AS avg_check,
    AVG(m.total_sum) AS avg_monthly_spend
FROM monthly m
JOIN clients_12_months c 
    ON m.ID_client = c.ID_client
GROUP BY m.ID_client;



SELECT 
    m.ID_client,
    m.ym,
    m.cnt_ops,
    m.total_sum,
    m.avg_check
FROM (
    SELECT 
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS ym,
        COUNT(*) AS cnt_ops,
        SUM(Sum_payment) AS total_sum,
        AVG(Sum_payment) AS avg_check
    FROM Transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY ID_client, ym
) m
JOIN (
    SELECT ID_client
    FROM Transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY ID_client
    HAVING COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) = 12
) c
ON m.ID_client = c.ID_client
ORDER BY m.ID_client, m.ym;


WITH base AS (
    SELECT 
        t.ID_client,
        DATE_FORMAT(t.date_new, '%Y-%m') AS ym,
        t.Sum_payment,
        c.Gender
    FROM Transactions t
    LEFT JOIN Customers c 
        ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new < '2016-06-01'
),

monthly AS (
    SELECT
        ym,
        COUNT(*) AS total_operations,
        SUM(Sum_payment) AS total_amount,
        AVG(Sum_payment) AS avg_check,
        COUNT(DISTINCT ID_client) AS unique_clients
    FROM base
    GROUP BY ym
),

year_totals AS (
    SELECT 
        SUM(total_operations) AS year_operations,
        SUM(total_amount) AS year_amount
    FROM monthly
)

SELECT 
    m.ym
FROM monthly m
CROSS JOIN year_totals y
ORDER BY m.ym;



SELECT 
    AVG(avg_check) AS avg_check_per_month,
    AVG(total_operations) AS avg_operations_per_month,
    AVG(unique_clients) AS avg_clients_per_month
FROM (
    SELECT
        DATE_FORMAT(date_new, '%Y-%m') AS ym,
        COUNT(*) AS total_operations,
        AVG(Sum_payment) AS avg_check,
        COUNT(DISTINCT ID_client) AS unique_clients
    FROM Transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY ym
) t;



WITH base AS (
    SELECT 
        DATE_FORMAT(t.date_new, '%Y-%m') AS ym,
        t.Sum_payment,
        COALESCE(c.Gender, 'NA') AS Gender
    FROM Transactions t
    LEFT JOIN Customers c 
        ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new < '2016-06-01'
),

monthly_totals AS (
    SELECT 
        ym,
        SUM(Sum_payment) AS total_amount
    FROM base
    GROUP BY ym
),

gender_stats AS (
    SELECT
        ym,
        Gender,
        COUNT(*) AS cnt_ops,
        SUM(Sum_payment) AS sum_amount
    FROM base
    GROUP BY ym, Gender
)

SELECT 
    g.ym,
    g.Gender,
    g.cnt_ops / SUM(g.cnt_ops) OVER (PARTITION BY g.ym) AS pct_operations,
    g.sum_amount / m.total_amount AS pct_amount

FROM gender_stats g
JOIN monthly_totals m 
    ON g.ym = m.ym
ORDER BY g.ym, g.Gender;