CREATE OR REPLACE VIEW vw_import_or_dealers AS 
 SELECT k."���������",
    n."������",
    t1."����",
    p."�����������",
    s."�������������",
        CASE
            WHEN COALESCE(s."���������", false) THEN '+'::text
            ELSE NULL::text
        END AS "���",
    s."�������������",
    s."������",
    s."��������",
    s.nosinc_dm
   FROM "����������" s
     --LEFT JOIN vwsupcurrent v ON s."�������������" = v."�������������"
     LEFT JOIN "�����������" p ON s."���������" = p."���"
LEFT JOIN ( SELECT "�������������",
            '������'::text AS "����"
           FROM devmod.modifications
          WHERE modifications.version_num = 0) t1 ON s."�������������" = t1."�������������"
     JOIN "������������" n ON s."���������������" = n."���������������"
     JOIN "���������" k ON n."������������" = k."������������"
  WHERE COALESCE(s."����������", false) AND (s."���������" = 215878 OR COALESCE(s."���������", false)) AND s.stop IS NULL;

ALTER TABLE vw_import_or_dealers
  OWNER TO arc_energo;
