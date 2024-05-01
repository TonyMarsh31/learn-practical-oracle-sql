/* ***************************************************** **
   ch01_correlating_inline_views.sql
   
   Companion script for Practical Oracle SQL, Apress 2020
   by Kim Berg Hansen, https://www.kibeha.dk
   Use at your own risk
   *****************************************************
   
   Chapter 1
   Correlating Inline Views
   
   To be executed in schema PRACTICAL
** ***************************************************** */

/* -----------------------------------------------------
   sqlcl formatting setup
   ----------------------------------------------------- */

-- set pagesize 80
-- set linesize 80
-- set sqlformat ansiconsole

/* -----------------------------------------------------
   Chapter 1 example code
   ----------------------------------------------------- */

-- Listing 1-1. The yearly sales of the 3 beers from Balthazar Brauerei
-- 一个酒厂的所有年销数据，先按产品再按销售量排序
select bp.brewery_name
     , bp.product_id as p_id
     , bp.product_name
     , ys.yr
     , ys.yr_qty
from brewery_products bp
         join yearly_sales ys
              on ys.product_id = bp.product_id
where bp.brewery_id = 518
order by bp.product_id, ys.yr;

-- Listing 1-2. Retrieving two columns from the best-selling year per beer
-- 任务2 给我一个酒厂中，卖的最好的年份和销售量
select bp.brewery_name
     , bp.product_id              as p_id
     , bp.product_name
     , (select ys.yr
        from yearly_sales ys
        where ys.product_id = bp.product_id
        order by ys.yr_qty desc
            fetch first row only) as yr
     , (select ys.yr_qty
        from yearly_sales ys
        where ys.product_id = bp.product_id
        order by ys.yr_qty desc
            fetch first row only) as yr_qty
from brewery_products bp
where bp.brewery_id = 518
order by bp.product_id;
-- 在这种做法中，最好的年份和最好的销售量分别用两个子查询来获取(一个子查询只能返回一个标量)，这样会导致两次访问yearly_sales表（两次select from）
--  以及，还有一个问题，因为拆成了两个子查询，所以用 desc order fetch first 来获取的数据可能是对不上的（即使value相同，但实际上不来自于同一行）

-- Listing 1-3. Using just a single scalar subquery and value concatenation
-- 优化1 一个经典的变通方法： 搭配数值拼接操作，只使用一次子查询
-- 即一个子查询将要查的字段都查出来，然后拼接在一起，然后外层再用substr函数分别取出来，这样只需要一次访问yearly_sales表
select brewery_name
     , product_id as p_id
     , product_name
     , to_number(
        substr(yr_qty_str, 1, instr(yr_qty_str, ';') - 1)
       )          as yr
     , to_number(
        substr(yr_qty_str, instr(yr_qty_str, ';') + 1)
       )          as yr_qty
from (select bp.brewery_name
           , bp.product_id
           , bp.product_name
           , (select ys.yr || ';' || ys.yr_qty
              from yearly_sales ys
              where ys.product_id = bp.product_id
              order by ys.yr_qty desc
                  fetch first row only) as yr_qty_str
      from brewery_products bp
      where bp.brewery_id = 518)
order by product_id;
-- 但是这种做法中多余的数据处理逻辑会使代码变得臃肿，同时若是连字符本身就在数据中存在，那么这种做法就会出现问题
-- 以及若是连接的字段不是字符串，而是其他数据类型，那么又要很多额外的处理


-- Listing 1-4. Using analytic function to be able to retrieve all columns if desired
-- 优化2 使用分析函数来获取所有列

select brewery_name
     , product_id as p_id
     , product_name
     , yr
     , yr_qty
from (select bp.brewery_name
           , bp.product_id
           , bp.product_name
           , ys.yr
           , ys.yr_qty
           , row_number() over (
        partition by bp.product_id
        order by ys.yr_qty desc
        ) as rn
      from brewery_products bp
               join yearly_sales ys
                    on ys.product_id = bp.product_id
      where bp.brewery_id = 518)
where rn = 1
order by product_id;
-- 思路大体相同，
--     这次用join而非子查询来获取数据，这样可以获取所有列,从而在外层获取任意多的列，
--     但这次不能简单地desc order fetch first了 , 替代操作的是分析函数，其对每一个产品做分区partition,然后分区中按销售量排序后用row_number()来标记，最后取出rn=1的行
-- 这种做法同时也能满足获取 second/third best selling year 的需求


-- 这足够好了（in this case）,但是在某些情况下，用关联内敛视图的进一步优化能更加灵活
-- correlating inline views 正是本章的主题

-- Listing 1-5. Achieving the same with a lateral inline view

select bp.brewery_name
     , bp.product_id as p_id
     , bp.product_name
     , top_ys.yr
     , top_ys.yr_qty
from brewery_products bp
         cross join lateral (
    select ys.yr
         , ys.yr_qty
    from yearly_sales ys
    where ys.product_id = bp.product_id
    order by ys.yr_qty desc
        fetch first row only
    ) top_ys
where bp.brewery_id = 518
order by bp.product_id;

-- Traditional style from clause without ANSI style cross join

select bp.brewery_name
     , bp.product_id as p_id
     , bp.product_name
     , top_ys.yr
     , top_ys.yr_qty
from brewery_products bp
   , lateral (
    select ys.yr
         , ys.yr_qty
    from yearly_sales ys
    where ys.product_id = bp.product_id
    order by ys.yr_qty desc
        fetch first row only
    ) top_ys
where bp.brewery_id = 518
order by bp.product_id;

-- Combining both lateral and join predicates in the on clause

select bp.brewery_name
     , bp.product_id as p_id
     , bp.product_name
     , top_ys.yr
     , top_ys.yr_qty
from brewery_products bp
         join lateral (
    select ys.yr
         , ys.yr_qty
    from yearly_sales ys
    where ys.product_id = bp.product_id
    order by ys.yr_qty desc
        fetch first row only
    ) top_ys
              on 1 = 1
where bp.brewery_id = 518
order by bp.product_id;

-- Listing 1-6. The alternative syntax cross apply

select bp.brewery_name
     , bp.product_id as p_id
     , bp.product_name
     , top_ys.yr
     , top_ys.yr_qty
from brewery_products bp
         cross apply(select ys.yr
                          , ys.yr_qty
                     from yearly_sales ys
                     where ys.product_id = bp.product_id
                     order by ys.yr_qty desc
                         fetch first row only) top_ys
where bp.brewery_id = 518
order by bp.product_id;

-- Listing 1-7. Using outer apply when you need outer join functionality

select bp.brewery_name
     , bp.product_id as p_id
     , bp.product_name
     , top_ys.yr
     , top_ys.yr_qty
from brewery_products bp
         outer apply(select ys.yr
                          , ys.yr_qty
                     from yearly_sales ys
                     where ys.product_id = bp.product_id
                       and ys.yr_qty < 400
                     order by ys.yr_qty desc
                         fetch first row only) top_ys
where bp.brewery_id = 518
order by bp.product_id;

-- Listing 1-8. Outer join with the lateral keyword

select bp.brewery_name
     , bp.product_id as p_id
     , bp.product_name
     , top_ys.yr
     , top_ys.yr_qty
from brewery_products bp
         left outer join lateral (
    select ys.yr
         , ys.yr_qty
    from yearly_sales ys
    where ys.product_id = bp.product_id
    order by ys.yr_qty desc
        fetch first row only
    ) top_ys
                         on top_ys.yr_qty < 500
where bp.brewery_id = 518
order by bp.product_id;

/* ***************************************************** */
