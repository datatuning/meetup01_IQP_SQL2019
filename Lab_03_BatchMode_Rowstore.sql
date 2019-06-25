-- 
-- Batch Mode on Row Store
-- @datatuning
-- https://blog.datatuning.com.br/
-- 

use master
go

create database TesteBatchMode

use TesteBatchMode
go

create table dbo.Vendas (
	idVenda		int identity(1,1) primary key
,	DtVenda		date
,	VlrTotal	numeric(12,2)
,	VlrFrete	numeric(12,2)
)
go

begin tran
insert into dbo.Vendas
values ( getdate() - (rand() * 1233), rand() * 891829, rand() * 891)
go 250000
commit

exec sp_spaceused 'Vendas'

--> SQL 2017
ALTER DATABASE [TesteBatchMode] SET COMPATIBILITY_LEVEL = 140

-- Limpando o cache (CUIDADO!!! NAO FACA ISSO EM PRODUCAO)
CHECKPOINT; 
DBCC DROPCLEANBUFFERS(); 
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

set statistics io, time on

select
	DtVenda
,	SUM(VlrTotal) as VlrTotal
,	SUM(VlrFrete) as VlrFrete
from dbo.Vendas
group by DtVenda
Order by VlrTotal desc

-- Table 'Vendas'. Scan count 1, logical reads 1102, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--  SQL Server Execution Times:
--    CPU time = 407 ms,  elapsed time = 1033 ms.


--> SQL 2019
ALTER DATABASE [TesteBatchMode] SET COMPATIBILITY_LEVEL = 150

-- Limpando o cache (CUIDADO!!! NAO FACA ISSO EM PRODUCAO)
CHECKPOINT; 
DBCC DROPCLEANBUFFERS(); 
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

set statistics io, time on

select
	DtVenda
,	SUM(VlrTotal) as VlrTotal
,	SUM(VlrFrete) as VlrFrete
from dbo.Vendas
group by DtVenda
Order by VlrTotal desc

-- Table 'Vendas'. Scan count 1, logical reads 1102, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
--  SQL Server Execution Times:
--    CPU time = 265 ms,  elapsed time = 665 ms.

-- Percebam o mesmo numero de logical reads, mas foram gastos menos recursos de CPU.

-- Exemplo do ColumStore
create nonclustered columnstore index ci_vendas on dbo.Vendas (DtVenda, VlrTotal, VlrFrete)

select
	DtVenda
,	SUM(VlrTotal) as VlrTotal
,	SUM(VlrFrete) as VlrFrete
from dbo.Vendas
group by DtVenda
Order by VlrTotal desc

-- Table 'Vendas'. Scan count 2, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 295, lob physical reads 0, lob read-ahead reads 0.
-- Table 'Vendas'. Segment reads 1, segment skipped 0.
-- CPU time = 31 ms,  elapsed time = 493 ms.

-- Agora sim, menos leituras e menor tempo de execucao.

drop index dbo.Vendas.ci_vendas

--========= COMO ATIVAR \ DESATIVAR?

-- Database Scope
ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_ON_ROWSTORE = OFF;
ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_ON_ROWSTORE = ON; -- Default


select
	DtVenda
,	SUM(VlrTotal) as VlrTotal
,	SUM(VlrFrete) as VlrFrete
from dbo.Vendas
group by DtVenda
Order by VlrTotal desc
OPTION(USE HINT('DISALLOW_BATCH_MODE'));


-- OBS: Nao eh possivel forcar um batch mode on rowstore.
-- Eh possivel apenas usar um HINT pra habilitar a opcao do Optimizer escolher usar o batch mode on rowstore
select top 10000 *
from dbo.Vendas
Order by VlrTotal desc
OPTION(USE HINT('ALLOW_BATCH_MODE'));


