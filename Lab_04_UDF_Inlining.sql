-- 
-- UDF Inlining
-- @datatuning
-- https://blog.datatuning.com.br/
-- 


use AdventureWorks
go

--============== Exemplo de Scalar Function
if object_id('dbo.ScalarFunction_NumeroDias') is not null
	drop function dbo.ScalarFunction_NumeroDias
go
create function dbo.ScalarFunction_NumeroDias (@DataInicio datetime, @DataFim datetime)
returns int
as
begin
	return DATEDIFF(DAY, @DataInicio, @DataFim) + 1
end
go

-- Retorna o numero de dias em 1 ano
select dbo.ScalarFunction_NumeroDias ('2018-01-01','2018-12-31')


--============== Exemplo de Inline Function?
if object_id('dbo.InlineFunction_Months') is not null
	drop function dbo.InlineFunction_Months
go
create function dbo.InlineFunction_Months ()
returns table
as
	return (	with cte_months as (
						select 'January'	as [Month],  1 as [Id] union
						select 'February'	as [Month],  2 as [Id] union
						select 'March'		as [Month],  3 as [Id] union
						select 'April'		as [Month],  4 as [Id] union
						select 'May'		as [Month],  5 as [Id] union
						select 'June'		as [Month],  6 as [Id] union
						select 'July'		as [Month],  7 as [Id] union
						select 'August'		as [Month],  8 as [Id] union
						select 'September'	as [Month],  9 as [Id] union
						select 'October'	as [Month], 10 as [Id] union
						select 'November'	as [Month], 11 as [Id] union
						select 'December'	as [Month], 12 as [Id])
					
					select * from cte_months	 );
go 

-- Retorna Meses de um ano 
select * from dbo.InlineFunction_Months() order by Id


-- Consulta se ela eh elegivel a Inlining
select object_name(object_id) as Name, definition, is_inlineable
from sys.sql_modules where object_name(object_id) = 'ScalarFunction_NumeroDias'

/*
NOTE
If a scalar UDF is inlineable, it does not imply that it will always be inlined. SQL Server will decide
(on a per-query, per-UDF basis) whether to inline a UDF or not. For instance, if the UDF definition runs 
into thousands of lines of code, SQL Server might choose not to inline it. Another example is a UDF in a 
GROUP BY clause - which will not be inlined. This decision is made when the query referencing a scalar 
UDF is compiled.

https://docs.microsoft.com/pt-br/sql/t-sql/statements/create-function-transact-sql?view=sql-server-2017 */

--============== Cria tabela com muitos registros
if OBJECT_ID('dbo.SalesOrderBig') is not null
	drop table dbo.SalesOrderBig
go
create table dbo.SalesOrderBig (
	SalesOrderID	int identity(1,1) primary key
,	CurrencyRateID	int
,	AverageRate		money
,	SubTotal		money
)
go

;with cte_Sales as (
	select
		soh.SalesOrderID	as SalesOrderID
	,	soh.CurrencyRateID	as CurrencyRateID
	,	cr.AverageRate		as AverageRate
	,	soh.SubTotal		as SubTotal
	from Sales.SalesOrderHeader soh
	left join Sales.CurrencyRate cr
	 on soh.CurrencyRateID = cr.CurrencyRateID
)

insert into dbo.SalesOrderBig (CurrencyRateID, AverageRate,	SubTotal)
select	cte1.CurrencyRateID
	,	cte1.AverageRate
	,	cte1.SubTotal * (1+ rand())
from	cte_Sales cte1
go 30



--> SQL 2017
ALTER DATABASE [AdventureWorks] SET COMPATIBILITY_LEVEL = 140

--============== Consulta para retornar valor de venda com cambio
select sum (case
				when CurrencyRateID is null then SubTotal
				else SubTotal / AverageRate 
			end ) as SubTotalDolar
from dbo.SalesOrderBig

-- Porque nao criar um Function para realizar o calculo do cambio??

if object_id('sfSubTotalRate') is not null
	drop function dbo.sfSubTotalRate
go
create function dbo.sfSubTotalRate(@SubTotal money, @AverageRate money)
returns money
as
begin

  return	case
				when @AverageRate is null then @SubTotal
				else @SubTotal / @AverageRate
			end

end
go 

-- Agora sim, codigo ficou bem mais amigavel, nao? rs
select	sum	(dbo.sfSubTotalRate(SubTotal, AverageRate)) as SubTotalDolar
from	dbo.SalesOrderBig

-- E a performance??? Ficou Legal???

--> A function sfSubTotalRate eh Inlineable??
select object_name(object_id) as Name, is_inlineable
from sys.sql_modules where object_name(object_id) = 'sfSubTotalRate'

--> SQL 2019
ALTER DATABASE [AdventureWorks] SET COMPATIBILITY_LEVEL = 150

select	sum	(dbo.sfSubTotalRate(SubTotal, AverageRate)) as SubTotalDolar
from	dbo.SalesOrderBig


--========= COMO ATIVAR \ DESATIVAR?

-- Database Scope
ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = OFF;
ALTER DATABASE SCOPED CONFIGURATION SET TSQL_SCALAR_UDF_INLINING = ON; -- Default

-- Hint
select	sum	(dbo.sfSubTotalRate(SubTotal, AverageRate)) as SubTotalDolar
from	dbo.SalesOrderBig
OPTION (USE HINT('DISABLE_TSQL_SCALAR_UDF_INLINING'));


-- Fica a dica pessoal! Possiveis hints
select * from sys.dm_exec_valid_use_hints


