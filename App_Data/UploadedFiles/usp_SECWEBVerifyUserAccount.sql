/****** Object:  StoredProcedure [dbo].[usp_SECWEBVerifyUserAccount]    Script Date: 03/07/2014 17:10:33 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_SECWEBVerifyUserAccount]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_SECWEBVerifyUserAccount]
GO

/****** Object:  StoredProcedure [dbo].[usp_SECWEBVerifyUserAccount]    Script Date: 03/07/2014 17:10:33 ******/
SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO








CREATE   PROCEDURE [dbo].[usp_SECWEBVerifyUserAccount]
( 
	@psProcessUserId	VARCHAR(10),
	@piLanguage			SMALLINT	= 1,
	@psErrorCode		VARCHAR(5) OUTPUT,
  
	@piAction			SMALLINT,			/*
											1 = Sign In
											2 = Lost/Forgotten Password
											3 = Registration/Activation
											*/
	@piUserType			SMALLINT,
	@psPolicyCode		VARCHAR(20),
	@psCertNum			VARCHAR(20),
	@piRelCat			SMALLINT,
	@psEmailAddress		VARCHAR(128),
	@psActivationCode	VARCHAR(50),
	@pdAsOfDate			DATETIME,
	@psProviderCode		VARCHAR(20)= NULL
 /*
				Plan Admin-2	Advisor-3		Provider-4		Plan Member-1      
				-------------------------------------------------------------------
SignIn			EmailAddress	EmailAddress	EmailAddress	Policy, Certificate		
L/F Password	EmailAddress	EmailAddress	EmailAddress	Policy, Certificate	
Activation		ActivationCode	ActivationCode	ActivationCode	Policy, Certificate						
*/
  
)
AS
BEGIN

/*	AUTHOR      	 DATE     		DESCRIPTION
	----------- 	 -------  		----------------------------
	Dana Scripcaru  March 4, 2012  	GAP#WEB
	Edmund Low		June 15, 2012  	GAP#WEB
	Dana Scripcaru  July 18, 2012  	GAP#WEB - implement Advisor and Practitioner
	Edmund Low		July 25, 2012  	GAP#WEB
*/ 
DECLARE @sUserID VARCHAR(20)
--DECLARE @sWASStructCode VARCHAR(20)
DECLARE @iCount SMALLINT
--DECLARE @iCertID INT
--DECLARE @iInsDepID INT
--DECLARE @dFirstDate DATETIME
--DECLARE @dLastDate DATETIME
DECLARE @iRet_Val SMALLINT
DECLARE @iROCID INT

SET @psCertNum = LTRIM(SUBSTRING(@psCertNum, PATINDEX ('%[^0]%', @psCertNum), LEN(@psCertNum)))

SET @iRet_Val  = 0
IF @piUserType not IN (1,2,3,4) -- Allow only external user types i.e. Plan Member, Plan Admin , Advisor, Practitioner
	BEGIN
			SET @psErrorCode='L0010'
			GOTO ERR_HANDLER				
	END
	
IF @piUserType IN (2,3,4) -- Plan Admin , Advisor, Practitioner
BEGIN
	IF @piAction IN (1,2) -- SignIn, Lost Forgotten Password
	BEGIN
		--========================================================================================================
		--	Case 1 Use EmailAddress	to get USERID
		--========================================================================================================
											
		PRINT 'USE EmailAddress to login ' 	
			SELECT @sUserID = UP.USERID,
				   @iROCID = R.ROCID
			FROM S00USERPROFILE UP
			INNER JOIN R00ROCROLE RR ON RR.ROCROLEID = UP.ROCROLEID 
			INNER JOIN R00ROC R ON R.ROCID = RR.ROCID 		
			INNER JOIN R00ROCCONTACTINFO RC ON  RC.ROCID = R.ROCID AND 
												RC.DELIVERYTYPE = 4 AND
												RC.CORRTYPE = 8 -- Non-Plan Members use Office email address
			WHERE	RC.CORRNUM = @psEmailAddress
					AND UP.USERTYPE = @piUserType
					AND WEB = '1'
			-- In case there is more then 1 UserID or there is no UserID	
			IF @@rowcount <> 1 
				BEGIN
					--SET @psErrorCode='L0010'
					--GOTO ERR_HANDLER
					RETURN(0) 
				END
	END
	ELSE -- Activation/Registration
	BEGIN
		--========================================================================================================
		--	Case 2 Use ActivationCode to get USERID
		--========================================================================================================

		PRINT 'USE ActivationCode to login '
		SELECT  @sUserID = USERID  ,
				@iROCID = RR.ROCID
		FROM S00USERPROFILE UP
		INNER JOIN R00ROCROLE RR ON RR.ROCROLEID = UP.ROCROLEID 
		WHERE PASSWD = @psActivationCode	
				AND USERTYPE = @piUserType
				AND WEB = '1'
		
		-- In case there are more then one USERID with the same Activation Code raise error
		IF @@rowcount <> 1 
		BEGIN
			--SET @psErrorCode='L0010'
			--GOTO ERR_HANDLER 
			RETURN(0)
		END
	END
