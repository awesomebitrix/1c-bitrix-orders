-- FUNCTION: arc_energo.get_emp(integer)

DROP FUNCTION arc_energo.get_emp(integer);

CREATE OR REPLACE FUNCTION arc_energo.get_emp(
    bx_order_id integer,
    OUT "out_КодРаботника" INTEGER,
    OUT "out_Код" INTEGER,
    OUT "out_ЕАдрес" VARCHAR)
    RETURNS record
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE NOT LEAKPROOF 
AS $function$

DECLARE
    emp RECORD;
    Firm RECORD;
    INN VARCHAR;
    KPP VARCHAR;
    FirmCode INTEGER;
    loc_buyer_id INTEGER;
    new_emp BOOLEAN;
    loc_email VARCHAR;
    loc_email1 VARCHAR;
    text_var1 text;
    text_var2 text;
    text_var3 text;
BEGIN
    SELECT bx_buyer_id INTO loc_buyer_id FROM bx_order WHERE "Номер" = bx_order_id;

    SELECT digits_only(trim(both FROM fvalue)) INTO INN FROM bx_order_feature WHERE "bx_order_Номер" = bx_order_id AND fname = 'ИНН';
    SELECT digits_only(trim(both FROM fvalue)) INTO KPP FROM bx_order_feature WHERE "bx_order_Номер" = bx_order_id AND fname = 'КПП';

    SELECT fvalue INTO loc_email FROM bx_order_feature WHERE "bx_order_Номер" = bx_order_id AND fname = 'Контактный Email';
    SELECT fvalue INTO loc_email1 FROM bx_order_feature WHERE "bx_order_Номер" = bx_order_id AND fname = 'EMail';
    IF 'siteorders@kipspb.ru' <> loc_email1 AND loc_email <> loc_email1 THEN
        loc_email := loc_email1;
        RAISE NOTICE 'заменяем _контактный email_ на EMail';
    END IF;


    IF (INN IS NOT NULL) -- AND (KPP IS NOT NULL) -- юр. лицо, у ИП нет КПП
    THEN
        RAISE NOTICE 'Юр. лицо, ИНН=%, КПП=%. Ищем Работника с loc_buyer_id=%', INN, COALESCE(KPP, '_не_задан_'), loc_buyer_id;
        Firm := fn_find_enterprise(bx_order_id, INN, KPP);
        -- moved into fn_find_enterprise
        -- FirmCode := COALESCE(Firm."Код", create_firm(bx_order_id, INN, KPP));
        FirmCode := Firm."Код";
        new_emp := True;
        -- Ищем Работника с loc_buyer_id
        SELECT ec."КодРаботника", ec."Код", '-1'::VARCHAR AS "ЕАдрес" INTO emp 
        FROM emp_company ec
            JOIN "Предприятия" f ON f."Код"=ec."Код"
            WHERE ec.bx_buyer_id=loc_buyer_id
            AND f."ИНН"=INN;
        IF FOUND THEN
            new_emp := False;
            RAISE NOTICE 'такой покупатель с сайта для предприятия найден.';
            SELECT "ЕАдрес" INTO emp."ЕАдрес" FROM "Работники" WHERE "Работники"."КодРаботника" = emp."КодРаботника";
        ELSIF loc_email IS NOT NULL THEN -- ищем Работника по email
            RAISE NOTICE 'покупатель для предприятия=% по loc_buyer_id=% не найден. Ищем по email=%', FirmCode, loc_buyer_id, loc_email;
            BEGIN
                SELECT "КодРаботника", "Код", "ЕАдрес" INTO STRICT emp FROM "Работники" WHERE "Работники"."ЕАдрес" = loc_email AND "Код" = FirmCode;
                IF FOUND THEN
                    new_emp := False;
                    RAISE NOTICE 'Найден Работник по email=%. Регистрируем для предприятия=% в emp_company', loc_email, FirmCode;
                    INSERT INTO emp_company VALUES(FirmCode, emp."КодРаботника", loc_buyer_id)
                        ON CONFLICT ("Код", "КодРаботника") -- ON CONSTRAINT  "emp_company_PK" 
                        DO UPDATE SET bx_buyer_id = EXCLUDED.bx_buyer_id;
                END IF; -- найден Работник по email
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        RAISE NOTICE 'Работник с email=% не найден', loc_email;
                    WHEN TOO_MANY_ROWS THEN
                        new_emp := False;
                        RAISE NOTICE 'ТУПИК: найдено более одного Работника по email=% для Предприятия=%', loc_email, FirmCode;
                    WHEN OTHERS THEN
                        GET STACKED DIAGNOSTICS text_var1 = MESSAGE_TEXT, text_var2 = PG_EXCEPTION_DETAIL, text_var3 = PG_EXCEPTION_HINT;
                        RAISE NOTICE 'MESSAGE_TEXT=%, PG_EXCEPTION_DETAIL=%, PG_EXCEPTION_HINT=%', text_var1, text_var2, text_var3;
            END;
        END IF;

        IF new_emp THEN
            RAISE NOTICE 'Создаём Работника bx_order_id=%, FirmCode=%', bx_order_id, FirmCode;
            SELECT * FROM create_emp(bx_order_id, FirmCode) AS fileds("КодРаботника" integer, "Код" integer, "ЕАдрес" varchar) INTO emp;
        END IF;
    ELSIF (INN IS NULL) AND (KPP IS NULL) THEN -- физ. лицо
        RAISE NOTICE 'Физ. лицо. Ищем Работника с loc_buyer_id=%', loc_buyer_id;
        FirmCode := 223719;
        new_emp := True;
        SELECT ec."КодРаботника", ec."Код", '-1' AS "ЕАдрес" INTO emp 
        FROM emp_company ec
            WHERE ec.bx_buyer_id=loc_buyer_id
            AND ec."Код" = FirmCode;
        IF FOUND THEN -- такой покупатель с сайта уже зарегистрирован
            new_emp := False;
            RAISE NOTICE 'такой покупатель с сайта уже зарегистрирован';
            SELECT "ЕАдрес" INTO emp."ЕАдрес" FROM "Работники" WHERE "Работники"."КодРаботника" = emp."КодРаботника";
        ELSIF loc_email IS NOT NULL THEN -- ищем Работника по email
            RAISE NOTICE 'покупатель по loc_buyer_id=% не найден. Ищем по email=%', loc_buyer_id, loc_email;
            BEGIN
                SELECT "КодРаботника", "Код", "ЕАдрес" INTO STRICT emp FROM "Работники" WHERE "Работники"."ЕАдрес" = loc_email AND "Код" = 223719;
                IF FOUND THEN
                    new_emp := False;
                    RAISE NOTICE 'Найден Работник-физ.лицо по email=%. Регистрируем в emp_company', loc_email;
                    INSERT INTO emp_company VALUES(FirmCode, emp."КодРаботника", loc_buyer_id)
                        ON CONFLICT ("Код", "КодРаботника") -- ON CONSTRAINT  "emp_company_PK" 
                        DO UPDATE SET bx_buyer_id = EXCLUDED.bx_buyer_id;
                END IF; -- найден Работник по email
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        RAISE NOTICE 'Работник с email=% не найден', loc_email;
                    WHEN TOO_MANY_ROWS THEN
                        new_emp := False;
                        RAISE NOTICE 'ТУПИК: найдено более одного Работника-физ.лица по email=%', loc_email;
                    WHEN OTHERS THEN
                        GET STACKED DIAGNOSTICS text_var1 = MESSAGE_TEXT, text_var2 = PG_EXCEPTION_DETAIL, text_var3 = PG_EXCEPTION_HINT;
                        RAISE NOTICE 'MESSAGE_TEXT=%, PG_EXCEPTION_DETAIL=%, PG_EXCEPTION_HINT=%', text_var1, text_var2, text_var3;
            END;
        END IF;

        IF new_emp THEN
            RAISE NOTICE 'Создаём Работника-физ.лицо bx_order_id=%, FirmCode=%', bx_order_id, FirmCode;
            SELECT * FROM create_emp(bx_order_id, FirmCode) AS fileds("КодРаботника" integer, "Код" integer, "ЕАдрес" varchar) INTO emp;

        END IF;
    ELSIF (INN IS NULL) AND (KPP IS not NULL) THEN -- юр. лицо, неполная информация
        RAISE NOTICE 'Юр. лицо, неполная информация ИНН=_не_задан_, КПП=%', KPP;
    END IF; -- IF INN, KPP

    IF emp."ЕАдрес" IS NULL THEN -- delete this code ???
        UPDATE "Работники" SET "ЕАдрес" = loc_email WHERE bx_buyer_id = loc_buyer_id;
    END IF;

RAISE NOTICE 'Заполняем выходные параметры КодРаботника=%, Код=%, ЕАдрес=%', emp."КодРаботника", emp."Код", emp."ЕАдрес";
"out_КодРаботника" := emp."КодРаботника";
"out_Код" := emp."Код";
"out_ЕАдрес" := emp."ЕАдрес";
RETURN;
END

$function$;

ALTER FUNCTION arc_energo.get_emp(integer)
    OWNER TO arc_energo;
