CREATE TABLE dim_temps (
    date_complete DATE PRIMARY KEY,
    annee INT,
    trimestre INT,
    mois INT,
    nom_mois NVARCHAR(20),
    jour_mois INT,
    jour_semaine INT,
    nom_jour NVARCHAR(20),
    est_weekend BIT
);
CREATE TABLE dim_client (
    client_id INT IDENTITY(1,1) PRIMARY KEY,
    code_client NVARCHAR(50) UNIQUE,
    nom_complet NVARCHAR(200),
    email NVARCHAR(200),
    segment NVARCHAR(50),
    date_acquisition DATE,
    pays NVARCHAR(100)
);
CREATE TABLE fait_ventes (
    vente_id INT IDENTITY(1,1) PRIMARY KEY,
    produit_id INT NOT NULL REFERENCES produits(id),
    client_id INT NOT NULL REFERENCES dim_client(client_id),
    date_complete DATE NOT NULL REFERENCES dim_temps(date_complete),
    quantite_vendue INT NOT NULL CHECK (quantite_vendue > 0),
    prix_unitaire DECIMAL(10,2) NOT NULL,
    montant_total AS (quantite_vendue * prix_unitaire) PERSISTED
);