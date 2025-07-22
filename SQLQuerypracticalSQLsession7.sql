-- 1.1 List all employees hired after January 1, 2012
SELECT p.BusinessEntityID, FirstName, LastName, HireDate
FROM HumanResources.Employee e
JOIN Person.Person p ON e.BusinessEntityID = p.BusinessEntityID
WHERE HireDate > '2012-01-01'
ORDER BY HireDate DESC;

-- 1.2 List products with list price between $100 and $500
SELECT ProductID, Name, ListPrice, ProductNumber
FROM Production.Product
WHERE ListPrice BETWEEN 100 AND 500
ORDER BY ListPrice ASC;

-- 1.3 List customers from 'Seattle' or 'Portland'
SELECT c.CustomerID,p.FirstName,p.LastName,a.City
FROM Sales.Customer c
JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
JOIN Person.Address a ON p.BusinessEntityID = a.AddressID
WHERE a.City IN ('Seattle', 'Portland');

-- 1.4 Top 15 most expensive products currently being sold
SELECT TOP 15 p.Name, p.ListPrice, p.ProductNumber, pc.Name AS CategoryName
FROM Production.Product p
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
WHERE p.SellEndDate IS NULL
ORDER BY p.ListPrice DESC;

-- 2.1 Products with name containing 'Mountain' and color 'Black'
SELECT ProductID, Name, Color, ListPrice
FROM Production.Product
WHERE Name LIKE '%Mountain%' AND Color = 'Black';

-- 2.2 Employees born between Jan 1, 1970 and Dec 31, 1985
SELECT FirstName + ' ' + LastName AS FullName, BirthDate,
       DATEDIFF(YEAR, BirthDate, GETDATE()) AS Age
FROM HumanResources.Employee e
JOIN Person.Person p ON e.BusinessEntityID = p.BusinessEntityID
WHERE BirthDate BETWEEN '1970-01-01' AND '1985-12-31';

-- 2.3 Orders in Q4 2013
SELECT SalesOrderID, OrderDate, CustomerID, TotalDue
FROM Sales.SalesOrderHeader
WHERE YEAR(OrderDate) = 2013 AND MONTH(OrderDate) IN (10, 11, 12);

-- 2.4 Products with null weight but non-null size
SELECT ProductID, Name, Weight, Size, ProductNumber
FROM Production.Product
WHERE Weight IS NULL AND Size IS NOT NULL;

-- 3.1 Count the number of products by category
SELECT pc.Name AS CategoryName, COUNT(*) AS ProductCount
FROM Production.Product p
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.Name
ORDER BY ProductCount DESC;

-- 3.2 Average list price by subcategory with more than 5 products
SELECT ps.Name AS SubcategoryName, AVG(p.ListPrice) AS AvgPrice
FROM Production.Product p
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
GROUP BY ps.Name
HAVING COUNT(*) > 5;

-- 3.3 Top 10 customers by total order count
SELECT TOP 10 c.CustomerID, p.FirstName + ' ' + p.LastName AS CustomerName, COUNT(*) AS OrderCount
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
GROUP BY c.CustomerID, p.FirstName, p.LastName
ORDER BY OrderCount DESC;

-- 3.4 Monthly sales totals for 2013
SELECT DATENAME(MONTH, OrderDate) AS MonthName, SUM(TotalDue) AS TotalSales
FROM Sales.SalesOrderHeader
WHERE YEAR(OrderDate) = 2013
GROUP BY DATENAME(MONTH, OrderDate), MONTH(OrderDate)
ORDER BY MONTH(OrderDate);

-- 4.1 Products launched in same year as 'Mountain-100 Black, 42'
SELECT ProductID, Name, SellStartDate, YEAR(SellStartDate) AS LaunchYear
FROM Production.Product
WHERE YEAR(SellStartDate) = (
    SELECT YEAR(SellStartDate)
    FROM Production.Product
    WHERE Name = 'Mountain-100 Black, 42'
);

-- 4.2 Employees hired on same date as someone else
SELECT p.FirstName + ' ' + p.LastName AS EmployeeName, e.HireDate, COUNT(*) OVER (PARTITION BY e.HireDate) AS HiresOnSameDate
FROM HumanResources.Employee e
JOIN Person.Person p ON e.BusinessEntityID = p.BusinessEntityID
WHERE e.HireDate IN (
    SELECT HireDate FROM HumanResources.Employee
    GROUP BY HireDate
    HAVING COUNT(*) > 1
);

-- 5.1 Products with 'Road' in the name and more than 100 units sold
SELECT p.Name, SUM(oi.OrderQty) AS TotalSold
FROM Sales.SalesOrderDetail oi
JOIN Production.Product p ON oi.ProductID = p.ProductID
WHERE p.Name LIKE '%Road%'
GROUP BY p.Name
HAVING SUM(oi.OrderQty) > 100;

