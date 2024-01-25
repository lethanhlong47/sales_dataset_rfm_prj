Select * From public.sales_dataset_rfm_prj

--1. Chuyển đổi kiểu dữ liệu phù hợp cho các trường ( sử dụng câu lệnh ALTER) 
  
alter table public.sales_dataset_rfm_prj
alter column priceeach type float using priceeach::float,
alter column sales type float using sales::float,
alter column orderdate type date using orderdate::date,
ALTER COLUMN quantityordered type INT
USING quantityordered::INT,
ALTER COLUMN orderlinenumber type INT
USING orderlinenumber::INT,
ALTER COLUMN msrp type float
USING msrp::float;
-----
--2.Check NULL/BLANK (‘’)  ở các trường: ORDERNUMBER, QUANTITYORDERED, PRICEEACH, ORDERLINENUMBER, SALES, ORDERDATE.

Select * From sales_dataset_rfm_prj
Where QUANTITYORDERED is null
Or ORDERNUMBER is null
or PRICEEACH is null
Or ORDERLINENUMBER is null
Or SALES is null
Or ORDERDATE is null

/*3.Thêm cột CONTACTLASTNAME, CONTACTFIRSTNAME được tách ra từ CONTACTFULLNAME . 
Chuẩn hóa CONTACTLASTNAME, CONTACTFIRSTNAME theo định dạng chữ cái đầu tiên viết hoa, chữ cái tiếp theo viết thường. 
Gợi ý: ( ADD column sau đó INSERT)*/
  
Alter table sales_dataset_rfm_prj
add column CONTACTFIRSTNAME character varying(100),
add column CONTACTLASTNAME character varying(100);

update sales_dataset_rfm_prj
Set 
	CONTACTLASTNAME = (Left(contactfullname,position('-' IN contactfullname)-1) ),
	CONTACTFIRSTNAME = (RIGHT(contactfullname,length(contactfullname) - position('-' IN contactfullname)) )
	
UPDATE SALES_DATASET_RFM_PRJ
SET contactlastname = UPPER(LEFT(contactlastname, 1)) || RIGHT(contactlastname, LENgth(contactlastname) - 1),
    contactfirstname = UPPER(LEFT(contactfirstname, 1)) || RIGHT(contactfirstname, LENgth(contactfirstname) - 1);

--4.Thêm cột QTR_ID, MONTH_ID, YEAR_ID lần lượt là Qúy, tháng, năm được lấy ra từ ORDERDATE 
ALTER TABLE SALES_DATASET_RFM_PRJ
ADD COLUMN qtrid INT,
ADD COLUMN monthid INT,
ADD COLUMN yearid INT;

UPDATE SALES_DATASET_RFM_PRJ
SET qtrid = EXTRACT('quarter' FROM ORDERDATE),
  monthid = EXTRACT('month' FROM ORDERDATE),
  yearid = EXTRACT('year' FROM ORDERDATE);

--5.Hãy tìm outlier (nếu có) cho cột QUANTITYORDERED và hãy chọn cách xử lý cho bản ghi đó (2 cách) ( Không chạy câu lệnh trước khi bài được review)
-- box plot: min = Q1 -IQR*1,5: Max = Q3+IQR*1.5
with cte_iqr  as (
Select 
	Q1 - IQR*1,5 as min_v,
	Q3 + IQR*1.5 as max_v
From(
Select 
 percentile_cont(0.25) within group(order by quantityordered) as Q1,
 percentile_cont(0.75) within group(order by quantityordered) as Q3,
 percentile_cont(0.75) within group(order by quantityordered) - percentile_cont(0.25) within group(order by quantityordered) as IQR
From SALES_DATASET_RFM_PRJ) as ab)
Select * From SALES_DATASET_RFM_PRJ 
Where quantityordered > (select max_v from cte_iqr)
Or quantityordered < (select min_v from cte_iqr)
--z-score = (quantityordered - avg)/STDDEV
With CTE_ZSCORE as (
Select
	quantityordered,
	(SELECT
  	AVG(quantityordered) 
	FROM SALES_DATASET_RFM_PRJ) AS avg_quantityordered,
	(SELECT
  	STDDEV(quantityordered) 
	FROM SALES_DATASET_RFM_PRJ) AS std_quantityordered
FROM SALES_DATASET_RFM_PRJ
)
,twt_outlier as (
Select 
	quantityordered,
	(quantityordered - avg_quantityordered)/std_quantityordered as z_score
From CTE_ZSCORE
Where abs((quantityordered - avg_quantityordered)/std_quantityordered) >3
Or abs((quantityordered - avg_quantityordered)/std_quantityordered) <-3
)
---Xử lí outlier
--c1
update SALES_DATASET_RFM_PRJ
Set quantityordered = (SELECT AVG(quantityordered) FROM SALES_DATASET_RFM_PRJ)
Where quantityordered in (select quantityordered from twt_outlier)
					   
--c2
Delete From SALES_DATASET_RFM_PRJ
Where quantityordered in (select * from twt_outlier)


--6.Sau khi làm sạch dữ liệu, hãy lưu vào bảng mới  tên là SALES_DATASET_RFM_PRJ_CLEAN
Create table SALES_DATASET_RFM_PRJ_CLEAN as
(
	Select 
		ordernumber,
  		quantityordered,
  		priceeach,
  		orderlinenumber,
  		sales,
  		orderdate,
  		status,
  		productline,
  		msrp,
  		productcode,
  		customername,
  		phone,
  		addressline1,
  		addressline2,
  		city,
  		state,
  		postalcode,
  		country,
  		territory,
  		contactfullname,
  		dealsize    
	From SALES_DATASET_RFM_PRJ
)
