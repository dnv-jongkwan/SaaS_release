

GO
PRINT N'Altering Procedure [synergix].[EXT_ALL_POST_SAVE]...';


GO


/*
 exec [synergix].[EXT_ALL_POST_SAVE] @nTrans=1898149, @nPerson =0
  select * FROM synergix.D_TRANS_TMP_MAIL


*/



ALTER      PROCEDURE [synergix].[EXT_ALL_POST_SAVE] @nTrans INT , @nPerson int
AS
begin
  PRINT(N'EXT_ALL_POST_SAVE')
  DECLARE @APPLICATION int =0, @QA_VERIFY_EMAIL NVARCHAR(4000),@ENV_VERIFY_EMAIL NVARCHAR(4000), @RECEIVER NVARCHAR(4000), @PIC_EMAIL nvarchar(4000)
          ,@STATUS int =0,@STATUS_TEMP int =0, @VALID_TRANS int =SYNERGIX.GET_VALID_TRANS(@nTrans) --@IS_EMAIL_READY int =0, 
          ,@UNIT_RESPONSIBLE int =0, @CREATOR_EMAIL NVARCHAR(4000)

  SELECT TOP 1 @APPLICATION = APPLICATION ,@PIC_EMAIL= P1.EMAIL_ADDRESS,@STATUS = T1.STATUS, @STATUS_TEMP = T1.STATUS_TEMP
         ,@UNIT_RESPONSIBLE= T1.UNIT_RESPONSIBLE
  FROM SYNERGIX.D_TRANS  T1 WITH(NOLOCK)
     LEFT OUTER JOIN  SYNERGIX.P_PERSON P1 WITH(NOLOCK) 
       ON T1.PERSON_IN_CHARGE = P1.PERSON
  WHERE TRANS = @nTrans

 SELECT TOP 1 @CREATOR_EMAIL= EMAIL_ADDRESS FROM SYNERGIX.P_PERSON P1 WITH(NOLOCK) 
       where PERSON IN (SELECT VALUE_INTEGER FROM SYNERGIX.D_SYNERGI_REFERENCE WITH(NOLOCK) WHERE TRANS =@nTrans AND REFERENCE =214 )


  --IF EXISTS(SELECT 1 FROM synergix.D_TRANS_TMP_MAIL WHERE TRANS = @nTrans)
  --   SET @IS_EMAIL_READY =1

  IF EXISTS(SELECT 1 FROM SYNERGIX.A_APPLICATION WHERE DESCEND_APPLICATION IN (179,541) AND APPLICATION =@APPLICATION)
     
  -- Enviroment, Cost of Poor Quality
  BEGIN
      select @QA_VERIFY_EMAIL= STRING_AGG(p1.EMAIL_ADDRESS,N', ') 
        from synergix.P_EXTRA_INFO e1 WITH(NOLOCK)
            INNER JOIN SYNERGIX.P_PERSON p1 WITH(NOLOCK)
                on e1.PERSON = p1.PERSON
        WHERE e1.EXTRA_INFO = 1
        AND   e1.VALUE_CODE IN (SELECT DESCEND_UNIT FROM  synergix.A_UNIT WHERE UNIT  = @UNIT_RESPONSIBLE) 
        and   p1.EMAIL_ADDRESS  IS NOT NULL

        select @ENV_VERIFY_EMAIL= STRING_AGG(p1.EMAIL_ADDRESS,N', ') 
        from synergix.P_EXTRA_INFO e1 WITH(NOLOCK)
            INNER JOIN SYNERGIX.P_PERSON p1 WITH(NOLOCK)
                on e1.PERSON = p1.PERSON
        WHERE e1.EXTRA_INFO = 2
        AND   e1.VALUE_CODE IN (SELECT DESCEND_UNIT FROM  synergix.A_UNIT WHERE UNIT  = @UNIT_RESPONSIBLE) 
        and   p1.EMAIL_ADDRESS  IS NOT NULL
        SET @RECEIVER = (CASE WHEN @APPLICATION = 541 THEN @QA_VERIFY_EMAIL
                            ELSE @ENV_VERIFY_EMAIL END)    
        IF @STATUS IN (1  ,0)
        BEGIN
             IF SYNERGIX.EXIST_SYNERGI_REFERENCE_OPTION(@nTrans,210,1) = 1 AND (SYNERGIX.EXIST_SYNERGI_REFERENCE_OPTION(@VALID_TRANS,210,1) = 0  OR @VALID_TRANS =0 )
               BEGIN   
                  PRINT(N'send verification email start')
                  insert into  synergix.D_TRANS_TMP_MAIL (TRANS, TMP_MAIL_NO, RECEIVERS_TO, CASE_COMMENT) 
                     values(@nTrans,1,@RECEIVER, SYNERGIX.GET_EMAIL_TEXT(@nPerson, 10, 8103))
                  --EXEC SYNERGIX.EXT_MERGE_SYNERGI_REFERENCE @TRANS =@nTrans, @REFERENCE =212, @INT_VALUE=1
                  PRINT(N'send verification email end')
               END
      
             DECLARE @R211 int =0, @R211_BEFORE int =0, @VERI_CHARGE_EMAIL NVARCHAR(4000)

             SET @VERI_CHARGE_EMAIL =@PIC_EMAIL
             IF @PIC_EMAIL != @CREATOR_EMAIL AND ISNULL(@CREATOR_EMAIL,N'') != N''
                SET @VERI_CHARGE_EMAIL = @VERI_CHARGE_EMAIL + N';'+@CREATOR_EMAIL

             SELECT TOP 1 @R211= REFERENCE_OPTION FROM SYNERGIX.D_SYNERGI_REFERENCE WITH(NOLOCK) WHERE TRANS =@nTrans AND REFERENCE =211
             SELECT TOP 1 @R211_BEFORE= REFERENCE_OPTION FROM SYNERGIX.D_SYNERGI_REFERENCE WITH(NOLOCK) WHERE TRANS =@VALID_TRANS AND REFERENCE =211
             PRINT(STR(@R211_BEFORE) + N'--->'+ STR(@R211))
             IF ISNULL(@R211,0) = 232 AND ISNULL(@R211,0) != ISNULL(@R211_BEFORE,0) 
             BEGIN
                  PRINT(N'send verification result : approve start')
                  insert into  synergix.D_TRANS_TMP_MAIL (TRANS, TMP_MAIL_NO, RECEIVERS_TO, CASE_COMMENT) 
                     values(@nTrans,1,@VERI_CHARGE_EMAIL, SYNERGIX.GET_EMAIL_TEXT(@nPerson, 10, 8104))
                --  EXEC SYNERGIX.EXT_MERGE_SYNERGI_REFERENCE @TRANS =@nTrans, @REFERENCE =213, @INT_VALUE=1
                  PRINT(N'send verification result : approve end')
             END
             IF ISNULL(@R211,0) = 233 AND ISNULL(@R211,0) != ISNULL(@R211_BEFORE,0) 
             BEGIN
                  PRINT(N'send verification result : reject start')
                  insert into  synergix.D_TRANS_TMP_MAIL (TRANS, TMP_MAIL_NO, RECEIVERS_TO, CASE_COMMENT) 
                     values(@nTrans,1,@VERI_CHARGE_EMAIL, SYNERGIX.GET_EMAIL_TEXT(@nPerson, 10, 8105))
                 -- EXEC SYNERGIX.EXT_MERGE_SYNERGI_REFERENCE @TRANS =@nTrans, @REFERENCE =213, @INT_VALUE=2
                  PRINT(N'send verification result : reject end')
             END
       END
       
        IF @STATUS_TEMP = 3 AND @STATUS_TEMP != @STATUS
        BEGIN
            PRINT(N'Status In Progress start')
            DECLARE @ACT_MAIL NVARCHAR(4000) = N'', @FINAL_MAIL NVARCHAR(4000) =N''

            SELECT @ACT_MAIL= STRING_AGG(p1.EMAIL_ADDRESS,N', ') 
            FROM SYNERGIX.D_ACTION A1 WITH(NOLOCK)
                INNER JOIN SYNERGIX.P_PERSON P1 WITH(NOLOCK)
                ON A1.PERSON_IN_CHARGE = P1.PERSON
            WHERE A1.TRANS =@nTrans
            AND   P1.EMAIL_ADDRESS IS NOT NULL

            SET @FINAL_MAIL = @PIC_EMAIL 
            IF  ISNULL(@ACT_MAIL,N'') != N''
                SET @FINAL_MAIL = @FINAL_MAIL + N',' +  @ACT_MAIL

            insert into  synergix.D_TRANS_TMP_MAIL (TRANS, TMP_MAIL_NO, RECEIVERS_TO, CASE_COMMENT) 
                values(@nTrans,1,@FINAL_MAIL, SYNERGIX.GET_EMAIL_TEXT(@nPerson, 10, 8108))
                 
            PRINT(N'Status In Progress end')
        END
        IF @STATUS_TEMP = 4 AND @STATUS_TEMP != @STATUS
        BEGIN
            PRINT(N'Status  Approved start')
            insert into  synergix.D_TRANS_TMP_MAIL (TRANS, TMP_MAIL_NO, RECEIVERS_TO, CASE_COMMENT) 
                values(@nTrans,1,@PIC_EMAIL, SYNERGIX.GET_EMAIL_TEXT(@nPerson, 10, 8109))                 
            PRINT(N'Status  Approved end')
        END

        IF @STATUS_TEMP = 6 AND @STATUS_TEMP != @STATUS
        BEGIN
            PRINT(N'Status  Closed start')
            IF ISNULL(@CREATOR_EMAIL,N'') != N''
            BEGIN
              insert into  synergix.D_TRANS_TMP_MAIL (TRANS, TMP_MAIL_NO, RECEIVERS_TO, CASE_COMMENT) 
                values(@nTrans,1,@PIC_EMAIL, SYNERGIX.GET_EMAIL_TEXT(@nPerson, 10, 8110)) 
            END
                            
            PRINT(N'Status  Closed end')
        END


      IF @STATUS IN (0,1,7)  
      BEGIN
          IF SYNERGIX.EXIST_SYNERGI_REFERENCE_OPTION(@nTrans,211,233) = 1
          BEGIN
             DELETE FROM SYNERGIX.D_SYNERGI_REFERENCE WHERE TRANS =@nTrans AND REFERENCE  IN (210,211)
          END
      END
     
  END




  
  ---------------------------------------------
end






GO
PRINT N'Update complete.';


GO
