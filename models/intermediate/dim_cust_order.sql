{{ config(materialized="table") }}

with
    customers as (select * from {{ ref("customers") }}),
    orders as (select * from {{ ref("orders") }}),
    orderanalyticscte as (
        select
            c.customerid,
            c.firstname,
            c.lastname,
            o.orderid,
            o.orderdate,
            o.totalamount,
            o.status,
            -- 1. Rank orders per customer (1 = most recent order)
            row_number() over (
                partition by o.customerid order by o.orderdate desc, o.orderid desc
            ) as ordersequencerank,

            -- 2. Running total of customer spending over time
            sum(o.totalamount) over (
                partition by o.customerid order by o.orderdate asc, o.orderid asc
            ) as runningtotalspent,

            -- 3. Moving average amount of the current order and the 2 orders before it
            avg(o.totalamount) over (
                partition by o.customerid
                order by o.orderdate asc, o.orderid asc
                rows between 2 preceding and current row
            ) as rollingthreeorderaverage,

            -- 4. Get the date of the previous order
            lag(o.orderdate, 1) over (
                partition by o.customerid order by o.orderdate asc, o.orderid asc
            ) as previousorderdate
        from customers c
        inner join orders o on c.customerid = o.customerid
    )
-- Final Selection & Calculations
select
    customerid,
    firstname,
    lastname,
    orderid,
    orderdate,
    totalamount,
    status,
    runningtotalspent,
    round(rollingthreeorderaverage, 2) as rollingthreeorderaverage,
    -- 5. Snowflake DATEDIFF format: DATEDIFF(<part>, <start_date>, <end_date>)
    coalesce(datediff('day', previousorderdate, orderdate), 0) as dayssincelastorder
from orderanalyticscte
-- 6. Filter to only return the top 2 latest orders for each customer
where ordersequencerank <= 2
order by customerid asc, ordersequencerank asc
