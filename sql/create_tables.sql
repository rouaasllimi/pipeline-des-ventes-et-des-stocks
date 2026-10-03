/* =====================================================================
   Projet 2 - Entrepôt de ventes (schéma en étoile)
   Prérequis : le projet 1 doit être installé (tables produits,
   fournisseurs, mouvements_stock et vue vw_stock_actuel).

   Ce script peut être relancé : il recrée les tables du projet 2.
   ATTENTION : fait_ventes, dim_client et dim_temps sont vidées.
   ===================================================================== */

USE BaseInventaire;
GO

-- ---------------------------------------------------------------------
-- 0. Nettoyage
-- ---------------------------------------------------------------------
IF OBJECT_ID('dbo.FK_mouvements_vente', 'F') IS NOT NULL
    ALTER TABLE dbo.mouvements_stock DROP CONSTRAINT FK_mouvements_vente;
GO
DROP VIEW  IF EXISTS dbo.vw_ventes;
DROP TABLE IF EXISTS dbo.fait_ventes;
DROP TABLE IF EXISTS dbo.dim_client;
DROP TABLE IF EXISTS dbo.dim_temps;
GO

-- ---------------------------------------------------------------------
-- 1. Dimensions
-- ---------------------------------------------------------------------
CREATE TABLE dbo.dim_temps (
    date_complete DATE PRIMARY KEY,
    annee         INT NOT NULL,
    trimestre     INT NOT NULL,
    mois          INT NOT NULL,
    nom_mois      NVARCHAR(20) NOT NULL,
    jour_mois     INT NOT NULL,
    jour_semaine  INT NOT NULL,        -- 1 = lundi ... 7 = dimanche
    nom_jour      NVARCHAR(20) NOT NULL,
    est_weekend   BIT NOT NULL,
    annee_mois    INT NOT NULL,        -- ex. 202405 : sert à trier les mois
    libelle_mois  NVARCHAR(30) NOT NULL -- ex. 'Mai 2024' : sert à l'affichage
);

CREATE TABLE dbo.dim_client (
    client_id        INT IDENTITY(1,1) PRIMARY KEY,
    code_client      NVARCHAR(50)  NOT NULL UNIQUE,
    nom_complet      NVARCHAR(200) NOT NULL,
    email            NVARCHAR(200),
    segment          NVARCHAR(50)  NOT NULL
                     CHECK (segment IN ('Grand compte', 'PME', 'E-commerce', 'Marketplace')),
    date_acquisition DATE,
    pays             NVARCHAR(100)
);
GO

-- ---------------------------------------------------------------------
-- 2. Table de faits
--    reference_vente = clé naturelle (n° de facture / ligne de commande).
--    La contrainte UNIQUE garantit qu'une même vente ne peut pas être
--    importée deux fois, même si le script est relancé.
-- ---------------------------------------------------------------------
CREATE TABLE dbo.fait_ventes (
    vente_id        INT IDENTITY(1,1) PRIMARY KEY,
    reference_vente NVARCHAR(50) NOT NULL UNIQUE,
    produit_id      INT NOT NULL REFERENCES dbo.produits(id),
    client_id       INT NOT NULL REFERENCES dbo.dim_client(client_id),
    date_complete   DATE NOT NULL REFERENCES dbo.dim_temps(date_complete),
    quantite_vendue INT NOT NULL CHECK (quantite_vendue > 0),
    prix_unitaire   DECIMAL(10,2) NOT NULL CHECK (prix_unitaire >= 0),  -- prix au moment de la vente
    montant_total   AS (quantite_vendue * prix_unitaire) PERSISTED
);

CREATE INDEX IX_ventes_date    ON dbo.fait_ventes (date_complete) INCLUDE (quantite_vendue, prix_unitaire);
CREATE INDEX IX_ventes_client  ON dbo.fait_ventes (client_id);
CREATE INDEX IX_ventes_produit ON dbo.fait_ventes (produit_id);
GO

-- ---------------------------------------------------------------------
-- 3. Lien vente <-> mouvement de stock (traçabilité)
--    Chaque vente importée par l'ETL crée un mouvement VENTE qui référence
--    la ligne de fait_ventes. Les ventes historiques (data.sql) n'ont
--    pas de mouvement : elles datent d'avant le suivi de stock.
-- ---------------------------------------------------------------------
IF COL_LENGTH('dbo.mouvements_stock', 'id_vente') IS NULL
    ALTER TABLE dbo.mouvements_stock ADD id_vente INT NULL;
GO
ALTER TABLE dbo.mouvements_stock
    ADD CONSTRAINT FK_mouvements_vente FOREIGN KEY (id_vente) REFERENCES dbo.fait_ventes(vente_id);
GO

-- ---------------------------------------------------------------------
-- 4. Vue d'analyse : ventes enrichies (produit, fournisseur, client, date)
-- ---------------------------------------------------------------------
CREATE VIEW dbo.vw_ventes AS
SELECT
    v.vente_id, v.reference_vente,
    v.date_complete, t.annee, t.trimestre, t.mois, t.annee_mois, t.libelle_mois,
    t.nom_jour, t.est_weekend,
    v.client_id, c.nom_complet AS client, c.segment, c.pays,
    v.produit_id, p.nom AS produit, p.sku,
    f.id AS fournisseur_id, f.nom AS fournisseur,
    v.quantite_vendue, v.prix_unitaire, v.montant_total
FROM dbo.fait_ventes v
JOIN dbo.dim_temps    t ON t.date_complete = v.date_complete
JOIN dbo.dim_client   c ON c.client_id     = v.client_id
JOIN dbo.produits     p ON p.id            = v.produit_id
JOIN dbo.fournisseurs f ON f.id            = p.id_fournisseur;
GO
