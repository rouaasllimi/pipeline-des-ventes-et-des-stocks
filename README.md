# Tableau de bord automatisé des ventes et des stocks

## Vue d’ensemble

Ce projet construit un pipeline entièrement automatisé qui ingère des ventes quotidiennes, met à jour les niveaux de stock, génère des alertes de réapprovisionnement et rafraîchit un tableau de bord Power BI – le tout sans intervention manuelle. Il illustre la conception de bases de données, le développement ETL, l’automatisation et la business intelligence.

## Fonctionnalités

- Base de données relationnelle avec un schéma en étoile (dimensions : date, client, produit, fournisseur ; fait : ventes)
- Script Python ETL qui lit les ventes depuis un fichier CSV, évite les doublons et enregistre les mouvements de stock
- Exécution quotidienne automatisée via le Planificateur de tâches Windows
- Export d’un rapport CSV des articles en stock faible
- Tableau de bord Power BI montrant les tendances des ventes, les meilleurs clients, les alertes stock et une matrice fournisseur / mois
- Rafraîchissement automatique de Power BI après l’ETL (via COM automation)

## Technologies utilisées

- **Base de données** : Microsoft SQL Server (T-SQL)
- **ETL** : Python (pandas, pyodbc, pywin32)
- **Business Intelligence** : Power BI Desktop
- **Ordonnancement** : Planificateur de tâches Windows
- **Gestion de version** : Git / GitHub

## Structure du projet

```
sales-inventory-pipeline/
├── sql/
│   ├── create_tables.sql          # Toutes les instructions CREATE TABLE
│   ├── dim_temps_populate.sql     # Remplissage de la dimension date (2024-2027)
│   └── sample_data.sql            # Produits, fournisseurs, clients, stock initial
├── python/
│   ├── etl_sales.py               # Script ETL principal (CSV avec anti-doublon)
│   ├── refresh_powerbi.py         # Ouvre le .pbix, rafraîchit, sauvegarde et ferme
│   └── daily_pipeline.bat         # Fichier batch pour exécuter ETL puis Power BI
├── powerbi/
│   └── dashboard.pbix             # Rapport Power BI (ou captures dans /docs)
├── docs/
│   ├── dashboard_screenshot.png
│   └── low_stock_sample.csv
├── requirements.txt               # Dépendances Python
└── README.md
```

## Instructions d’installation

### 1. Base de données

- Installez SQL Server (Express fonctionne) et SQL Server Management Studio (SSMS).
- Exécutez `sql/create_tables.sql` pour créer la base `BaseInventaire` et toutes les tables.
- Exécutez `sql/dim_temps_populate.sql` pour remplir la dimension date (2024-2027).
- Exécutez `sql/sample_data.sql` pour insérer les produits, fournisseurs, clients et mouvements initiaux.

### 2. Environnement Python

- Téléchargez et installez WinPython (ou toute distribution Python 3.13+).
- Installez les paquets requis :

```cmd
pip install pandas pyodbc pywin32
```

- Adaptez la chaîne de connexion dans `etl_sales.py` si nécessaire (nom du serveur, authentification).

### 3. Rapport Power BI

- Ouvrez `powerbi/dashboard.pbix` dans Power BI Desktop.
- Changez la source de données pour pointer vers votre base `BaseInventaire`.
- Si besoin, modifiez la variable `pbix_path` dans `refresh_powerbi.py` avec le chemin vers votre fichier `.pbix`.

### 4. Automatisation

- Placez les trois scripts Python (`etl_sales.py`, `refresh_powerbi.py`) et le fichier batch (`daily_pipeline.bat`) dans le même dossier.
- Modifiez `daily_pipeline.bat` pour utiliser le bon chemin vers `python.exe` s’il n’est pas dans votre PATH.
- Créez une tâche dans le Planificateur de tâches Windows qui exécute `daily_pipeline.bat` chaque matin à l’heure souhaitée (par exemple 8h00).

### 5. Utilisation

- Placez un fichier `new_sales.csv` dans le même dossier avec les colonnes suivantes :  
  `produit_id, client_id, date_complete, quantite_vendue, prix_unitaire`
- Testez manuellement le batch : double-cliquez sur `daily_pipeline.bat`.
- Après une exécution réussie, le CSV des stocks faibles apparaît et le rapport Power BI est automatiquement rafraîchi.

## Fonctionnement du script ETL

- Lit les ventes depuis `new_sales.csv`.
- Pour chaque ligne, vérifie si une vente identique existe déjà dans `fait_ventes` (prévention des doublons).
- Insère uniquement les nouvelles ventes dans la table de faits et une ligne `VENTE` correspondante dans `mouvements_stock` (quantité négative).
- Après traitement, renomme le fichier CSV en `processed_YYYY-MM-DD_new_sales.csv` pour éviter un nouveau traitement.
- Calcule les niveaux de stock actuels et exporte un CSV des produits dont le stock est inférieur au seuil de réapprovisionnement.

## Tableau de bord Power BI

Le tableau de bord contient :

- **Cartes** : Total des ventes, quantité vendue, stock moyen
- **Graphique linéaire** : Évolution des ventes dans le temps (hiérarchie de dates)
- **Graphique à barres** : Top 5 des clients par chiffre d’affaires
- **Tableau** : Stock produit, seuil, et indicateur alerte (rouge/vert)
- **Matrice** : Ventes par fournisseur et par mois

## Exemple de CSV des stocks faibles

```
produit_nom,stock_actuel,seuil_reapprovisionnement,fournisseur_nom,email_contact
"Widget A",3,15,"Global Supplies","orders@globalsupplies.com"
"Sensor Pro X",5,12,"Metro Wholesale","sales@metrowholesale.com"
```


## Licence

Ce projet est destiné à un portfolio. Vous êtes libre de l’utiliser et de l’adapter avec mention de l’auteur.