-- 5.2 Products with highest total sales per subcategory
WITH ProductSales AS (
    SELECT p.ProductID, p.Name, ps.ProductSubcategoryID, SUM(soh.TotalDue) AS TotalSales
    FROM Sales.SalesOrderDetail sod
    JOIN Production.Product p ON sod.ProductID = p.ProductID
    JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
    GROUP BY p.ProductID, p.Name, ps.ProductSubcategoryID
)
SELECT ps1.Name AS Subcategory, ps2.Name AS Product, TotalSales
FROM (
    SELECT *, RANK() OVER (PARTITION BY ProductSubcategoryID ORDER BY TotalSales DESC) AS rnk
    FROM ProductSales
) ps
JOIN Production.ProductSubcategory ps1 ON ps.ProductSubcategoryID = ps1.ProductSubcategoryID
JOIN Production.Product ps2 ON ps.ProductID = ps2.ProductID
WHERE rnk = 1;

-- 6.1 Create a scalar function that returns the full name of a person
CREATE FUNCTION dbo.GetFullName(@BusinessEntityID INT)
RETURNS NVARCHAR(200)
AS
BEGIN
    DECLARE @FullName NVARCHAR(200);
    SELECT @FullName = FirstName + ' ' + LastName
    FROM Person.Person
    WHERE BusinessEntityID = @BusinessEntityID;
    RETURN @FullName;
END;

-- 6.2 Use the scalar function to list customer full names
SELECT c.CustomerID, dbo.GetFullName(p.BusinessEntityID) AS FullName
FROM Sales.Customer c
JOIN Person.Person p ON c.PersonID = p.BusinessEntityID;

-- 7.1 Create an inline table-valued function returning products by subcategory
CREATE FUNCTION dbo.fnGetProductsBySubcategory(@SubcategoryID INT)
RETURNS TABLE
AS
RETURN (
    SELECT ProductID, Name, ListPrice
    FROM Production.Product
    WHERE ProductSubcategoryID = @SubcategoryID
);

-- 7.2 Use the TVF to list products of a specific subcategory
SELECT * FROM dbo.fnGetProductsBySubcategory(1);

-- 8.1 Create a stored procedure to get order details for a customer
CREATE PROCEDURE dbo.GetCustomerOrders
    @CustomerID INT
AS
BEGIN
    SELECT SalesOrderID, OrderDate, TotalDue
    FROM Sales.SalesOrderHeader
    WHERE CustomerID = @CustomerID;
END;

-- 8.2 Execute the stored procedure
EXEC dbo.GetCustomerOrders @CustomerID = 30105;

-- 8.3 Alter the procedure to include order items
ALTER PROCEDURE dbo.GetCustomerOrders
    @CustomerID INT
AS
BEGIN
    SELECT h.SalesOrderID, h.OrderDate, h.TotalDue, d.ProductID, d.OrderQty, d.UnitPrice
    FROM Sales.SalesOrderHeader h
    JOIN Sales.SalesOrderDetail d ON h.SalesOrderID = d.SalesOrderID
    WHERE h.CustomerID = @CustomerID;
END;

-- 9.1 Show category-wise product counts including total using ROLLUP
SELECT pc.Name AS CategoryName, COUNT(p.ProductID) AS ProductCount
FROM Production.Product p
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
GROUP BY ROLLUP(pc.Name);

-- 9.2 Average price and total sales grouped by category and subcategory
SELECT pc.Name AS CategoryName, ps.Name AS SubcategoryName,
       AVG(p.ListPrice) AS AvgPrice, SUM(soh.TotalDue) AS TotalSales
FROM Production.Product p
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
JOIN Sales.SalesOrderDetail sod ON p.ProductID = sod.ProductID
JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
GROUP BY pc.Name, ps.Name
ORDER BY pc.Name, ps.Name;

-- 10.1 INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL JOIN example
-- Find all orders and their products
SELECT o.SalesOrderID, p.Name AS ProductName
FROM Sales.SalesOrderDetail o
INNER JOIN Production.Product p ON o.ProductID = p.ProductID;

-- 10.2 List all employees and their managers using self join
SELECT e1.BusinessEntityID AS EmployeeID, p1.FirstName + ' ' + p1.LastName AS EmployeeName,
       p2.FirstName + ' ' + p2.LastName AS ManagerName
FROM HumanResources.Employee e1
LEFT JOIN HumanResources.Employee e2 ON e1.ManagerID = e2.BusinessEntityID
LEFT JOIN Person.Person p1 ON e1.BusinessEntityID = p1.BusinessEntityID
LEFT JOIN Person.Person p2 ON e2.BusinessEntityID = p2.BusinessEntityID;

