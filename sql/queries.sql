/* =====================================================================
   Projet 2 - Requêtes d'analyse commerciale
   Prérequis : create_tables.sql, dim_temps_population.sql, data.sql
   ===================================================================== */

USE BaseInventaire;
GO

-- ---------------------------------------------------------------------
-- 1. Indicateurs clés
-- ---------------------------------------------------------------------
SELECT SUM(montant_total)   AS chiffre_affaires,
       SUM(quantite_vendue) AS unites_vendues,
       COUNT(*)             AS nb_ventes,
       CAST(SUM(montant_total) / COUNT(*) AS DECIMAL(10,2)) AS panier_moyen
FROM dbo.vw_ventes;


-- ---------------------------------------------------------------------
-- 2. Évolution mensuelle du CA et variation vs mois précédent
-- ---------------------------------------------------------------------
WITH mensuel AS (
    SELECT annee_mois, MIN(libelle_mois) AS mois, SUM(montant_total) AS ca
    FROM dbo.vw_ventes
    GROUP BY annee_mois
)
SELECT mois, ca,
       LAG(ca) OVER (ORDER BY annee_mois) AS ca_mois_precedent,
       CAST(100.0 * (ca - LAG(ca) OVER (ORDER BY annee_mois))
            / NULLIF(LAG(ca) OVER (ORDER BY annee_mois), 0) AS DECIMAL(10,1)) AS variation_pct
FROM mensuel
ORDER BY annee_mois;


-- ---------------------------------------------------------------------
-- 3. Top 5 clients par chiffre d'affaires
-- ---------------------------------------------------------------------
SELECT TOP 5 client, segment, pays,
       SUM(montant_total) AS chiffre_affaires,
       COUNT(*)           AS nb_ventes
FROM dbo.vw_ventes
GROUP BY client, segment, pays
ORDER BY chiffre_affaires DESC;


-- ---------------------------------------------------------------------
-- 4. CA par fournisseur et par mois
--    (chaîne vente -> produit -> fournisseur : chaque vente n'est
--     comptée qu'une seule fois)
-- ---------------------------------------------------------------------
SELECT fournisseur, libelle_mois,
       SUM(montant_total) AS chiffre_affaires
FROM dbo.vw_ventes
GROUP BY fournisseur, libelle_mois, annee_mois
ORDER BY fournisseur, annee_mois;


-- ---------------------------------------------------------------------
-- 5. CA par segment client et par pays
-- ---------------------------------------------------------------------
SELECT segment, pays,
       SUM(montant_total) AS chiffre_affaires,
       CAST(100.0 * SUM(montant_total) / SUM(SUM(montant_total)) OVER () AS DECIMAL(5,1)) AS part_pct
FROM dbo.vw_ventes
GROUP BY segment, pays
ORDER BY chiffre_affaires DESC;


-- ---------------------------------------------------------------------
-- 6. Analyse de Pareto : quels produits font l'essentiel du CA ?
-- ---------------------------------------------------------------------
WITH ca_produit AS (
    SELECT produit, SUM(montant_total) AS ca
    FROM dbo.vw_ventes
    GROUP BY produit
)
SELECT produit, ca,
       CAST(100.0 * ca / SUM(ca) OVER () AS DECIMAL(5,1)) AS part_pct,
       CAST(100.0 * SUM(ca) OVER (ORDER BY ca DESC ROWS UNBOUNDED PRECEDING)
            / SUM(ca) OVER () AS DECIMAL(5,1)) AS part_cumulee_pct
FROM ca_produit
ORDER BY ca DESC;


-- ---------------------------------------------------------------------
-- 7. Priorités de réapprovisionnement : produits en alerte classés
--    par chiffre d'affaires généré (croise ventes et stock du projet 1)
-- ---------------------------------------------------------------------
SELECT s.produit, s.fournisseur,
       s.stock_actuel, s.seuil_reapprovisionnement, s.en_commande,
       COALESCE(v.ca, 0)  AS chiffre_affaires,
       COALESCE(v.qte, 0) AS unites_vendues
FROM dbo.vw_stock_actuel s
LEFT JOIN (
    SELECT produit_id, SUM(montant_total) AS ca, SUM(quantite_vendue) AS qte
    FROM dbo.fait_ventes
    GROUP BY produit_id
) v ON v.produit_id = s.id_produit
WHERE s.stock_actuel < s.seuil_reapprovisionnement
ORDER BY chiffre_affaires DESC;
