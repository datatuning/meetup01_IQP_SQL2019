-- 
-- ROW MODE MEMORY GRANT FEEDBACK
-- @datatuning
-- https://blog.datatuning.com.br/
-- 

use master;
GO

/* CONSIDERANDO O COMPATIBILITY DO SQL SERVER 2017 */
ALTER DATABASE [AdventureWorks] SET COMPATIBILITY_LEVEL = 140
GO

use [AdventureWorks]
go

-- Limpando o cache (CUIDADO!!! NAO FACA ISSO EM PRODUCAO)
CHECKPOINT; 
DBCC DROPCLEANBUFFERS(); 
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

select * 
from Sales.SalesOrderDetail
where UnitPrice between 100 and 110
order by LineTotal

-- Verificar o MemoryGrant definido pra consulta -> 1 MB

select * 
from Sales.SalesOrderDetail
where UnitPrice between 100 and 12600
order by LineTotal

-- Rodar mais uma vez pra evidenciar a utilizacao do tempdb para o sort
-- Ou seja, mesmo evidenciando a falta de Memoria para a consulta, nao foi alterado o MemoryGrant


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


select * 
from Sales.SalesOrderDetail
where UnitPrice between 100 and 110
order by LineTotal

-- Verificar o MemoryGrant definido pra consulta -> 1 MB

select * 
from Sales.SalesOrderDetail
where UnitPrice between 100 and 12500
order by LineTotal

-- Como se comportou agora? Continua utilizando o tempdb?

select * 
from Sales.SalesOrderDetail
where UnitPrice between 100 and 110
order by LineTotal

-- No plano de execucao, em Propertis, analisar MemoryGrantInfo

/*
IsMemoryGrantFeedbackAdjusted Value	Description
No:		FirstExecution		Memory grant feedback does not adjust memory for the first compile and associated execution.
No:		Accurate Grant		If there is no spill to disk and the statement uses at least 50% of the granted memory, then memory grant feedback is not triggered.
No:		Feedback disabled	If memory grant feedback is continually triggered and fluctuates between memory-increase and memory-decrease operations, we will disable memory grant feedback for the statement.
Yes:	Adjusting			Memory grant feedback has been applied and may be further adjusted for the next execution.
Yes:	Stable				Memory grant feedback has been applied and granted memory is now stable, meaning that what was last granted for the previous execution is what was granted for the current execution.
*/


-- Perceba que o Memory Grant da query vai alterando conforme caracteristica das execucoes
select 
    ObjName              = isnull(object_name(t.objectid),'Ad-Hoc')
,   Command              = SUBSTRING (t.text, qs.statement_start_offset/2, ( CASE WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), t.text)) * 2 ELSE qs.statement_end_offset END - qs.statement_start_offset ) /2 )
,   DtCreated            = qs.creation_time
,   ExecCount            = qs.execution_count
,   AvgMemoryGrant       = qs.total_grant_kb / qs.execution_count
,   LastMemoryGrant      = qs.last_grant_kb
,   MinMemoryGrant       = qs.min_grant_kb
,   MaxMemoryGrant       = qs.max_grant_kb
,   AvgUsedMemoryGrant   = qs.total_used_grant_kb / qs.execution_count
,   LastUsedMemoryGrant  = qs.last_used_grant_kb
,   MinUsedMemoryGrant   = qs.min_used_grant_kb
,   MaxUsedMemoryGrant   = qs.max_used_grant_kb
,   IdealMemoryGrant     = qs.last_ideal_grant_kb
,   AvgTimeMs            = ( qs.total_elapsed_time / qs.execution_count ) / 1000
,   LastTimeMs           = qs.last_elapsed_time / 1000
,   MinTimeMs            = qs.min_elapsed_time / 1000
,   MaxTimeMs            = qs.max_elapsed_time / 1000
,   AvgLogReads          = qs.total_logical_reads / qs.execution_count
,   LastLogReads         = qs.last_logical_reads
,   MinLogReads          = qs.min_logical_reads
,   MaxLogReads          = qs.max_logical_reads
from
			sys.dm_exec_query_stats qs
outer apply	sys.dm_exec_sql_text(qs.sql_handle) t
where 
		1=1
--and		t.objectid = object_id('dbo.ListSalesReason')
and		t.text like '%where UnitPrice between%'
and     t.text not like '%sys.dm_exec_query_stats%'



--========= COMO ATIVAR \ DESATIVAR?

-- Database Scope
ALTER DATABASE SCOPED CONFIGURATION SET ROW_MODE_MEMORY_GRANT_FEEDBACK = OFF;
ALTER DATABASE SCOPED CONFIGURATION SET ROW_MODE_MEMORY_GRANT_FEEDBACK = ON; -- Default

-- Query Scope -> OPTION (USE HINT ('DISABLE_ROW_MODE_MEMORY_GRANT_FEEDBACK')); 
use [AdventureWorks]
go

-- Limpando o cache (CUIDADO!!! NAO FACA ISSO EM PRODUCAO)
CHECKPOINT; 
DBCC DROPCLEANBUFFERS(); 
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

select * 
from Sales.SalesOrderDetail
where UnitPrice between 100 and 110
order by LineTotal
OPTION (USE HINT ('DISABLE_ROW_MODE_MEMORY_GRANT_FEEDBACK')); 

select * 
from Sales.SalesOrderDetail
where UnitPrice between 100 and 52500
order by LineTotal
OPTION (USE HINT ('DISABLE_ROW_MODE_MEMORY_GRANT_FEEDBACK')); 
