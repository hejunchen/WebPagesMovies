

use ACES2fWEB_DEV1;

declare @AsOfDate as date
set @AsOfDate='2014-01-01 00:00:00'
declare @LANGID as integer
set @LANGID=1
;
-- -- The following script is to get the qualified Plan Members only
--select top 500 
--CE.ROCID, CE.USERID, CE.RELCAT, CE.LANGUAGEID, CE.ISWASENABLED, CE.CERTEFFDT, P.GENWEBACCT, RC.DELIVERYTYPE, RC.CORRTYPE, RC.CORRNUM,
--CE.POLICYSTATUS, CE.CERTSTATUS, CE.CERTNUM, CE.CERTRESSTATUS, CE.COVLSTATUS, CE.COVLRESSTATUS, CE.ISNEXUS, CE.ISFLEX,
--UP.[STATUS], WU.SENTWELCOMEPKGDTTM,
----CE.*,
--NEWID() as 'GUID'
--from VW_WEBMEMBERCERTIFICATE CE
--inner join G00POLICY P on CE.POLICYID = P.POLICYID
--inner join R00ROCCONTACTINFO RC on CE.ROCID = RC.ROCID
--left join S00USERPROFILE UP on CE.USERID = UP.USERID
--left join S00WEBUSER WU ON WU.USERID = CE.USERID
--where 
--(CE.LANGUAGEID = @LANGID and CE.ISWASENABLED = 1 and CE.CERTEFFDT <= @AsOfDate) and 
--(P.GENWEBACCT = 1) and 
--(RC.DELIVERYTYPE = 4 and RC.CORRTYPE = 7 and (RC.CORRNUM is not null and RC.CORRNUM <> '')) and 
--(CE.POLICYSTATUS not in (1,4) and CE.POLICYRESSTATUS is null) and
--(CE.CERTSTATUS not in (1, 4) and CE.CERTRESSTATUS is null) and 
--(CE.COVLSTATUS not in (1 ,4) and CE.COVLRESSTATUS is null) and 
--(CE.ISNEXUS = '0' or CE.ISFLEX = '1') and 
--(CE.USERID is null or (CE.USERID is not null and UP.[STATUS] = 8 and WU.SENTWELCOMEPKGDTTM is null)) and
--(CE.RELCAT = -1);

IF OBJECT_ID('tempdb..#tblResult_Spouse') IS NOT NULL
begin
    DROP TABLE #tblResult_Spouse;
	print 'Drop temp table'
end    
-- -- The following script is to get the qualified Spouse only
with DistinctPolicyAndCert as 
(
	select distinct CE.POLICYID, CE.CERTID
	from VW_WEBMEMBERCERTIFICATE CE
	inner join S00USERPROFILE UP on CE.USERID = UP.USERID
	where UP.PMWEBACCESS = 1
)
select 
CE.ROCID, CE.USERID, CE.RELCAT, CE.LANGUAGEID, CE.POLICYID, CE.CERTNUM, CE.COVLIVEID,
CE.ISWASENABLED, CE.CERTEFFDT, P.GENWEBACCT, RC.DELIVERYTYPE, RC.CORRTYPE, RC.CORRNUM,
CE.POLICYSTATUS, CE.POLICYRESSTATUS, CE.CERTSTATUS, CE.CERTRESSTATUS, CE.COVLSTATUS, CE.COVLRESSTATUS, CE.ISNEXUS, CE.ISFLEX,
UP.[STATUS], WU.SENTWELCOMEPKGDTTM, 0 as 'IsWebActive',
NEWID() as 'GUID'
into #tblResult_Spouse
from VW_WEBMEMBERCERTIFICATE CE
inner join G00POLICY P on CE.POLICYID = P.POLICYID
inner join R00ROCCONTACTINFO RC on CE.ROCID = RC.ROCID
inner join DistinctPolicyAndCert DPC on CE.POLICYID = DPC.POLICYID and CE.CERTID = DPC.CERTID
left join S00USERPROFILE UP on CE.USERID = UP.USERID
left join S00WEBUSER WU ON WU.USERID = CE.USERID
where 
(CE.LANGUAGEID = @LANGID and CE.ISWASENABLED = 1 and CE.CERTEFFDT <= @AsOfDate) and 
(P.GENWEBACCT = 1) and 
(RC.DELIVERYTYPE = 4 and RC.CORRTYPE = 7 and (RC.CORRNUM is not null and RC.CORRNUM <> '')) and 
(CE.POLICYSTATUS not in (1,4) and CE.POLICYRESSTATUS is null) and
(CE.CERTSTATUS not in (1, 4) and CE.CERTRESSTATUS is null) and 
(CE.COVLSTATUS not in (1 ,4) and CE.COVLRESSTATUS is null) and 
(CE.ISNEXUS = '0' or CE.ISFLEX = '1') and 
(CE.USERID is null or (CE.USERID is not null and UP.[STATUS] = 8 and WU.SENTWELCOMEPKGDTTM is null)) and
(CE.RELCAT = 1)

update #tblResult_Spouse
set IsWebActive = dbo.udf_SECWebResolveSpouseAccess(COVLIVEID, @AsOfDate)

select * from #tblResult_Spouse where IsWebActive = 1

--drop table #tblResult_Spouse
