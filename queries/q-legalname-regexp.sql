SELECT  "Код"
       ,"Предприятие"
       , "ЮрНазвание"
--       , aname, lname, lname[2] l2
, TRIM(lname[1] || lname[3]) || ' ' || lname[2] As newname
FROM       
(SELECT "Код"
       ,"Предприятие"
       , "ЮрНазвание"
      -- , regexp_replace("ЮрНазвание", '["''«»“]*', '', 'g') AS aname
, regexp_matches(
      regexp_replace("ЮрНазвание", '["''«»“]*', '', 'g')
      , '(.*)(ООО|ПАО|ОАО|ЗАО|\mАО|АООТ|АОЗТ|ТОО)(.*)') AS lname
  FROM "Предприятия"
  WHERE "Код" IN (
253761
,253760
,253759
,253758
,253757
,253756
,253755
,253754
,253752
,253751
,253750
,253749
,253748
,253747
,253746
,253744
,253743
,253742
,253741
,253740
,253738
)
) as ln
