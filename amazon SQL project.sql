USE amazon

SELECT * FROM category ;
SELECT * FROM customers ;
SELECT * FROM inventory ;
SELECT * FROM order_items ;
SELECT * FROM orders ;
SELECT * FROM payments ;
SELECT * FROM products ;
SELECT * FROM sellers ;
SELECT * FROM shippings ;

--1.Top Selling Products
--Query the top 10 products by total sales value.
select top 10 p.product_id ,
p.product_name ,
SUM(o.total_sale) AS total_sales,
count(distinct o.order_id) as total_order
from products as p 
join order_items as o 
ON p.product_id=o.product_id
group by p.product_id,product_name
order by total_sales desc

--2. Revenue by Category
--Calculate total revenue , percentage contribution of each category 
--to the total sales
SELECT c.category_id, c.category_name ,
SUM(o.total_sale) AS total_sales ,
SUM(o.total_sale) / (select SUM(total_sale) from order_items)*100 as perce_cont
from order_items as o
join products as p ON o.product_id=p.product_id
left join category as c ON c.category_id=p.category_id
group by c.category_id, c.category_name 
order by total_sales desc


--3. Average Order Value (AOV)
--Compute the average order value for each customer.
--Challenge: Include only customers with more than 5 orders.
SELECT c.customer_id ,
CONCAT(c.first_name,' ',c.last_name) as full_name,
SUM(oi.total_sale) / COUNT(O.order_id) as aov
from orders as o
JOIN customers as c
ON o.customer_id=c.customer_id
JOIN order_items as oi
ON o.order_id = oi.order_id
group by c.customer_id , CONCAT(c.first_name,' ',c.last_name)
Having COUNT(o.order_id) > 5

--4. Monthly Sales Trend
--Query monthly total sales over the past year.
--Challenge: Display the sales trend, grouping by month,
--return current_month sale, last month sale!

WITH MonthlySales AS (
    SELECT
        YEAR(o.order_date) AS year,
        MONTH(o.order_date) AS month,
        ROUND(SUM(oi.total_sale), 2) AS total_sale
    FROM
        orders AS o
    JOIN
        order_items AS oi ON oi.order_id = o.order_id
    WHERE
        o.order_date >= DATEADD(year, -1, (SELECT MAX(order_date) FROM orders))
        AND o.order_date <= (SELECT MAX(order_date) FROM orders)
    GROUP BY
        YEAR(o.order_date),
        MONTH(o.order_date)
)
SELECT
    year,
    month,
    total_sale AS current_month_sale,
    LAG(total_sale, 1) OVER (ORDER BY year, month) AS last_month_sale
FROM
    MonthlySales
ORDER BY
     month;


--7. Customer Lifetime Value (CLTV)
--Calculate the total value of orders placed by each customer over their lifetime.
--Challenge: Rank customers based on their CLTV.


SELECT 
	c.customer_id,
	CONCAT(c.first_name,' ', c.last_name) as full_name,
	SUM(oi.total_sale) as CLTV,
	count(*) as no_order,
	DENSE_RANK() OVER(ORDER BY SUM(total_sale) DESC) as cx_ranking
FROM orders as o
JOIN customers as c
ON c.customer_id = o.customer_id
JOIN order_items as oi
ON oi.order_id = o.order_id
GROUP BY c.customer_id,
	CONCAT(c.first_name,' ', c.last_name) 




--5. Customers with No Purchases
--Find customers who have registered but never placed an order.
--Challenge: List customer details and the time since their registration.
Select * from customers where customer_id NOT IN 
(select distinct customer_id from orders)

--6. Least-Selling Categories by State
--Identify the least-selling product category for each state.
--Challenge: Include the total sales for that category within each state.

SELECT 
	c.state,
	ca.category_name,
	SUM(oi.total_sale) as total_sale,
	RANK() OVER(PARTITION BY c.state ORDER BY SUM(oi.total_sale) ) as rank
