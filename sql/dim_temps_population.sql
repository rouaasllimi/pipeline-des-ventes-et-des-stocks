
SET DATEFIRST 1;


-- Declare a variable for the start date 
DECLARE @start_date DATE = '2024-01-01';
-- Declare a variable for the end date 
DECLARE @end_date DATE = '2027-12-31';


WHILE @start_date <= @end_date
BEGIN

    INSERT INTO dim_temps (date_complete, annee, trimestre, mois, nom_mois, jour_mois, jour_semaine, nom_jour, est_weekend)
    VALUES (
   
        @start_date,
     
        YEAR(@start_date),
      
        DATEPART(QUARTER, @start_date),
     
        MONTH(@start_date),
        
        CASE MONTH(@start_date)
            WHEN 1 THEN 'Janvier' WHEN 2 THEN 'Février' WHEN 3 THEN 'Mars'
            WHEN 4 THEN 'Avril'   WHEN 5 THEN 'Mai'     WHEN 6 THEN 'Juin'
            WHEN 7 THEN 'Juillet' WHEN 8 THEN 'Août'    WHEN 9 THEN 'Septembre'
            WHEN 10 THEN 'Octobre' WHEN 11 THEN 'Novembre' WHEN 12 THEN 'Décembre'
        END,
        
        DAY(@start_date),
       
        DATEPART(WEEKDAY, @start_date),
       
        CASE DATEPART(WEEKDAY, @start_date)
            WHEN 1 THEN 'Lundi'    WHEN 2 THEN 'Mardi'   WHEN 3 THEN 'Mercredi'
            WHEN 4 THEN 'Jeudi'    WHEN 5 THEN 'Vendredi' WHEN 6 THEN 'Samedi'
            WHEN 7 THEN 'Dimanche'
        END,
     
        CASE WHEN DATEPART(WEEKDAY, @start_date) IN (6,7) THEN 1 ELSE 0 END
    );
   
    SET @start_date = DATEADD(DAY, 1, @start_date);
END;
