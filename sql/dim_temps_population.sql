/* =====================================================================
   Remplissage de la dimension date (2024-01-01 -> 2027-12-31)
   Requête ensembliste (CTE récursive) : une seule instruction au lieu
   d'une boucle de 1 461 insertions. Relançable sans créer de doublons.
   ===================================================================== */

USE BaseInventaire;
GO

SET DATEFIRST 1;   -- la semaine commence le lundi (1 = lundi ... 7 = dimanche)

DECLARE @debut DATE = '2024-01-01';
DECLARE @fin   DATE = '2027-12-31';

WITH jours AS (
    SELECT @debut AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d) FROM jours WHERE d < @fin
)
INSERT INTO dbo.dim_temps
    (date_complete, annee, trimestre, mois, nom_mois, jour_mois,
     jour_semaine, nom_jour, est_weekend, annee_mois, libelle_mois)
SELECT
    d,
    YEAR(d),
    DATEPART(QUARTER, d),
    MONTH(d),
    CHOOSE(MONTH(d), N'Janvier', N'Février', N'Mars', N'Avril', N'Mai', N'Juin',
                     N'Juillet', N'Août', N'Septembre', N'Octobre', N'Novembre', N'Décembre'),
    DAY(d),
    DATEPART(WEEKDAY, d),
    CHOOSE(DATEPART(WEEKDAY, d), N'Lundi', N'Mardi', N'Mercredi', N'Jeudi',
                                 N'Vendredi', N'Samedi', N'Dimanche'),
    CASE WHEN DATEPART(WEEKDAY, d) IN (6, 7) THEN 1 ELSE 0 END,
    YEAR(d) * 100 + MONTH(d),
    CONCAT(CHOOSE(MONTH(d), N'Janvier', N'Février', N'Mars', N'Avril', N'Mai', N'Juin',
                            N'Juillet', N'Août', N'Septembre', N'Octobre', N'Novembre', N'Décembre'),
           N' ', YEAR(d))
FROM jours
WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_temps t WHERE t.date_complete = jours.d)
OPTION (MAXRECURSION 0);
GO

SELECT COUNT(*) AS nb_jours, MIN(date_complete) AS premier_jour, MAX(date_complete) AS dernier_jour
FROM dbo.dim_temps;   -- attendu : 1461 jours
GO
