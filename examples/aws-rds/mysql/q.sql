SELECT t1.col, t3.col FROM table1 join table2 ON table1.primarykey = table2.foreignkey
                                  join table3 ON table2.primarykey = table3.foreignkey


select customers.customerName,products.productName 
from customers 
join orders on customers.customerNumber = orders.customerNumber
join orderdetails on  orders.orderNumber = orderdetails.orderNumber
join products on orderdetails.productCode = products.productCode;


/* Inner join */
SELECT 
    productCode, 
    productName, 
    textDescription
FROM
    products t1
INNER JOIN productlines t2 
    ON t1.productline = t2.productline;                                  