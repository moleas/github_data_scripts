CREATE OR REPLACE PROCEDURE DEVENGAMIENTO_COMPUESTO_COMPLETO @fcd DATE
AS
	-- Tabla Base
	DROP TABLE IF EXISTS DWH_DT_INTERES_COMPUESTO
	SELECT * INTO DWH_DT_INTERES_COMPUESTO FROM DWH_DT_BASE_SOFR WHERE 1 = 2
	INSERT INTO DWH_DT_INTERES_COMPUESTO(SELECT * FROM DWH_DT_BASE_SOFR)

	-- condiciones años bisiestos y euro
	DECLARE @CONDICION1 INTEGER = (SELECT (CASE WHEN YEAR(@fcd) NOT IN (SELECT DISTINCT YEAR FROM DWH_AU_FECHAS WHERE MONTH=2 AND DAY_IN_MONTH=29) THEN 0 ELSE 1 END) FROM DUMMY)
	DECLARE @CONDICION2 INTEGER = (SELECT (CASE WHEN @fcd <> (SELECT LAST_DATE FROM DWH_AU_FECHAS WHERE FECHA=@fcd) THEN 0 ELSE 1 END) FROM DUMMY)
	DECLARE @NUMERO INTEGER = (SELECT DAY(@fcd) FROM DUMMY)
	
	-- Calculo de Intereses
	ALTER TABLE DWH_DT_INTERES_COMPUESTO ADD INT_BASE_MOTOR_DIARIO DECIMAL(28,12), ADD INT_MARGEN_MOTOR_DIARIO DECIMAL(28,12), ADD INT_CAS_MOTOR_DIARIO DECIMAL(28,12), ADD INT_TOTAL_MOTOR_DIARIO DECIMAL(28,12)
	
	-- Calculo de interes diario por Tasa Base por metodo simple o compuesto
    UPDATE DWH_DT_INTERES_COMPUESTO SET INT_BASE_MOTOR_DIARIO = (
		CASE
			WHEN  RFR_COMPOUNDING_TYPE = 1 THEN (
				CASE
					WHEN INTEREST_DAY_BASIS = 'ACTUAL/360' THEN LCY_AMOUNT*TASA_BASE/36000 
					WHEN INTEREST_DAY_BASIS = 'ACTUAL/365' THEN LCY_AMOUNT*TASA_BASE/36500
					WHEN INTEREST_DAY_BASIS = 'ACTUAL/ACTUAL' AND @CONDICION1 = 0 THEN LCY_AMOUNT*TASA_BASE/36500
					WHEN INTEREST_DAY_BASIS = 'ACTUAL/ACTUAL' AND @CONDICION1 = 1 THEN LCY_AMOUNT* TASA_BASE/36600
					WHEN INTEREST_DAY_BASIS LIKE '%EURO%' AND @CONDICION2 = 0 THEN LCY_AMOUNT*TASA_BASE/36000
					WHEN INTEREST_DAY_BASIS LIKE '%EURO%' AND @CONDICION2 = 1 THEN LCY_AMOUNT*TASA_BASE/36000 *(31- @NUMERO)
				END)
		
			WHEN RFR_COMPOUNDING_TYPE = 2 THEN (
				CASE 
					WHEN INTEREST_DAY_BASIS = 'ACTUAL/360' THEN (LCY_AMOUNT_ACUM)*TASA_BASE/36000 -- Falta sumar LCY_AMOUNT_ACUM y LCY_AMOUNT
					WHEN INTEREST_DAY_BASIS = 'ACTUAL/365' THEN (LCY_AMOUNT_ACUM)*TASA_BASE/36500
					WHEN INTEREST_DAY_BASIS = 'ACTUAL/ACTUAL' AND @CONDICION1 = 0 THEN (LCY_AMOUNT_ACUM)*TASA_BASE/36500
					WHEN INTEREST_DAY_BASIS = 'ACTUAL/ACTUAL' AND @CONDICION1 = 1 THEN (LCY_AMOUNT_ACUM)* TASA_BASE/36600
					WHEN INTEREST_DAY_BASIS LIKE '%EURO%' AND @CONDICION2 = 0 THEN (LCY_AMOUNT_ACUM)*TASA_BASE/36000
					WHEN INTEREST_DAY_BASIS LIKE '%EURO%' AND @CONDICION2 = 1 THEN (LCY_AMOUNT_ACUM)*TASA_BASE/36000 *(31- @NUMERO)
				END)
		END)
	
	-- Calculo de interes diario por Tasa Margen por metodo simple
	UPDATE DWH_DT_INTERES_COMPUESTO SET INT_MARGEN_MOTOR_DIARIO =(
		CASE 
			WHEN INTEREST_DAY_BASIS = 'ACTUAL/360' THEN LCY_AMOUNT*TASA_SPREAD/36000 
			WHEN INTEREST_DAY_BASIS = 'ACTUAL/365' THEN LCY_AMOUNT*TASA_SPREAD/36500
			WHEN INTEREST_DAY_BASIS = 'ACTUAL/ACTUAL' AND @CONDICION1 = 0 THEN LCY_AMOUNT*TASA_SPREAD/36500
			WHEN INTEREST_DAY_BASIS = 'ACTUAL/ACTUAL' AND @CONDICION1 = 1 THEN LCY_AMOUNT* TASA_SPREAD/36600
			WHEN INTEREST_DAY_BASIS LIKE '%EURO%' AND @CONDICION2 = 0 THEN LCY_AMOUNT*TASA_SPREAD/36000
			WHEN INTEREST_DAY_BASIS LIKE '%EURO%' AND @CONDICION2 = 1 THEN LCY_AMOUNT*TASA_SPREAD/36000 *(31- @NUMERO)
		END)

    -- Calculo de interes diario por Tasa CAS por metodo simple
	UPDATE DWH_DT_INTERES_COMPUESTO SET INT_CAS_MOTOR_DIARIO =(
		CASE 
			WHEN INTEREST_DAY_BASIS = 'ACTUAL/360' THEN LCY_AMOUNT * TASA_CAS/36000 
			WHEN INTEREST_DAY_BASIS = 'ACTUAL/365' THEN LCY_AMOUNT*TASA_CAS/36500
			WHEN INTEREST_DAY_BASIS = 'ACTUAL/ACTUAL' AND @CONDICION1 = 0 THEN LCY_AMOUNT*TASA_CAS/36500
			WHEN INTEREST_DAY_BASIS = 'ACTUAL/ACTUAL' AND @CONDICION1 = 1 THEN LCY_AMOUNT* TASA_CAS/36600
			WHEN INTEREST_DAY_BASIS LIKE '%EURO%' AND @CONDICION2 = 0 THEN LCY_AMOUNT*TASA_CAS/36000
			WHEN INTEREST_DAY_BASIS LIKE '%EURO%' AND @CONDICION2 = 1 THEN LCY_AMOUNT*TASA_CAS/36000 *(31- @NUMERO)
		END)
	
	UPDATE DWH_DT_INTERES_COMPUESTO SET INT_TOTAL_MOTOR_DIARIO = ISNULL(INT_BASE_MOTOR_DIARIO,0) + ISNULL(INT_MARGEN_MOTOR_DIARIO,0) + ISNULL(INT_CAS_MOTOR_DIARIO,0)

	-- Tabla de FCC para acumulados
	DROP TABLE IF EXISTS DWH_DT_INFORMACION_FCC
	CREATE TABLE DWH_DT_INFORMACION_FCC(DEAL_REF_NO_FINAL VARCHAR(20), CAMPO_DWH VARCHAR(20), REAL_DATE DATE, LEG VARCHAR(3), MONTO DECIMAL(28,12))
	INSERT INTO DWH_DT_INFORMACION_FCC(DEAL_REF_NO_FINAL, CAMPO_DWH, REAL_DATE, LEG, MONTO)
	(SELECT DEAL_REF_NO_FINAL, CAMPO_DWH, REAL_DATE, LEG, SUM(MONTO) MONTO FROM (
    SELECT SDO.DEAL_REF_NO_FINAL, SDO.COD_PRODUCTO_FINAL, SDO.AMOUNT_TAG, AMT.CAMPO_DWH, SDO.REAL_DATE,
	(CASE WHEN SDO.AMOUNT_TAG LIKE '%DV_IN%' THEN 'IN' 
	WHEN SDO.AMOUNT_TAG LIKE '%DV_OUT%' THEN 'OUT' 
	ELSE 'N/A' END) LEG,
	SUM(CASE WHEN DRCR_IND = 'D' THEN LCY_AMOUNT ELSE -LCY_AMOUNT END) MONTO
	FROM DWH_DT_TRANSACCIONES_REV_PL SDO
	LEFT JOIN(SELECT DISTINCT GL_CODE, AMOUNT_TAG, CAMPO_DWH, COD_PRODUCTO FROM DWH_AU_PARAMETRIZACION_AMOUNT_TAG_SOFR) AMT ON SDO.AMOUNT_TAG = AMT.AMOUNT_TAG AND SDO.COD_PRODUCTO_FINAL = AMT.COD_PRODUCTO 
	WHERE (AMT.CAMPO_DWH = 'INT_ACCR' OR AMT.CAMPO_DWH = 'REV_ACCR') AND SDO.REAL_DATE = @fcd
	GROUP BY SDO.DEAL_REF_NO_FINAL, SDO.COD_PRODUCTO_FINAL, SDO.AMOUNT_TAG, AMT.CAMPO_DWH, SDO.REAL_DATE) AS SDU
    GROUP BY DEAL_REF_NO_FINAL, CAMPO_DWH, REAL_DATE, LEG)

	-- Join tabla de FCC
	DROP TABLE IF EXISTS TMP_DT_INTERES_COMPUESTO  
	CREATE TABLE TMP_DT_INTERES_COMPUESTO (COD_DEAL varchar(21), COD_BRANCH varchar(3), LCY_AMOUNT decimal(38,3), LCY_AMOUNT_ACUM decimal(38,3), COMPONENTE varchar(20), COD_PRODUCTO varchar(6), GL_CODE_PRODUCTO varchar(9), LEG varchar(4), COD_DIVISA varchar(3), NXT_SCH_DUE_DT date, FECHA_LO date, MATURITY_DATE datetime, COD_MODULO varchar(2), INTEREST_DAY_BASIS varchar(20), TASA_BASE decimal(13,8), TASA_BASE_ORIGINAL decimal(13,8), TASA_BASE_LO decimal(13,8), TASA_SPREAD decimal(13,8), TASA_CAS decimal(28,7), TASA_TOTAL decimal(13,8), TASA_MORA decimal(28,7), USER_DEFINED_STATUS varchar(4), LOCK_OUT_DAYS decimal(28,7), LOOK_BACK_DAYS decimal(28,7), RFR_COMPOUNDING_TYPE decimal(28,7), DAY_WEIGHT integer, FEC_DATO date, INT_BASE_MOTOR_DIARIO decimal(28,12), INT_MARGEN_MOTOR_DIARIO decimal(28,12), INT_CAS_MOTOR_DIARIO decimal(28,12), INT_TOTAL_MOTOR_DIARIO decimal(28,12), INT_ACCRUAL_FCC_DIARIO decimal(28,12))
	INSERT INTO TMP_DT_INTERES_COMPUESTO(COD_DEAL, COD_BRANCH, LCY_AMOUNT, LCY_AMOUNT_ACUM, COMPONENTE, COD_PRODUCTO, GL_CODE_PRODUCTO, LEG, COD_DIVISA, NXT_SCH_DUE_DT, FECHA_LO, MATURITY_DATE, COD_MODULO, INTEREST_DAY_BASIS, TASA_BASE, TASA_BASE_ORIGINAL, TASA_BASE_LO, TASA_SPREAD, TASA_CAS, TASA_TOTAL, TASA_MORA, USER_DEFINED_STATUS, LOCK_OUT_DAYS, LOOK_BACK_DAYS, RFR_COMPOUNDING_TYPE, DAY_WEIGHT, FEC_DATO, INT_BASE_MOTOR_DIARIO, INT_MARGEN_MOTOR_DIARIO, INT_CAS_MOTOR_DIARIO, INT_TOTAL_MOTOR_DIARIO, INT_ACCRUAL_FCC_DIARIO)
	(SELECT PRN.COD_DEAL, PRN.COD_BRANCH, PRN.LCY_AMOUNT, PRN.LCY_AMOUNT_ACUM, PRN.COMPONENTE, PRN.COD_PRODUCTO, PRN.GL_CODE_PRODUCTO, PRN.LEG, PRN.COD_DIVISA, PRN.NXT_SCH_DUE_DT, PRN.FECHA_LO, PRN.MATURITY_DATE, PRN.COD_MODULO, PRN.INTEREST_DAY_BASIS, PRN.TASA_BASE, PRN.TASA_BASE_ORIGINAL, PRN.TASA_BASE_LO, PRN.TASA_SPREAD, PRN.TASA_CAS, PRN.TASA_TOTAL, PRN.TASA_MORA, PRN.USER_DEFINED_STATUS, PRN.LOCK_OUT_DAYS, PRN.LOOK_BACK_DAYS, PRN.RFR_COMPOUNDING_TYPE, PRN.DAY_WEIGHT, PRN.FEC_DATO, PRN.INT_BASE_MOTOR_DIARIO, PRN.INT_MARGEN_MOTOR_DIARIO, PRN.INT_CAS_MOTOR_DIARIO, PRN.INT_TOTAL_MOTOR_DIARIO, ISNULL(SEC.MONTO, 0) FROM DWH_DT_INTERES_COMPUESTO PRN 
	LEFT JOIN DWH_DT_INFORMACION_FCC SEC ON PRN.COD_DEAL = SEC.DEAL_REF_NO_FINAL AND PRN.LEG = SEC.LEG AND PRN.FEC_DATO = SEC.REAL_DATE)

	-- Metodo de Redondeo
	ALTER TABLE TMP_DT_INTERES_COMPUESTO ADD ACUMULADO_CONTABLE DECIMAL(28,12), ADD ACUMULADO_CONTABLE_DIA_ANTERIOR DECIMAL(28,12), ADD ACCRUAL_CONTABLE DECIMAL(28,12), ADD INT_AJUSTE_MOTOR_DIARIO DECIMAL(28,12)

	UPDATE TMP_DT_INTERES_COMPUESTO SET ACUMULADO_CONTABLE_DIA_ANTERIOR = ROUND(LCY_AMOUNT_ACUM, 2)
	UPDATE TMP_DT_INTERES_COMPUESTO SET ACUMULADO_CONTABLE = ROUND((LCY_AMOUNT_ACUM + INT_TOTAL_MOTOR_DIARIO), 2)
	UPDATE TMP_DT_INTERES_COMPUESTO SET ACCRUAL_CONTABLE = ACUMULADO_CONTABLE - ACUMULADO_CONTABLE_DIA_ANTERIOR
	
    -- Calculo Diferencias 
    UPDATE TMP_DT_INTERES_COMPUESTO SET INT_AJUSTE_MOTOR_DIARIO = ISNULL(ABS(ACCRUAL_CONTABLE), 0) - ISNULL(ABS(INT_ACCRUAL_FCC_DIARIO),0)

	-- DROP tablas temporales 
	DROP TABLE IF EXISTS DWH_DT_INTERES_COMPUESTO
	DROP TABLE IF EXISTS DWH_DT_INFORMACION_FCC

	-- Print table
    SELECT * FROM TMP_DT_INTERES_COMPUESTO 