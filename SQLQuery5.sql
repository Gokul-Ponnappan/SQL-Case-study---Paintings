
-- 1. Fetch all the paintings which are not displayed on any museums?

select *
from [Paintings].[dbo].[work]
where [Paintings].[dbo].[work].museum_id is null;

-- 2. Are there museums without any paintings?

select * from [Paintings].[dbo].[museum]  m
where not exists (select 1 from [Paintings].[dbo].[work]  w
					where m.museum_id=w.museum_id):

-- 3. How many paintings have an asking price of more than their regular price?

select *
from [Paintings].[dbo].[product_size]
where sale_price > regular_price;

--4. Identify the paintings whose asking price is less than 50% of its regular price

select *
from [Paintings].[dbo].[product_size]
where sale_price < regular_price/2;

--5. Which canva size costs the most?

select TOP 1 *
from [Paintings].[dbo].[canvas_size] c join [Paintings].[dbo].[product_size] p on c.size_id = p.size_id
order by sale_price desc;

--6. Delete duplicate records from work, product_size, subject and image_link tables


WITH CTE AS (
    SELECT 
        work_id,
        ROW_NUMBER() OVER (PARTITION BY work_id ORDER BY (SELECT NULL)) AS row_num
    FROM [Paintings].[dbo].[work]
)
DELETE FROM CTE
WHERE row_num > 1;

WITH CTE AS (
    SELECT 
        work_id,
        ROW_NUMBER() OVER (PARTITION BY work_id ORDER BY (SELECT NULL)) AS row_num
    FROM [Paintings].[dbo].[product_size]
)
DELETE FROM CTE
WHERE row_num > 1;

WITH CTE AS (
    SELECT 
        work_id,
        ROW_NUMBER() OVER (PARTITION BY work_id ORDER BY (SELECT NULL)) AS row_num
    FROM [Paintings].[dbo].[subject]
)
DELETE FROM CTE
WHERE row_num > 1;

WITH CTE AS (
    SELECT 
        work_id,
        ROW_NUMBER() OVER (PARTITION BY work_id ORDER BY (SELECT NULL)) AS row_num
    FROM [Paintings].[dbo].[image_link]
)
DELETE FROM CTE
WHERE row_num > 1;


--7. Identify the museums with invalid city information in the given dataset

select *
from [Paintings].[dbo].[museum]
where city is null or city like '%[0-9]%' 

--8. Museum_Hours table has 1 invalid entry. Identify it and remove it.

WITH CTE AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY museum_id, day ORDER BY museum_id) AS RowNum
    FROM [Paintings].[dbo].[museum_hours]
)
DELETE FROM CTE
WHERE RowNum > 1;

--9. Fetch the top 10 most famous painting subject
-- we can use 2 methods using sub query and without subquery 
-- method 1
select * 
	from (
		select s.subject,count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as ranking
		from [Paintings].[dbo].[work] w
		join [Paintings].[dbo].[subject] s on s.work_id=w.work_id
		group by s.subject ) x
	where ranking <= 10;
-- method 2
select top 10 s.subject, count(*) as num_works,
		dense_rank() over(order by count(*) desc) as rn
from [Paintings].[dbo].[work] w join [Paintings].[dbo].[subject] s on w.work_id = s.work_id
group by s.subject
order by num_works desc;

--10. Identify the museums which are open on both Sunday and Monday. Display museum name, city.

select distinct m.name, m.city, m.state, m.country 
from [Paintings].[dbo].[museum_hours] mh inner join [Paintings].[dbo].[museum] m on mh.museum_id = m.museum_id
where exists
		(select 1 from [Paintings].[dbo].[museum_hours] mh2
			where mh2.museum_id = mh.museum_id and mh2.day = 'Sunday')
		and exists 
		(select 1 from [Paintings].[dbo].[museum_hours] mh2 where 
			mh2.museum_id = mh.museum_id and mh2.day = 'Monday')
group by  m.name, m.city, m.state, m.country;

--11. How many museums are open every single day?

with mus_count_cte as(
		select mh.museum_id, count(*) as mus_count
		from [Paintings].[dbo].[museum_hours] mh
		group by mh.museum_id)
select count(*) as total_mus_count
from mus_count_cte
where mus_count = 7;

--12) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)

select Top 5 w.museum_id, m.name, count(*) as total_paints
from [Paintings].[dbo].[museum] m inner join [Paintings].[dbo].[work] w on m.museum_id= w.museum_id
group by w.museum_id, m.name
order by total_paints desc;

--13. Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

select top 5 a.full_name, t1.Total_paints as total_paints
from (select a.artist_id, count(*) as Total_paints
		from [Paintings].[dbo].[work] w inner join [Paintings].[dbo].[dimartist] a on w.artist_id = a.artist_id
		group by a.artist_id) t1 
		join [Paintings].[dbo].[dimartist] a on t1.artist_id = a.artist_id 
order by t1.total_paints desc;

--14. Display the 3 least popular canva sizes

select t1.label, t1.ranking, t1.cs_count
	from (select cs.size_id, cs.label, count(*) as cs_count,
	DENSE_RANK() over(order by count(*)) as ranking
		from [Paintings].[dbo].[work] w inner join  [Paintings].[dbo].[product_size] ps on ps.work_id=w.work_id inner join 
		[Paintings].[dbo].[canvas_size] cs on cs.size_id = ps.size_id 
		group by cs.size_id, cs.label) t1
where t1.ranking <= 3;


--15. Which museum has the most no of most popular painting style?

-- method 1 

select top 1 t1.style, t1.style_count, m.name, m.museum_id
from(select style, count(*) as style_count, museum_id
	from [Paintings].[dbo].[work]
		where museum_id is not null and style is not null
		group by style, museum_id) t1 join [Paintings].[dbo].[museum] m on
		t1.museum_id = m.museum_id
group by t1.style, t1.style_count, m.name, m.museum_id
order by t1.style_count desc;

-- method 2

with pop_style as 
		(select style
		,rank() over(order by count(1) desc) as rnk
		from [Paintings].[dbo].[work]
		group by style),
	cte as
		(select w.museum_id,m.name as museum_name,ps.style, count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as rnk
		from [Paintings].[dbo].[work] w
		join [Paintings].[dbo].[museum] m on m.museum_id=w.museum_id
		join pop_style ps on ps.style = w.style
		where w.museum_id is not null
		and ps.rnk=1
		group by w.museum_id, m.name,ps.style)
select museum_name,style,no_of_paintings
from cte 
where rnk=1;

--16. Identify the artists whose paintings are displayed in multiple museums

select t1.full_name, count(*) as no_museums
from (select a.full_name, a.artist_id, m.museum_id, count(*) as paint_count
from [Paintings].[dbo].[museum] m join [Paintings].[dbo].[work] w on m.museum_id = w.museum_id join 
	[Paintings].[dbo].[dimartist] a on w.artist_id = a.artist_id
group by a.full_name, a.artist_id, m.museum_id having count(a.artist_id) > 1) t1 join [Paintings].[dbo].[museum] m2 on t1.museum_id = m2.museum_id
group by t1.full_name
having count(*) > 2 
order by no_museums desc; 

--17. Identify the artists whose paintings are displayed in multiple countries

with cte as (select Distinct a.full_name as artist, m.country
from [Paintings].[dbo].[work] w join [Paintings].[dbo].[dimartist] a on w.artist_id = a.artist_id 
		join [Paintings].[dbo].[museum] m on w.museum_id = m.museum_id)
	select artist, count(*) as countries
	from cte
	group by artist
	having count(*) >1
	order by countries desc

