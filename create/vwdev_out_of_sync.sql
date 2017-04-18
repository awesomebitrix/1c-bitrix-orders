CREATE OR REPLACE VIEW vwdev_out_of_sync AS 
 SELECT v."���������",
    v."������",
    v."����",
    v."�����������",
    v."�������������",
    v."���",
    v."�������������",
    v.nosinc_dm
   FROM vw_import_or_dealers v
     LEFT JOIN ( SELECT modifications."�������������" AS ks
           FROM modifications
          WHERE modifications.version_num = 1 AND NOT modifications."�������������" IS NULL
        UNION
         SELECT modif_ks_nosinc."�������������"
           FROM modif_ks_nosinc
          WHERE modif_ks_nosinc.version_num = 1) t1 ON v."�������������" = t1.ks
  WHERE NOT COALESCE(v.nosinc_dm, false) AND t1.ks IS NULL;

ALTER TABLE vwdev_out_of_sync
  OWNER TO arc_energo;