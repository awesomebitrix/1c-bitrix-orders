-- Function: setup_reserve_measured(integer, integer, double precision, integer, integer)

-- DROP FUNCTION setup_reserve_measured(integer, integer, double precision, integer, integer);

CREATE OR REPLACE FUNCTION setup_reserve_measured(
    a_bill_no integer,
    ks integer,
    kol double precision,
    usr integer,
    code_position integer DEFAULT NULL::integer)
  RETURNS double precision AS
$BODY$
DECLARE
--SELECT setup_reserve_measured(13200056,100001775,140)
--110021098
--	a_bill_no integer;
--	ks integer;
--	kol0 double precision;
--	kol double precision;
	rs record;
	rez double precision default 0;
	kod integer default 0;
	usr_name character varying;
	loc_code_position integer;
BEGIN
RAISE NOTICE 'К резервированию: %', kol;

SELECT Имя INTO usr_name FROM Сотрудники WHERE Номер = usr;
SELECT Код INTO kod FROM arc_energo.Счета WHERE "№ счета"= a_bill_no;

If NOT code_position IS NULL THEN
loc_code_position =code_position;
END IF;
-----------------------------------------------------------------------------------------------------------------------
IF kol >=100 THEN
	FOR rs IN
	   SELECT k.КодСодержания, k.КодСклада, k.Примечание, k.КодКоличества kk, k.Свободно, coalesce(r.rez,0) Рез 
	   FROM Количество k
	   JOIN Содержание s ON k.КодСодержания=s.КодСодержания
	   LEFT JOIN
		(SELECT КодКоличества, Sum(Резерв) rez FROM Резерв 
		WHERE КогдаСнял IS NULL
		GROUP BY КодКоличества) r
	   ON k.КодКоличества=r.КодКоличества
	   WHERE k.Свободно - coalesce(r.rez,0) >=100 AND coalesce(ОКЕИ,796)=6 AND k.quality=0
	   AND k.КодСодержания =ks
	   ORDER BY  k.Свободно - coalesce(r.rez,0)  DESC

	LOOP
	IF kol <100 THEN EXIT; END IF;
	RAISE NOTICE 'Мерный. Попали в первый цикл, когда количество мерн. товара больше ста.';
		IF rs.Свободно - rs.Рез >= kol THEN
				INSERT INTO arc_energo.Резерв (Резерв, КодКоличества, КодСодержания, Счет, КодСклада, ПримечаниеСклада,Когда, Докуда, Кем, Подкого, "Подкого_Код", Кем_Номер, КодПозиции)
				VALUES (
				kol, nullif(rs.kk,0), ks, a_bill_no, rs.КодСклада, rs.Примечание,now(), now()+'10 days'::interval,usr_name,
				(SELECT Предприятие FROM arc_energo.Предприятия WHERE Код =kod),kod,usr,loc_code_position);
			rez:=rez + kol;
			kol:=0;
		ELSE
		RAISE NOTICE 'Мерный. Мерный больше ста.Резервируем бухту';
				INSERT INTO arc_energo.Резерв (Резерв, КодКоличества, КодСодержания, Счет, КодСклада, ПримечаниеСклада,Когда, Докуда, Кем, Подкого, "Подкого_Код", Кем_Номер, КодПозиции)
				VALUES (
				rs.Свободно - rs.Рез , nullif(rs.kk,0), ks, a_bill_no, rs.КодСклада, rs.Примечание,now(), now()+'10 days'::interval,usr_name,
				(SELECT Предприятие FROM arc_energo.Предприятия WHERE Код =kod),kod,usr,loc_code_position);

			rez:=rez + rs.Свободно - rs.Рез;	
			kol:= kol-(rs.Свободно - rs.Рез);
		END IF;
		
	END LOOP;
END IF;	
-----------------------------------------------------------------------------------------------------------------------
IF kol > 0 THEN
	RAISE NOTICE 'Мерный. Попали во второй цикл, количество мерн. товара меньше ста.';
	FOR rs IN
	   SELECT k.КодСодержания, k.КодСклада, k.Примечание, k.КодКоличества kk, k.Свободно, coalesce(r.rez,0) Рез 
	   FROM Количество k
	   JOIN Содержание s ON k.КодСодержания=s.КодСодержания
	   LEFT JOIN
		(SELECT КодКоличества, Sum(Резерв) rez FROM Резерв 
		WHERE КогдаСнял IS NULL
		GROUP BY КодКоличества) r
	   ON k.КодКоличества=r.КодКоличества
	   WHERE k.Свободно - coalesce(r.rez,0)>0 AND coalesce(ОКЕИ,796)=6 AND k.quality=0
	   AND k.КодСодержания = ks
	   ORDER BY k.Свободно - coalesce(r.rez,0)>0  ASC
	LOOP

	IF kol=0 THEN EXIT; END IF;
	
		RAISE NOTICE 'Зарезервировано: % Остаток: % На месте: %', rez, kol, rs.Свободно;
		IF kol <=(rs.Свободно - rs.Рез) THEN

				INSERT INTO arc_energo.Резерв (Резерв, КодКоличества, КодСодержания, Счет, КодСклада, ПримечаниеСклада,Когда, Докуда, Кем, Подкого,"Подкого_Код", Кем_Номер, КодПозиции)
				VALUES (
				kol , nullif(rs.kk,0), ks, a_bill_no, rs.КодСклада, rs.Примечание,now(), now()+'10 days'::interval,usr_name,
				(SELECT Предприятие FROM arc_energo.Предприятия WHERE Код=kod),kod,usr,loc_code_position);

				rez:=rez + kol ;
				kol:=0;
				
		RAISE NOTICE 'Зарезервировано: % Остаток: % На месте: %', rez, kol, rs.Свободно::double precision;			
		END IF;
		
	END LOOP;
END IF;

RAISE NOTICE 'Зарезервировано: % Остаток: %', rez, kol;

RETURN kol; 

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION setup_reserve_measured(integer, integer, double precision, integer, integer)
  OWNER TO arc_energo;
