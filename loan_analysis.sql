-- ###########################################################
-- SQL Project: Loan Default Analysis
-- Description: Import, clean, and analyze loan data to 
--              calculate default rates by income, credit score, 
--              and EMI burden. Suitable for financial analysis.
-- Author: Maitri Patel
-- ###########################################################

-- -----------------------------------------------------------
-- Step 1: Drop existing raw table if it exists
-- -----------------------------------------------------------
DROP TABLE IF EXISTS loans;

-- -----------------------------------------------------------
-- Step 2: Create raw loans table with all columns as TEXT
--         (CSV data is imported as text first for safety)
-- -----------------------------------------------------------
CREATE TABLE loans (
    customer_id TEXT,
    age TEXT,
    income_inr TEXT,
    credit_score TEXT,
    loan_amount_inr TEXT,
    tenure_months TEXT,
    interest_rate TEXT,
    existing_emis TEXT,
    dependents TEXT,
    experience_years TEXT,
    city TEXT,
    job_type TEXT,
    education_level TEXT,
    marital_status TEXT,
    loan_purpose TEXT,
    has_credit_card TEXT,
    has_vehicle TEXT,
    default_flag TEXT
);

-- -----------------------------------------------------------
-- Step 3: Import CSV data into raw loans table
--         Ensure the CSV file exists at the given path
-- -----------------------------------------------------------
COPY loans
FROM 'C:/Program Files/PostgreSQL/16/data/train.csv'
DELIMITER ','
CSV HEADER;

-- -----------------------------------------------------------
-- Step 4: Quick checks on raw data
-- -----------------------------------------------------------
SELECT COUNT(*) AS total_rows FROM loans;
SELECT * FROM loans LIMIT 5;

-- -----------------------------------------------------------
-- Step 5: Create cleaned loans table with proper numeric types
--         This table will be used for all analysis
-- -----------------------------------------------------------
DROP TABLE IF EXISTS loans_clean;

CREATE TABLE loans_clean AS
SELECT
    customer_id,
    ROUND(age::NUMERIC)::INT AS age,
    income_inr::NUMERIC AS income,
    ROUND(credit_score::NUMERIC)::INT AS credit_score,
    loan_amount_inr::NUMERIC AS loan_amount,
    ROUND(tenure_months::NUMERIC)::INT AS tenure_months,
    interest_rate::NUMERIC AS interest_rate,
    existing_emis::NUMERIC AS existing_emis,
    ROUND(dependents::NUMERIC)::INT AS dependents,
    ROUND(experience_years::NUMERIC)::INT AS experience_years,
    city,
    job_type,
    education_level,
    marital_status,
    loan_purpose,
    has_credit_card,
    has_vehicle,
    ROUND(default_flag::NUMERIC)::INT AS default_flag
FROM loans;

-- ###########################################################
-- Step 6: Analyze default rate by income group
-- ###########################################################
SELECT  
    CASE 
        WHEN income < 400000 THEN 'Low Income'
        WHEN income BETWEEN 400000 AND 800000 THEN 'Medium Income'
        ELSE 'High Income'
    END AS income_group,
    COUNT(*) AS total_loans,
    ROUND(100.0 * SUM(default_flag)/COUNT(*), 2) AS default_rate_percent
FROM loans_clean
GROUP BY income_group
ORDER BY default_rate_percent DESC;

-- -----------------------------------------------------------
-- Step 7: Count of defaults vs non-defaults
-- -----------------------------------------------------------
SELECT default_flag, COUNT(*) AS count
FROM loans
GROUP BY default_flag;

-- -----------------------------------------------------------
-- Step 8: Alternative default rate calculation (using default_flag=0)
-- -----------------------------------------------------------
SELECT  
    CASE 
        WHEN income < 400000 THEN 'Low Income'
        WHEN income BETWEEN 400000 AND 800000 THEN 'Medium Income'
        ELSE 'High Income'
    END AS income_group,
    COUNT(*) AS total_loans,
    ROUND(
        100.0 * SUM(CASE WHEN default_flag = 0 THEN 1 ELSE 0 END) 
        / COUNT(*), 2
    ) AS default_rate_percent
