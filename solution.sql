CREATE DATABASE SaaS_Business_BI;
USE SaaS_Business_BI;


CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    signup_date DATE NOT NULL
);

-- Plans table
CREATE TABLE plans (
    plan_id INT AUTO_INCREMENT PRIMARY KEY,
    plan_name VARCHAR(50) NOT NULL,
    monthly_price DECIMAL(10, 2) NOT NULL
);

-- Subscriptions table
CREATE TABLE subscriptions (
    subscription_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    plan_id INT,
    start_date DATE NOT NULL,
    end_date DATE, -- NULL represents an actively ongoing subscription
    status ENUM('active', 'canceled', 'expired') DEFAULT 'active',
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (plan_id) REFERENCES plans(plan_id)
);

-- Payments table
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    subscription_id INT,
    amount DECIMAL(10, 2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_status ENUM('success', 'failed') DEFAULT 'success',
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id)
);

-- Activity Logs table
CREATE TABLE activity_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action_type VARCHAR(50) NOT NULL,
    log_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);



-- DATA INGESTION

INSERT INTO plans (plan_name, monthly_price) VALUES 
('Basic', 9.99),
('Standard', 14.99),
('Premium', 19.99);


INSERT INTO users (first_name, last_name, email, signup_date) VALUES 
('Alice', 'Smith', 'alice@email.com', '2026-01-01'),
('Bob', 'Jones', 'bob@email.com', '2026-01-15'),
('Charlie', 'Brown', 'charlie@email.com', '2026-02-01'),
('Diana', 'Prince', 'diana@email.com', '2026-02-10'),
('Evan', 'Wright', 'evan@email.com', '2026-03-01');


INSERT INTO subscriptions (user_id, plan_id, start_date, end_date, status) VALUES 
(1, 1, '2026-01-01', NULL, 'active'),       
(2, 2, '2026-01-15', '2026-02-15', 'canceled'), 
(3, 2, '2026-02-01', NULL, 'active'),       
(4, 3, '2026-02-10', NULL, 'active'),       
(5, 3, '2026-03-01', NULL, 'active');       


INSERT INTO payments (subscription_id, amount, payment_date, payment_status) VALUES 
(1, 9.99, '2026-01-01', 'success'),
(1, 9.99, '2026-02-01', 'success'),
(1, 9.99, '2026-03-01', 'success'),
(2, 14.99, '2026-01-15', 'success'), 
(3, 14.99, '2026-02-01', 'success'),
(3, 14.99, '2026-03-01', 'success'),
(4, 19.99, '2026-02-10', 'success'),
(4, 19.99, '2026-03-10', 'success'),
(5, 19.99, '2026-03-01', 'success');


INSERT INTO activity_logs (user_id, action_type, log_timestamp) VALUES 
(1, 'login', '2026-01-02 09:00:00'),
(1, 'watch_content', '2026-01-02 09:15:00'),
(2, 'login', '2026-01-16 18:00:00'),
(2, 'change_settings', '2026-02-14 14:00:00'), 
(3, 'login', '2026-02-05 20:00:00'),
(4, 'login', '2026-03-12 11:00:00'),
(1, 'login', '2026-03-15 10:30:00');




-- 1. Complex Multidirectional INNER JOIN: Generating User Subscriptions Directory
SELECT 
    u.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS customer_name,
    p.plan_name,
    p.monthly_price,
    s.status AS subscription_status,
    s.start_date
FROM users u
INNER JOIN subscriptions s ON u.user_id = s.user_id
INNER JOIN plans p ON s.plan_id = p.plan_id
ORDER BY s.start_date ASC;

-- 2. Windows Function Pipeline: Computing Cumulative Running Total of Revenue
SELECT 
    payment_id,
    payment_date,
    amount,
    SUM(amount) OVER (ORDER BY payment_date, payment_id) AS running_total_revenue
FROM payments
WHERE payment_status = 'success';

-- 3. Core Enterprise KPI Pipeline: Monthly Recurring Revenue (MRR) & Month-over-Month Growth Analysis
WITH MonthlyRevenue AS (
    -- Step A: Aggregate chronological revenue sums into monthly segments
    SELECT 
        DATE_FORMAT(payment_date, '%Y-%m') AS payment_month,
        SUM(amount) AS total_mrr
    FROM payments
    WHERE payment_status = 'success'
    GROUP BY DATE_FORMAT(payment_date, '%Y-%m')
),
MoM_Analysis AS (
    -- Step B: Apply the LAG window function to pull previous record alongside current month
    SELECT 
        payment_month,
        total_mrr,
        LAG(total_mrr, 1) OVER (ORDER BY payment_month) AS previous_month_mrr
    FROM MonthlyRevenue
)
-- Step C: Perform arithmetic growth derivation and establish default bases using COALESCE
SELECT 
    payment_month,
    total_mrr AS current_month_mrr,
    COALESCE(previous_month_mrr, 0.00) AS previous_month_mrr,
    total_mrr - COALESCE(previous_month_mrr, 0) AS net_mrr_change,
    ROUND(
        ((total_mrr - COALESCE(previous_month_mrr, total_mrr)) / COALESCE(previous_month_mrr, total_mrr)) * 100, 
        2
    ) AS mom_growth_percentage
FROM MoM_Analysis;