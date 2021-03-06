-- DROP FUNCTION arc_energo.billno_seqs_gen();

CREATE OR REPLACE FUNCTION arc_energo.billno_seqs_gen()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
sql_str TEXT;
BEGIN
	FOR sql_str IN 
	    SELECT
	       format('CREATE SEQUENCE IF NOT EXISTS billno_%s_%s_seq;', bc_list."Менеджер", extract(Year from now())) 
           FROM (SELECT "Менеджер" FROM vwbillcreator UNION SELECT 66) bc_list
	LOOP
	   RAISE NOTICE 'sql_str=%', sql_str;
	   EXECUTE sql_str;
    END LOOP; 
END;
$function$