FROM loans_clean
GROUP BY income_group
ORDER BY default_rate_percent DESC;

-- ###########################################################
-- Step 9: Analyze default rate by credit score category
-- ###########################################################
SELECT  
    CASE 
        WHEN credit_score < 600 THEN 'Poor'
        WHEN credit_score BETWEEN 600 AND 750 THEN 'Average'
        ELSE 'Good'
    END AS credit_category,
    COUNT(*) AS total_loans,
    ROUND(
        100.0 * SUM(CASE WHEN default_flag = 0 THEN 1 ELSE 0 END)
        / COUNT(*), 2
    ) AS default_rate_percent
FROM loans_clean
GROUP BY credit_category
ORDER BY default_rate_percent DESC;

-- ###########################################################
-- Step 10: Analyze default rate by EMI burden
-- ###########################################################
SELECT
    CASE 
        WHEN existing_emis / income > 0.4 THEN 'High EMI Burden'
        WHEN existing_emis / income BETWEEN 0.2 AND 0.4 THEN 'Medium EMI Burden'
        ELSE 'Low EMI Burden'
    END AS emi_group,
    COUNT(*) AS total_loans,
    ROUND(
        100.0 * SUM(CASE WHEN default_flag = 0 THEN 1 ELSE 0 END)
        / COUNT(*), 2
    ) AS default_rate_percent
FROM loans_clean
GROUP BY emi_group
ORDER BY default_rate_percent DESC;


-- ###########################################################
-- Step 11: Correlation analysis to identify influential factors
-- ###########################################################
SELECT 
    corr(default_flag, income) AS corr_income_default,
    corr(default_flag, credit_score) AS corr_credit_default,
    corr(default_flag, existing_emis/income) AS corr_emi_default
FROM loans_clean;

-- ###########################################################
-- Step 12: Risk segmentation based on income, credit score, and EMI burden
-- ###########################################################
SELECT *,
    CASE 
        WHEN income < 400000 AND credit_score < 600 AND existing_emis/income > 0.4 THEN 'Very High Risk'
        WHEN income < 400000 AND credit_score < 600 THEN 'High Risk'
        WHEN credit_score BETWEEN 600 AND 750 AND existing_emis/income > 0.4 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_category
FROM loans_clean
LIMIT 20;

-- ###########################################################
-- Step 13: Loan portfolio analysis by risk category
-- ###########################################################
SELECT
    risk_category,
    COUNT(*) AS total_customers,
    SUM(loan_amount) AS total_loan_exposure,
    ROUND(100.0*SUM(default_flag)/COUNT(*),2) AS default_rate_percent
FROM (
    SELECT *,
        CASE 
            WHEN income < 400000 AND credit_score < 600 AND existing_emis/income > 0.4 THEN 'Very High Risk'
            WHEN income < 400000 AND credit_score < 600 THEN 'High Risk'
            WHEN credit_score BETWEEN 600 AND 750 AND existing_emis/income > 0.4 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS risk_category
    FROM loans_clean
) sub
GROUP BY risk_category
ORDER BY total_loan_exposure DESC;

-- ###########################################################
-- Step 14: Top 10 cities with highest default rate
-- ###########################################################
SELECT city,
       COUNT(*) AS total_loans,
       ROUND(100.0*SUM(default_flag)/COUNT(*),2) AS default_rate_percent
FROM loans_clean
GROUP BY city
ORDER BY default_rate_percent DESC
LIMIT 10;

-- ###########################################################
-- Step 15: Loan-to-Income ratio analysis by income group
-- ###########################################################
SELECT 
    CASE 
        WHEN income < 400000 THEN 'Low Income'
        WHEN income BETWEEN 400000 AND 800000 THEN 'Medium Income'
        ELSE 'High Income'
    END AS income_group,
    ROUND(AVG(loan_amount / NULLIF(income,0)), 2) AS avg_loan_to_income_ratio,
    ROUND(100.0*SUM(default_flag)/COUNT(*),2) AS default_rate_percent
FROM loans_clean
WHERE income IS NOT NULL
GROUP BY income_group
ORDER BY avg_loan_to_income_ratio DESC;