-- 11.1 UNION example: all cities from customers and vendors
SELECT a.City FROM Person.Address a
JOIN Sales.CustomerAddress ca ON a.AddressID = ca.AddressID
UNION
SELECT a.City FROM Person.Address a
JOIN Purchasing.VendorAddress va ON a.AddressID = va.AddressID;

-- 11.2 INTERSECT example: cities shared by customers and vendors
SELECT a.City FROM Person.Address a
JOIN Sales.CustomerAddress ca ON a.AddressID = ca.AddressID
INTERSECT
SELECT a.City FROM Person.Address a
JOIN Purchasing.VendorAddress va ON a.AddressID = va.AddressID;

-- 11.3 EXCEPT example: customer cities not vendor cities
SELECT a.City FROM Person.Address a
JOIN Sales.CustomerAddress ca ON a.AddressID = ca.AddressID
EXCEPT
SELECT a.City FROM Person.Address a
JOIN Purchasing.VendorAddress va ON a.AddressID = va.AddressID;

-- 12.1 Create a view of top 10 products by total sales
CREATE VIEW vTop10Products AS
SELECT TOP 10 p.Name, SUM(soh.TotalDue) AS TotalSales
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
GROUP BY p.Name
ORDER BY TotalSales DESC;

-- 12.2 Query the view
SELECT * FROM vTop10Products;

-- 12.3 Alter the view to include ProductID
ALTER VIEW vTop10Products AS
SELECT TOP 10 p.ProductID, p.Name, SUM(soh.TotalDue) AS TotalSales
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
GROUP BY p.ProductID, p.Name
ORDER BY TotalSales DESC;

-- 13.1 Use RANK() to rank products by price in each subcategory
SELECT Name, ProductSubcategoryID, ListPrice,
       RANK() OVER (PARTITION BY ProductSubcategoryID ORDER BY ListPrice DESC) AS PriceRank
FROM Production.Product;

-- 13.2 Use NTILE(4) to divide products into price quartiles
SELECT Name, ListPrice, NTILE(4) OVER (ORDER BY ListPrice) AS PriceQuartile
FROM Production.Product
WHERE ListPrice > 0;

-- 14.1 Use LAG/LEAD to compare employee hire dates
SELECT BusinessEntityID, HireDate,
       LAG(HireDate) OVER (ORDER BY HireDate) AS PreviousHire,
       LEAD(HireDate) OVER (ORDER BY HireDate) AS NextHire
FROM HumanResources.Employee;