FROM orders as o
JOIN customers as c
ON o.customer_id = c.customer_id
JOIN order_items as oi
ON o.order_id = oi.order_id
JOIN products as p
ON oi.product_id = p.product_id
JOIN category as ca
ON ca.category_id = p.category_id
GROUP BY c.state,ca.category_name

--7. Inventory Stock Alerts
--Query products with stock levels below a certain threshold (e.g., less than 10 units).
--Challenge: Include last restock date and warehouse information.
SELECT
  p.product_id,
  p.product_name,
  i.warehouse_id,
  i.stock as available_stock,
  i.last_stock_date
FROM
  inventory AS i
JOIN
  products AS p ON i.product_id = p.product_id
WHERE
  i.stock < 10;

--8. Shipping Delays
--Identify orders where the shipping date is later than 3 days after the order date.
--Challenge: Include customer, order details, and delivery provider.
SELECT
  c.customer_id,
  o.order_id,
  o.order_date,
  CONCAT(c.first_name,' ', c.last_name) AS name,
  s.shipping_date,
  DATEDIFF(day, o.order_date, s.shipping_date) AS shipping_delay
FROM customers AS c
JOIN  orders AS o ON c.customer_id = o.customer_id
JOIN shippings AS s ON o.order_id = s.order_id
WHERE DATEDIFF(day, o.order_date, s.shipping_date) > 3;


--9. Top 5 Customers by Orders in Each State
--Identify the top 5 customers with the highest number of orders for each state.
--Challenge: Include the number of orders and total sales for each customer.



SELECT state, name, order_total, total_sales, rank_in_state
FROM (
SELECT  c.state,CONCAT(c.first_name, ' ', c.last_name) AS name,
        COUNT(o.order_id) AS order_total,
        SUM(oi.total_sale) AS total_sales,
        ROW_NUMBER() OVER (
        PARTITION BY c.state 
            ORDER BY COUNT(o.order_id) DESC
        ) AS rank_in_state
    FROM customers c
    JOIN orders o 
        ON c.customer_id = o.customer_id
    JOIN order_items oi 
        ON o.order_id = oi.order_id
    GROUP BY c.state, c.first_name, c.last_name
) AS ranked
WHERE ranked.rank_in_state <= 5
ORDER BY state, rank_in_state;


--10. Payment Success Rate 
--Calculate the percentage of successful payments across all orders.
--Challenge: Include breakdowns by payment status (e.g., failed, pending).
SELECT 
    p.payment_status,
    COUNT(*) AS total_cnt,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM payments) AS DECIMAL(5,2)) AS percentage
FROM payments AS p
JOIN orders AS o 
    ON p.order_id = o.order_id
GROUP BY p.payment_status;



--11. Product Profit Margin
--Calculate the profit margin for each product (difference between price and cost of goods sold).
--Challenge: Rank products by their profit margin, showing highest to lowest.
SELECT p.product_id,
       p.product_name,
       SUM(total_sale - (p.cogs * o.quantity)) as profit,
	   SUM(total_sale - (p.cogs * o.quantity))/sum(total_sale)*100 as profit_margin,
	   dense_rank() over( order by SUM(total_sale - (p.cogs * o.quantity))/sum(total_sale)*100 desc) as rnk
from order_items as o  
JOIN products as p 
ON p.product_id=o.product_id
group by p.product_id,
       p.product_name
order by profit_margin desc


--12. Most Returned Products
--Query the top 10 products by the number of returns.
--Challenge: Display the return rate as a percentage of total units sold for each product.
SELECT p.product_id,
       p.product_name,
       count(*) as total_unit_sold,
       SUM(CASE WHEN o.order_status = 'returned' then 1 else 0 END) as total_returned,
       CAST(SUM(CASE WHEN o.order_status = 'returned' then 1 else 0 END) AS DECIMAL(10,2)) / COUNT(*) * 100 AS PER_RET
FROM order_items as oi
JOIN products as p
  ON oi.product_id = p.product_id
JOIN orders as o
  ON o.order_id = oi.order_id
GROUP BY
  p.product_id,
  p.product_name
ORDER BY PER_RET desc






