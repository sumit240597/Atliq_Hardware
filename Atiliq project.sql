 ---  Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region

select distinct(market)
from dim_customer
where customer like "%Atliq Exclusive%" and region ="APAC"


-- What is the percentage of unique product increase in 2021 vs. 2020?
with Pro_yr2020 as
(
SELECT COUNT(DISTINCT(product_code)) AS Production_20 FROM fact_manufacturing_cost
            WHERE cost_year = 2020),
            
  Pro_yr2021 as
  (          
SELECT COUNT(DISTINCT(product_code)) AS Production_21 FROM fact_manufacturing_cost
            WHERE cost_year = 2021)

select Pro_yr2020.Production_20 as Unique_Product_2020,
        Pro_yr2021.Production_21 as Unique_Product_2021,
        concat(round((Pro_yr2021.Production_21-Pro_yr2020.Production_20)*100/Pro_yr2020.Production_20,2),'%') As Production_Change
from Pro_yr2020,Pro_yr2021


-- Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts

SELECT segment, count(product) AS product_count FROM dim_product
    GROUP BY segment
    ORDER BY product_count DESC;
    
 -- Follow-up: Which segment had the most increase in unique products in
-- 2021 vs 2020?    

with Pro_yr20 as
(
select p.segment,count(distinct(m.product_code)) as Unique_Product20
from fact_manufacturing_cost m 
Right JOIN dim_product p
on p.product_code=m.product_code
where m.cost_year = 2020
group by p.segment),

Pro_yr21 as
(
select p.segment,count(distinct(m.product_code)) as Unique_Product21
from fact_manufacturing_cost m 
Right JOIN dim_product p
on p.product_code=m.product_code
where m.cost_year = 2021
group by p.segment)

select Pro_yr20.segment, Pro_yr21.Unique_Product21 as Product_Count_21,
Pro_yr20.Unique_Product20 as Product_Count_20,
concat(Pro_yr21.Unique_Product21-Pro_yr20.Unique_Product20)as difference
from Pro_yr20 
join Pro_yr21
on Pro_yr20.segment= Pro_yr21.segment
order by difference asc

-- Get the products that have the highest and lowest manufacturing costs

select f.product_code,product, manufacturing_cost
from fact_manufacturing_cost f
join dim_product p 
on f.product_code=p.product_code
where f.manufacturing_cost =(select max(manufacturing_cost) from fact_manufacturing_cost) or
f.manufacturing_cost =(select min(manufacturing_cost) from fact_manufacturing_cost)
order by manufacturing_cost desc;

-- Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market

select c.customer,f.customer_code,round(avg(pre_invoice_discount_pct) *100,2) as Average_discount_Percentage
from fact_pre_invoice_deductions f
join dim_customer c
on f.customer_code = c.customer_code
where market ="India" and fiscal_year = 2021
group by c.customer,f.customer_code
order by Average_discount_Percentage desc limit 5;

--- Get the complete report of the Gross sales amount for the customer “Atliq
-- Exclusive” for each month



with Gross_Sales as
(
select date, fs.customer_code,fg.fiscal_year,(fg.gross_price*fs.sold_quantity) as gross_monthly_sales
from fact_gross_price fg
join fact_sales_monthly fs
on fg.product_code = fs.product_code
and fg.fiscal_year=fs.fiscal_year
),

customer as
(
  SELECT date, dc.customer_code, gross_monthly_sales FROM Gross_Sales gs
            JOIN dim_customer dc
            ON gs.customer_code = dc.customer_code
            WHERE customer = "Atliq Exclusive")
            
select  monthname(date) as Months, YEAR(date) Year,ROUND(SUM(gross_monthly_sales) / 1000000, 2) as Gross_Sales_Amount
from customer
group by Months, Year;

--- In which quarter of 2020, got the maximum total_sold_quantity

with q as 
(
select sold_quantity,
case
when month(date) between 09 and 11 then "Q1"
when month(date) in (12,01,02) then "Q2"
when month(date) between 03 and 05 then "Q3"
when month(date) between 06 and 08 then "Q4"
end as Quarter
from fact_sales_monthly
where fiscal_year = 2020)
select Quarter, sum(sold_quantity) as total_sold_quantity
from q
group by quarter
order by total_sold_quantity desc

--- Which channel helped to bring more gross sales in the fiscal year 2021
--- and the percentage of contribution?

with gross_sales as
(
 select  fs.customer_code,(fg.gross_price*fs.sold_quantity) as gross_monthly_sales
from fact_gross_price fg
join fact_sales_monthly fs
on fg.product_code = fs.product_code
and fg.fiscal_year=fs.fiscal_year
where fg.fiscal_year=2021
),
channel_table as
(select channel,round(sum(gross_monthly_sales/100000),3) as gross_monthly_sales
from gross_sales gs
join dim_customer dc 
on dc.customer_code = gs.customer_code
group by channel
),

total_sum as ( 
select sum( gross_monthly_Sales) as sum_ from channel_table)

select ct.*,concat(round(ct.gross_monthly_sales*100/ts.sum_,2),'%') as Percentage
   FROM channel_table ct, total_sum ts
   ORDER BY percentage DESC;


--- Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021?

with product_table as
(
SELECT dp.division, f.product_code, dp.product, SUM(f.sold_quantity) AS total_sold_quantity 
FROM fact_sales_monthly f
JOIN dim_product dp
ON f.product_code = dp.product_code
WHERE f.fiscal_year = 2021
GROUP BY f.product_code, dp.division, dp.product
),
    rank_table AS (
        SELECT *, RANK () OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order FROM product_table)

SELECT * from rank_table
    WHERE rank_order < 4;