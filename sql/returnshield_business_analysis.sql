-- ============================================================
-- ReturnShield: SQL Business Analysis
-- Purpose: Analyse return behaviour, model outputs, and business insights
--
-- Table notes:
-- orders_cleaned contains the full cleaned order-line dataset.
-- return_risk_scores contains model-scored test-set order lines.
-- model_comparison, feature_importance, and model_metrics were generated in Python
-- and exported into SQLite for analysis.
-- ============================================================


--  Validate exported database tables
SELECT name AS table_name
FROM sqlite_master
WHERE type = 'table'
ORDER BY name;


-- Overall return rate
SELECT
    COUNT(*) AS total_order_lines,
    SUM(is_returned) AS returned_order_lines,
    ROUND(AVG(is_returned) * 100, 2) AS return_rate_percent
FROM orders_cleaned;


-- Return rate by sub-category
SELECT
    sub_category,
    category,
    COUNT(*) AS total_order_lines,
    SUM(is_returned) AS returned_order_lines,
    ROUND(AVG(is_returned) * 100, 2) AS return_rate_percent
FROM orders_cleaned
GROUP BY sub_category, category
HAVING COUNT(*) >= 30
ORDER BY return_rate_percent DESC
LIMIT 10;


-- Return rate by state
SELECT
    state,
    COUNT(*) AS total_order_lines,
    SUM(is_returned) AS returned_order_lines,
    ROUND(AVG(is_returned) * 100, 2) AS return_rate_percent
FROM orders_cleaned
GROUP BY state
HAVING COUNT(*) >= 50
ORDER BY return_rate_percent DESC
LIMIT 10;


-- Delivery delay impact on returns
SELECT
    CASE
        WHEN is_delayed = 1 THEN 'Delayed'
        ELSE 'Not Delayed'
    END AS delivery_status,
    COUNT(*) AS total_order_lines,
    SUM(is_returned) AS returned_order_lines,
    ROUND(AVG(is_returned) * 100, 2) AS return_rate_percent
FROM orders_cleaned
GROUP BY is_delayed
ORDER BY return_rate_percent DESC;


-- Return rate by shipping mode
SELECT
    ship_mode,
    COUNT(*) AS total_order_lines,
    SUM(is_returned) AS returned_order_lines,
    ROUND(AVG(is_returned) * 100, 2) AS return_rate_percent
FROM orders_cleaned
GROUP BY ship_mode
ORDER BY return_rate_percent DESC;


-- Highest model-scored order lines among actual returns
SELECT
    order_id,
    customer_id,
    product_id,
    category,
    sub_category,
    state,
    sales,
    delivery_duration,
    is_delayed,
    is_returned,
    ROUND(return_risk_score, 3) AS return_risk_score,
    risk_level,
    recommended_action
FROM return_risk_scores
WHERE is_returned = 1
ORDER BY return_risk_score DESC
LIMIT 10;


-- Return rate by predicted risk-score decile
WITH ranked_orders AS (
    SELECT
        *,
        NTILE(10) OVER (ORDER BY return_risk_score DESC) AS risk_decile
    FROM return_risk_scores
)
SELECT
    risk_decile,
    COUNT(*) AS total_order_lines,
    SUM(is_returned) AS actual_returned_order_lines,
    ROUND(AVG(return_risk_score), 3) AS average_risk_score,
    ROUND(AVG(is_returned) * 100, 2) AS actual_return_rate_percent
FROM ranked_orders
GROUP BY risk_decile
ORDER BY risk_decile;


-- Model comparison table
SELECT
    model,
    accuracy,
    precision_returned,
    recall_returned,
    f1_returned,
    roc_auc,
    average_precision
FROM model_comparison
ORDER BY roc_auc DESC;


-- Most important model features
SELECT
    feature,
    ROUND(importance, 4) AS importance
FROM feature_importance
ORDER BY importance DESC
LIMIT 10;


-- Return rate, sales, and profit by category
SELECT
    category,
    COUNT(*) AS total_order_lines,
    SUM(is_returned) AS returned_order_lines,
    ROUND(AVG(is_returned) * 100, 2) AS return_rate_percent,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(AVG(profit), 2) AS average_profit
FROM orders_cleaned
GROUP BY category
ORDER BY return_rate_percent DESC;


-- High-risk sub-categories by average model risk score
SELECT
    category,
    sub_category,
    COUNT(*) AS total_order_lines,
    SUM(is_returned) AS actual_returned_order_lines,
    ROUND(AVG(return_risk_score), 3) AS average_return_risk_score,
    ROUND(AVG(is_returned) * 100, 2) AS actual_return_rate_percent,
    ROUND(SUM(sales), 2) AS total_sales
FROM return_risk_scores
GROUP BY category, sub_category
HAVING COUNT(*) >= 20
ORDER BY average_return_risk_score DESC
LIMIT 10;