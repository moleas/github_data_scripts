CREATE OR REPLACE PROCEDURE SP_CREA_HISTORIA_COF @fcd DATE
AS
	-- CARGA HISTORICA INICIAL
	-- PROCESO PARA CARGA INICIAL DE TODA LA HISTORIA
	DECLARE @ROW_ID INTEGER = 1, @i INTEGER, @VAR_1 VARCHAR(31), @SEPARATOR VARCHAR(1), @INIT_NO INTEGER, @VAR_2 INTEGER, @VAR_3 VARCHAR(250)

	DELETE FROM TMP_DT_CONTRATOS_COF_H
	INSERT INTO TMP_DT_CONTRATOS_COF_H (ROW_ID, CONTRACT_REF_NO, MODULE, PRODUCT_CODE, BUY_SALE_INTERBR, RELATED_REFERENCES, FEC_DATO)
	(
	SELECT ROW_NUMBER( ) OVER (ORDER BY CONTRACT_REF_NO) AS ROW_ID, * FROM (
	SELECT DISTINCT CONTRACT_REF_NO, MODULE, PRODUCT_CODE, BUY_SALE_INTERBR, RELATED_REFERENCES, @fcd
	FROM DWH_DT_UDF_CONTRATOS_H WHERE BUY_SALE_INTERBR = 'Loan Sold' AND RELATED_REFERENCES IS NOT NULL
	) AS T1
	)

	WHILE @ROW_ID <= (SELECT MAX(ROW_ID) FROM TMP_DT_CONTRATOS_COF_H)
		BEGIN
		
			SET @VAR_3 = (SELECT RELATED_REFERENCES FROM TMP_DT_CONTRATOS_COF_H WHERE ROW_ID = @ROW_ID)
			SET @VAR_2 = 0
			SET @INIT_NO = 1
			SET @i = 1

			IF @VAR_3 LIKE '%-%'
				BEGIN
					WHILE @i <= (SELECT LEN((SELECT RELATED_REFERENCES FROM TMP_DT_CONTRATOS_COF_H WHERE ROW_ID = @ROW_ID)) FROM DUMMY)
						BEGIN
							SET @SEPARATOR = SUBSTRING((SELECT RELATED_REFERENCES FROM TMP_DT_CONTRATOS_COF_H WHERE ROW_ID = @ROW_ID), @i, 1)
							IF @SEPARATOR = '-' --AND (@i < (SELECT LEN((SELECT RELATED_REFERENCES FROM TMP_DT_CONTRATOS_COF_H)) FROM DUMMY)))
								BEGIN
									SET @VAR_2 = @VAR_2 + 1
									SET @VAR_1 = (SELECT SUBSTRING((SELECT RELATED_REFERENCES FROM TMP_DT_CONTRATOS_COF_H WHERE ROW_ID = @ROW_ID), @INIT_NO, @i - @INIT_NO) FROM DUMMY)
									
									IF @VAR_2 = 1
										BEGIN
											UPDATE TMP_DT_CONTRATOS_COF_H SET R_REFERENCE_1 = @VAR_1 WHERE ROW_ID = @ROW_ID
										END
									ELSE IF @VAR_2 = 2
										BEGIN
											UPDATE TMP_DT_CONTRATOS_COF_H SET R_REFERENCE_2 = @VAR_1 WHERE ROW_ID = @ROW_ID
										END
									ELSE IF @VAR_2 = 3
										BEGIN
											UPDATE TMP_DT_CONTRATOS_COF_H SET R_REFERENCE_3 = @VAR_1 WHERE ROW_ID = @ROW_ID
										END
									ELSE IF @VAR_2 = 4
										BEGIN
											UPDATE TMP_DT_CONTRATOS_COF_H SET R_REFERENCE_4 = @VAR_1 WHERE ROW_ID = @ROW_ID
										END
									SET @INIT_NO = @i + 1
								END
							ELSE IF @i = (SELECT LEN((SELECT RELATED_REFERENCES FROM TMP_DT_CONTRATOS_COF_H WHERE ROW_ID = @ROW_ID)) FROM DUMMY)
								BEGIN
									SET @VAR_2 = @VAR_2 + 1
									SET @VAR_1 = (SELECT SUBSTRING((SELECT RELATED_REFERENCES FROM TMP_DT_CONTRATOS_COF_H WHERE ROW_ID = @ROW_ID), @INIT_NO, @i - @INIT_NO + 1) FROM DUMMY)
									
									IF @VAR_2 = 1
										BEGIN
											UPDATE TMP_DT_CONTRATOS_COF_H SET R_REFERENCE_1 = @VAR_1 WHERE ROW_ID = @ROW_ID
										END
									ELSE IF @VAR_2 = 2
										BEGIN
											UPDATE TMP_DT_CONTRATOS_COF_H SET R_REFERENCE_2 = @VAR_1 WHERE ROW_ID = @ROW_ID
										END
									ELSE IF @VAR_2 = 3
										BEGIN
											UPDATE TMP_DT_CONTRATOS_COF_H SET R_REFERENCE_3 = @VAR_1 WHERE ROW_ID = @ROW_ID
										END
									ELSE IF @VAR_2 = 4
										BEGIN
											UPDATE TMP_DT_CONTRATOS_COF_H SET R_REFERENCE_4 = @VAR_1 WHERE ROW_ID = @ROW_ID
										END
									SET @INIT_NO = @i + 1
								END

							SET @i = @i + 1
						END
				END
			ELSE
				BEGIN
					SET @VAR_1 = (SELECT RELATED_REFERENCES FROM TMP_DT_CONTRATOS_COF_H WHERE ROW_ID = @ROW_ID)
					UPDATE TMP_DT_CONTRATOS_COF_H SET R_REFERENCE_1 = @VAR_1  WHERE ROW_ID = @ROW_ID
				END

			SET @ROW_ID = @ROW_ID + 1

		END
		
	UPDATE TMP_DT_CONTRATOS_COF_H SET COD_DEAL_COF = (
		CASE 
			WHEN (SUBSTRING(CONTRACT_REF_NO, 1, 3) <> SUBSTRING(R_REFERENCE_1, 1, 3)) AND SUBSTRING(R_REFERENCE_1, 4, 4) <> 'LSDB' THEN R_REFERENCE_1 
			WHEN (SUBSTRING(CONTRACT_REF_NO, 1, 3) <> SUBSTRING(R_REFERENCE_2, 1, 3)) AND SUBSTRING(R_REFERENCE_2, 4, 4) <> 'LSDB' THEN R_REFERENCE_2
			WHEN (SUBSTRING(CONTRACT_REF_NO, 1, 3) <> SUBSTRING(R_REFERENCE_3, 1, 3)) AND SUBSTRING(R_REFERENCE_3, 4, 4) <> 'LSDB' THEN R_REFERENCE_3 
			WHEN (SUBSTRING(CONTRACT_REF_NO, 1, 3) <> SUBSTRING(R_REFERENCE_4, 1, 3)) AND SUBSTRING(R_REFERENCE_4, 4, 4) <> 'LSDB' THEN R_REFERENCE_4 
		END)