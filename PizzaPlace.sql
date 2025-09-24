CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

-- QUESTIONS
--1.What is the total amount each customer spent at the restaurant?
SELECT 
    ROW_NUMBER() OVER (ORDER BY s.customer_id) AS serial_number,
    s.customer_id, 
    SUM(m.price) AS total_amount_spent
FROM dannys_diner.sales s
JOIN dannys_diner.menu m 
    ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

--2.How many days has each customer visited the restaurant?
SELECT 
    customer_id, 
    COUNT(DISTINCT order_date) AS days_visited
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY customer_id;

--3.What was the first item from the menu purchased by each customer?
WITH ordered_orders AS (
    SELECT 
        s.customer_id, 
        m.product_name,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS rn
    FROM dannys_diner.sales s
    JOIN dannys_diner.menu m ON s.product_id = m.product_id
)
SELECT 
    customer_id, 
    product_name AS first_purchase
FROM ordered_orders
WHERE rn = 1;

--4.What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT 
    m.product_name,
    COUNT(*) AS order_count
FROM dannys_diner.sales s
JOIN dannys_diner.menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY order_count DESC
LIMIT 1;

--5.Which item was the most popular for each customer?
WITH customer_orders AS (
    SELECT 
        s.customer_id,
        m.product_name,
        COUNT(*) AS order_count,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY COUNT(*) DESC, m.product_name) AS rn
    FROM dannys_diner.sales s
    JOIN dannys_diner.menu m ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
)
SELECT 
    customer_id, 
    product_name AS most_popular_item
FROM customer_orders
WHERE rn = 1
ORDER BY customer_id; 

--6.Which item was purchased first by the customer after they became a member?
WITH customers AS (
    SELECT DISTINCT customer_id FROM sales
),
membership AS (
    SELECT customer_id, join_date FROM members
),
orders_with_membership AS (
    SELECT
        s.customer_id,
        m.product_name,
        s.order_date,
        mb.join_date
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
    LEFT JOIN membership mb ON s.customer_id = mb.customer_id
),
first_post_membership_purchase AS (
    SELECT
        customer_id,
        product_name,
        order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
    FROM orders_with_membership
    WHERE join_date IS NOT NULL AND order_date >= join_date
)
SELECT
    c.customer_id,
    COALESCE(
        (SELECT product_name 
         FROM first_post_membership_purchase f 
         WHERE f.customer_id = c.customer_id AND rn = 1),
        CASE
            WHEN m.join_date IS NULL THEN 'Not a member'
            ELSE 'No purchase after membership'
        END
    ) AS first_purchase_after_membership
FROM customers c
LEFT JOIN membership m ON c.customer_id = m.customer_id
ORDER BY c.customer_id;

--7.Which item was purchased just before the customer became a member?
WITH pre_membership_orders AS (
    SELECT 
        s.customer_id,
        m.product_name,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rn
    FROM dannys_diner.sales s
    JOIN dannys_diner.menu m ON s.product_id = m.product_id
    JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
    WHERE s.order_date < mb.join_date
)
SELECT 
    customer_id, 
    product_name AS last_purchase_before_membership
FROM pre_membership_orders
WHERE rn = 1;

--8.What is the total items and amount spent for each member before they became a member?
SELECT 
    s.customer_id,
    COUNT(*) AS total_items,
    SUM(m.price) AS total_amount_spent
FROM dannys_diner.sales s
JOIN dannys_diner.menu m ON s.product_id = m.product_id
JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

--9.If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT 
    s.customer_id,
    SUM(CASE 
        WHEN m.product_name = 'sushi' THEN m.price * 20 
        ELSE m.price * 10 
    END) AS total_points
FROM dannys_diner.sales s
JOIN dannys_diner.menu m ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

--10.In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH january_points AS (
    SELECT 
        s.customer_id,
        SUM(CASE 
            WHEN s.order_date BETWEEN mb.join_date AND (mb.join_date + INTERVAL '7 days') THEN m.price * 20
            WHEN m.product_name = 'sushi' THEN m.price * 20
            ELSE m.price * 10
        END) AS points
    FROM dannys_diner.sales s
    JOIN dannys_diner.menu m ON s.product_id = m.product_id
    LEFT JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
    WHERE s.order_date < '2021-02-01'
    GROUP BY s.customer_id
)
SELECT * FROM january_points
ORDER BY customer_id;

--BONUS QUESTIONS - The following questions are related creating basic data tables that Danny and his team can use to quickly derive insights without needing to join the underlying tables using SQL.
--11.Recreate the following table output using the available data (click url to go to Case Study)
SELECT 
    s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE 
        WHEN s.order_date >= mb.join_date THEN 'Y'
        ELSE 'N' 
    END AS member
FROM dannys_diner.sales s
JOIN dannys_diner.menu m ON s.product_id = m.product_id
LEFT JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
ORDER BY s.customer_id, s.order_date;

--12.Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet part of the loyalty program.
WITH order_status AS (
    SELECT 
        s.customer_id,
        s.order_date,
        m.product_name,
        m.price,
        CASE 
            WHEN s.order_date >= mb.join_date THEN 'Y'
            ELSE 'N' 
        END AS member
    FROM dannys_diner.sales s
    JOIN dannys_diner.menu m ON s.product_id = m.product_id
    LEFT JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
)
SELECT 
    *,
    CASE 
        WHEN member = 'Y' THEN 
            RANK() OVER (PARTITION BY customer_id, member ORDER BY order_date)
        ELSE NULL 
    END AS ranking
FROM order_status
ORDER BY customer_id, order_date;

-- Extra insights by Eshwaree
-- 1. Customer Spending Summary With Status
-- Goal: Show each customer’s total spent + membership status (Member, Non-member) with a friendly label.
SELECT
    s.customer_id,
    SUM(m.price) AS total_amount_spent,
    CASE 
        WHEN mb.customer_id IS NOT NULL THEN 'Member'
        ELSE 'Non-member'
    END AS membership_status
FROM dannys_diner.sales s
JOIN dannys_diner.menu m ON s.product_id = m.product_id
LEFT JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
GROUP BY s.customer_id, mb.customer_id
ORDER BY total_amount_spent DESC;

--2.Customer Visit Frequency Segment”
--Goal: Categorize customers by visit frequency — great for UX tagging (e.g., badges or notifications).
WITH visit_counts AS (
    SELECT customer_id, COUNT(DISTINCT order_date) AS visit_days
    FROM dannys_diner.sales
    GROUP BY customer_id
)
SELECT 
    customer_id,
    visit_days,
    CASE
        WHEN visit_days <= 2 THEN 'Low Frequency'
        WHEN visit_days <= 4 THEN 'Medium Frequency'
        ELSE 'High Frequency'
    END AS frequency_segment
FROM visit_counts
ORDER BY customer_id;

--Thank you!
--#8WeekSQLChallenge #1stCaseStudy #Danny'sDiner #DatabyDanny #DannyMa
