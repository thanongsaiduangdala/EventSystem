
use reservation_system;
select * from customer_info;

DROP DATABASE IF EXISTS reservation_system;
CREATE DATABASE reservation_system;

select * from point_info;
select * from registered_customer_info;
select * from table_info;

ALTER TABLE customer_info 
MODIFY COLUMN CustomerPhoneNum VARCHAR(20);

ALTER TABLE customer_info ADD COLUMN StatusID INT DEFAULT 1;

SELECT * FROM tbunit;

SELECT * FROM statusinfo;

use schoolwork;

SELECT * FROM tbcategory;

use schoolwork;
ALTER TABLE tbsuplier DROP COLUMN tbsupliercol1;

DESCRIBE tbsuplier;