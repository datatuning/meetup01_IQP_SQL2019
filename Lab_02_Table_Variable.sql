-- 
-- Table Variable Deferred Compilation
-- @datatuning
-- https://blog.datatuning.com.br/
-- 

use master;
GO

/* CONSIDERANDO O COMPATIBILITY DO SQL SERVER 2017 */
ALTER DATABASE [AdventureWorks] SET COMPATIBILITY_LEVEL = 140
GO

-- Indice utilizado para o exemplo
--USE [AdventureWorks]
--GO
--CREATE NONCLUSTERED INDEX [IX_SalesOrderDetail_OrderQty]
--ON [Sales].[SalesOrderDetail] ([OrderQty])

USE [AdventureWorks]
GO

-- Limpando o cache (CUIDADO!!! NAO FACA ISSO EM PRODUCAO)
CHECKPOINT; 
DBCC DROPCLEANBUFFERS(); 
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

set statistics io, time on


declare @TempIDs as table (SalesOrderId int)

insert into @TempIDs
select SalesOrderID
from Sales.SalesOrderDetail
where OrderQty > 40
-- 2 rows

select oh.SalesOrderID, OrderDate, PurchaseOrderNumber, AccountNumber, SubTotal
from Sales.SalesOrderHeader oh
inner join @TempIDs t on oh.SalesOrderID = t.SalesOrderId

-- Table 'SalesOrderDetail'. Scan count 1, logical reads 2, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
-- Table 'SalesOrderHeader'. Scan count 0, logical reads 6, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

-- Confira o Estimated Number Rows vs Actual Number Rows
-- Retorno bem rapido!!! Pronto, finalizei meus testes. Sera?
-- Vamos testar com outro parametro agora (menos restritivo)
go

declare @TempIDs as table (SalesOrderId int)

insert into @TempIDs
select SalesOrderID
from Sales.SalesOrderDetail
where OrderQty > 5 ---> Ops, filtrou muito, agora quero todos maior que 5
-- 10225 rows

select oh.SalesOrderID, OrderDate, PurchaseOrderNumber, AccountNumber, SubTotal
from Sales.SalesOrderHeader oh
inner join @TempIDs t on oh.SalesOrderID = t.SalesOrderId

-- Table 'SalesOrderDetail'. Scan count 1, logical reads 24, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
-- Table 'SalesOrderHeader'. Scan count 0, logical reads 30675, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

-- Quando se usa Table Variables, o Estimated Number Rows que o SQL espera � sempre 1.
-- Maaaas no SQL Server 2019...

use master;
GO

/* CONSIDERANDO O COMPATIBILITY DO SQL SERVER 2019 */
ALTER DATABASE [AdventureWorks] SET COMPATIBILITY_LEVEL = 150
GO

use [AdventureWorks]
go

-- Limpando o cache (CUIDADO!!! NAO FACA ISSO EM PRODUCAO)
CHECKPOINT; 
DBCC DROPCLEANBUFFERS(); 
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

declare @TempIDs as table (SalesOrderId int)

insert into @TempIDs
select SalesOrderID
from Sales.SalesOrderDetail
where OrderQty > 5 ---> Ops, filtrou muito, agora quero todos maior que 5
-- 10225 rows

select oh.SalesOrderID, OrderDate, PurchaseOrderNumber, AccountNumber, SubTotal
from Sales.SalesOrderHeader oh
inner join @TempIDs t on oh.SalesOrderID = t.SalesOrderId

--Table 'SalesOrderDetail'. Scan count 1, logical reads 24, physical reads 1, read-ahead reads 29, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--Table 'SalesOrderHeader'. Scan count 1, logical reads 689, physical reads 3, read-ahead reads 685, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

-- Reduziu o numero de leituras na SalesOrderHeader de 30675 para 689. 
-- Obs: sem alterar a consulta!


--========= COMO ATIVAR \ DESATIVAR?

-- Database Scope
ALTER DATABASE SCOPED CONFIGURATION SET DEFERRED_COMPILATION_TV = OFF;
ALTER DATABASE SCOPED CONFIGURATION SET DEFERRED_COMPILATION_TV = ON; -- Default

-- Query Scope -> OPTION (USE HINT('DISABLE_DEFERRED_COMPILATION_TV'));
use [AdventureWorks]
go

-- Limpando o cache (CUIDADO!!! NAO FACA ISSO EM PRODUCAO)
CHECKPOINT; 
DBCC DROPCLEANBUFFERS(); 
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

declare @TempIDs as table (SalesOrderId int)

insert into @TempIDs
select SalesOrderID
from Sales.SalesOrderDetail
where OrderQty > 5 ---> Ops, filtrou muito, agora quero todos maior que 5
-- 10225 rows

select oh.SalesOrderID, OrderDate, PurchaseOrderNumber, AccountNumber, SubTotal
from Sales.SalesOrderHeader oh
inner join @TempIDs t on oh.SalesOrderID = t.SalesOrderId
OPTION (USE HINT('DISABLE_DEFERRED_COMPILATION_TV'))