-- 14.2 Running totals using SUM OVER
SELECT SalesOrderID, OrderDate, TotalDue,
       SUM(TotalDue) OVER (ORDER BY OrderDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal
FROM Sales.SalesOrderHeader;

-- 15.1 CTE to list employees and their hire year
WITH EmpCTE AS (
    SELECT e.BusinessEntityID, p.FirstName, p.LastName, YEAR(HireDate) AS HireYear
    FROM HumanResources.Employee e
    JOIN Person.Person p ON e.BusinessEntityID = p.BusinessEntityID
)
SELECT * FROM EmpCTE WHERE HireYear > 2010;

-- 15.2 Recursive CTE to list product categories and subcategories
WITH CategoryCTE AS (
    SELECT ProductCategoryID, Name, NULL AS ParentCategory
    FROM Production.ProductCategory
    UNION ALL
    SELECT ps.ProductSubcategoryID, ps.Name, ps.ProductCategoryID
    FROM Production.ProductSubcategory ps
    JOIN CategoryCTE c ON ps.ProductCategoryID = c.ProductCategoryID
)
SELECT * FROM CategoryCTE;

-- 16.1 Moving average of TotalDue
SELECT SalesOrderID, OrderDate, TotalDue,
       AVG(TotalDue) OVER (ORDER BY OrderDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MovingAvg
FROM Sales.SalesOrderHeader;

-- 16.2 Year over year sales difference
SELECT YEAR(OrderDate) AS SalesYear, SUM(TotalDue) AS TotalSales,
       LAG(SUM(TotalDue)) OVER (ORDER BY YEAR(OrderDate)) AS PrevYearSales
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate);

-- 17.1 Create a non-clustered index on LastName column of Person table
CREATE NONCLUSTERED INDEX IX_Person_LastName
ON Person.Person (LastName);

-- 17.2 Find execution plan for a query on Product table
-- (This is done via SSMS: Use Actual Execution Plan or Estimated Execution Plan option)
SELECT * FROM Production.Product WHERE ProductID = 999;

-- 18.1 Create a trigger to prevent delete from Product table
CREATE TRIGGER trg_PreventProductDelete
ON Production.Product
INSTEAD OF DELETE
AS
BEGIN
    PRINT 'Delete operation is not allowed on Product table.'
END;

-- 18.2 Create a trigger to log employee insertions
CREATE TABLE Audit_EmployeeInsert (
    EmployeeID INT,
    InsertDate DATETIME DEFAULT GETDATE()
);

CREATE TRIGGER trg_LogEmployeeInsert
ON HumanResources.Employee
AFTER INSERT
AS
BEGIN
    INSERT INTO Audit_EmployeeInsert (EmployeeID)
    SELECT BusinessEntityID FROM inserted;
END;

-- 19.1 Grant SELECT on Product to a specific user
GRANT SELECT ON Production.Product TO [YourUsername];

-- 19.2 Revoke DELETE on Customer table from a user
REVOKE DELETE ON Sales.Customer FROM [YourUsername];

-- 20.1 Use EXISTS to check customers with orders
SELECT c.CustomerID, p.FirstName + ' ' + p.LastName AS CustomerName
FROM Sales.Customer c
JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
WHERE EXISTS (
    SELECT 1 FROM Sales.SalesOrderHeader soh WHERE soh.CustomerID = c.CustomerID
);

-- 20.2 Use NOT EXISTS to find customers without orders
SELECT c.CustomerID, p.FirstName + ' ' + p.LastName AS CustomerName
FROM Sales.Customer c
JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
WHERE NOT EXISTS (
    SELECT 1 FROM Sales.SalesOrderHeader soh WHERE soh.CustomerID = c.CustomerID
);


-- 21.1 Create a stored procedure to list products by category
CREATE PROCEDURE usp_GetProductsByCategory
    @CategoryName NVARCHAR(50)
AS
BEGIN
    SELECT p.Name, p.ListPrice, pc.Name AS CategoryName
    FROM Production.Product p
    JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
    WHERE pc.Name = @CategoryName;
END;

-- 21.2 Execute the stored procedure
EXEC usp_GetProductsByCategory @CategoryName = 'Bikes';

-- 22.1 Create a scalar function to calculate discount price
CREATE FUNCTION dbo.fn_DiscountPrice (@Price DECIMAL(10,2), @DiscountPercent DECIMAL(5,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @Price - (@Price * @DiscountPercent / 100);
END;

-- 22.2 Use the function
SELECT Name, ListPrice,
       dbo.fn_DiscountPrice(ListPrice, 10) AS DiscountedPrice
FROM Production.Product;

-- 23.1 Use a transaction to transfer stock between locations
BEGIN TRANSACTION;

UPDATE Production.ProductInventory
SET Quantity = Quantity - 10
WHERE ProductID = 707 AND LocationID = 1;

UPDATE Production.ProductInventory
SET Quantity = Quantity + 10
WHERE ProductID = 707 AND LocationID = 6;

COMMIT TRANSACTION;

-- 23.2 Use ROLLBACK for invalid quantity
BEGIN TRANSACTION;

UPDATE Production.ProductInventory
SET Quantity = Quantity - 9999
WHERE ProductID = 707 AND LocationID = 1;

-- Check condition and rollback
IF (SELECT Quantity FROM Production.ProductInventory WHERE ProductID = 707 AND LocationID = 1) < 0
    ROLLBACK TRANSACTION;
ELSE
    COMMIT TRANSACTION;

-- 24.1 TRY...CATCH block example
BEGIN TRY
    -- Divide by zero error example
    SELECT 1 / 0;
END TRY
BEGIN CATCH
    PRINT 'An error occurred: ' + ERROR_MESSAGE();
END CATCH;

-- 24.2 Error handling in transaction
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE Production.ProductInventory
    SET Quantity = Quantity - 10000
    WHERE ProductID = 707 AND LocationID = 1;

    IF (SELECT Quantity FROM Production.ProductInventory WHERE ProductID = 707 AND LocationID = 1) < 0
        THROW 50001, 'Insufficient stock.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH;

)


-- Session 25: Views

-- 25.1 Create a view showing products with their category and subcategory
CREATE VIEW vw_ProductDetails AS
SELECT p.ProductID, p.Name AS ProductName, pc.Name AS Category, ps.Name AS Subcategory, p.ListPrice
FROM Production.Product p
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID;

-- 25.2 Query the view to list products under 'Bikes' category
SELECT *
FROM vw_ProductDetails
WHERE Category = 'Bikes';


-- 26: Advanced Analytics:

-- 26.1 Rank products by ListPrice within each subcategory
SELECT ProductID, Name, ProductNumber, ListPrice, 
       RANK() OVER(PARTITION BY ProductSubcategoryID ORDER BY ListPrice DESC) AS PriceRank
FROM Production.Product;

-- 26.2 Use PIVOT to show total sales by territory in columns
SELECT *
FROM (
    SELECT TerritoryID, YEAR(OrderDate) AS OrderYear, TotalDue
    FROM Sales.SalesOrderHeader
    WHERE YEAR(OrderDate) = 2013
) AS SourceTable
PIVOT (
    SUM(TotalDue) FOR TerritoryID IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10])
) AS PivotTable;