END
ELSE
BEGIN -- Plan Member, all actions
	--========================================================================================================
	--	Case 3 Use Policy, Certificate	to get USERID
	--========================================================================================================

	PRINT 'USE Policy, Certificate to login'
	SELECT	@sUserID = UP.USERID,
			--@iCertID = CE.CERTID,
			@iROCID = R.ROCID
			--,
			--@iInsDepID = CL.INSDEPID
	FROM G00POLICY P
	INNER JOIN G00CERTIFICATE CE ON P.POLICYID = CE.POLICYID
	INNER JOIN G00COVEREDLIVE CL ON CL.CERTID = CE.CERTID 
	INNER JOIN R00ROCROLE RR ON RR.ROCROLEID = CL.INSDEPID 
	INNER JOIN R00ROC R ON R.ROCID = RR.ROCID
	--INNER JOIN R00PERSON PE ON PE.PERSONID = R.PERSONCORPID
	LEFT JOIN R00ROCROLE RRU ON RRU.ROCID = RR.ROCID
								AND RRU.ROLETYPE = 7		-- 7 = User
	LEFT JOIN S00USERPROFILE UP ON UP.ROCROLEID = RRU.ROCROLEID 
								AND UP.WEB = '1' 			-- 1 = WEB
								AND USERTYPE = @piUserType	
	WHERE P.POLICYCODE = @psPolicyCode
			AND LTRIM(SUBSTRING(CE.CERTNUM, PATINDEX ('%[^0]%', CE.CERTNUM), LEN(CE.CERTNUM))) = @psCertNum
			AND CL.RELCAT = @piRelCat 
			AND ((@piRelCat = -1) OR
				 (@piRelCat = 1 AND dbo.udf_SECWebResolveSpouseAccess(CL.COVLIVEID, GETDATE()) = 1)
				 )
				 OPTION(FORCE ORDER)

	SET @iCount = @@rowcount	

	PRINT 'UserID=' + ISNULL(@sUserID, 'NULL') + ' ROCID=' + CAST(ISNULL(@iROCID, 0) AS VARCHAR) + ' @iCount=' + CAST(@iCount AS VARCHAR)

	-- There should be only one record found	
	IF  @iCount <> 1 
		BEGIN
			--SET @psErrorCode='L0010'
			--GOTO ERR_HANDLER 
			RETURN(0)
		END		


	--SELECT @dFirstDate = MIN(ELIGDT)
	--FROM G00COVERAGE COV 
	--WHERE CERTID = @iCertID
	--		AND INSDEPID = @iInsDepID 
	--		AND COV.SYSSTATUS = 1
			
	--SELECT @dLastDate = dbo.udf_COMLastDateAnyBenefitTerminated (@iCertID, @iInsDepID)	
END
			 
--========================================================================================================
--	Return
--========================================================================================================
PRINT 'ROCID ' + CAST(@iROCID AS VARCHAR)+ ', USERID ' + @sUserID
EXEC @iRet_Val = usp_SECWEBRetrieveUserAccount
						@psProcessUserId		,
						@piLanguage		,
						@psErrorCode	OUTPUT,		-- Error Code
						@sUserID,
						@iROCID		
					
	IF @iRet_Val <> 0
		BEGIN
			SET @psErrorCode='L000P'
			GOTO ERR_HANDLER 
		END

IF @piUserType IN (1, 2)
BEGIN
	EXEC @iRet_Val = usp_SECWEBVerifyUserAccountPlanMemberPlanAdmin
						@psProcessUserId,
						@piLanguage		,
						@psErrorCode	OUTPUT,		-- Error Code
						@piAction		,
						@piUserType		,
						@iROCID			,
						@psPolicyCode	,
						@psCertNum		,
						@piRelCat		,
						@pdAsOfDate
					
	IF @iRet_Val <> 0
		BEGIN
			SET @psErrorCode='L000P'
			GOTO ERR_HANDLER 
		END
END
--------------------------------------------------------------------------
--                       GAP#WEB - implement Advisor and Practitioner
--------------------------------------------------------------------------
IF @piUserType = 3 -- advisor
BEGIN 
	EXEC @iRet_Val = usp_SECWEBVerifyUserAccountAdvisor
						@psProcessUserId,
						@piLanguage		,
						@psErrorCode	OUTPUT,		-- Error Code
						@piAction		,
						@piUserType		,
						@iROCID	
					
	IF @iRet_Val <> 0
		BEGIN
			SET @psErrorCode='L000P'
			GOTO ERR_HANDLER 
		END

END 
IF @piUserType = 4 -- practitioner
BEGIN 
	EXEC @iRet_Val = usp_SECWEBVerifyUserAccountPractitioner
						@psProcessUserId,
						@piLanguage		,
						@psErrorCode	OUTPUT,		-- Error Code
						@piAction,
						@piUserType		,
						@iROCID	,
						@psProviderCode 
					
	IF @iRet_Val <> 0
		BEGIN
			SET @psErrorCode='L000P'
			GOTO ERR_HANDLER 
		END

END 	


RETURN(0)

ERR_HANDLER:
        RETURN(1)
END









GO

GRANT EXECUTE ON [dbo].[usp_SECWEBVerifyUserAccount] TO [ACESWebUserRole] AS [dbo]
GO

