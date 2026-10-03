# 📈 Pipeline ETL et tableau de bord des ventes et des stocks

Pipeline de données qui importe des ventes quotidiennes depuis un fichier CSV, les contrôle, met à jour le stock, génère l'alerte de réapprovisionnement et alimente un tableau de bord Power BI.

> **Ce projet prolonge le [Inventaire_management_system] : il réutilise sa base `BaseInventaire` (produits, fournisseurs, mouvements de stock) et y ajoute un entrepôt de ventes en schéma en étoile.



---

## Architecture

```
new_sales.csv ──► etl_ventes.py ──► fait_ventes ──► Power BI (analyse des ventes)
 (ventes du jour)  ├─ validation        │
                   ├─ rejets (CSV)      └─► mouvements_stock ──► vw_stock_actuel ──► Power BI (stock)
                   ├─ archivage                                        │
                   └─ alerte stock ◄───────────────────────────────────┘
                      (exports/stock_faible_AAAA-MM-JJ.csv)
```

---

## Fonctionnalités

- **Entrepôt de données en étoile** : table de faits `fait_ventes`, dimensions `dim_temps` et `dim_client`, produits et fournisseurs issus du projet 1
- **ETL Python** avec contrôle qualité : produit/client inconnu, date invalide, quantité ou prix incohérent, doublons
- **Import transactionnel** : toutes les ventes d'un fichier sont enregistrées, ou aucune
- **Traçabilité** : chaque vente importée crée un mouvement de stock lié (`mouvements_stock.id_vente`)
- **Rejets documentés** : les lignes refusées sont exportées avec le motif du refus
- **Alerte de stock faible** quotidienne en CSV, qui tient compte des commandes déjà en cours
- **Journalisation** dans `logs/` et code de retour exploitable par le Planificateur de tâches
- **Tableau de bord Power BI** : évolution du CA, top clients, état des stocks, CA par fournisseur et par mois

---

## Modèle de données

```
dim_temps (date_complete PK) ──┐
                               ├──< fait_ventes >── produits ── fournisseurs   (projet 1)
dim_client (client_id PK) ─────┘        │
                                        └──< mouvements_stock (id_vente)
```

| Table | Rôle |

| `fait_ventes` | Une ligne par vente : produit, client, date, quantité, prix au moment de la vente, montant (colonne calculée) |
| `dim_temps` | Calendrier 2024-2027 (année, trimestre, mois, jour, week-end, libellé de mois pour le tri) |
| `dim_client` | Clients avec segment (Grand compte, PME, E-commerce, Marketplace) et pays |
| `vw_ventes` | Vue qui joint les ventes à leurs axes d'analyse (utilisée par `queries.sql`) |

---

## Contrôle qualité et idempotence

| Cas | Traitement |

| Référence de vente déjà en base ou répétée dans le fichier | **Doublon ignoré** (le fichier peut être rejoué sans risque) |
| Produit ou client inconnu | Ligne **rejetée** |
| Date invalide, hors calendrier ou mal formatée | Ligne **rejetée** |
| Quantité non entière ou ≤ 0, prix négatif ou illisible | Ligne **rejetée** |
| Erreur technique en cours d'import | **Rollback** : aucune vente n'est enregistrée |
| Stock négatif après import | **Avertissement** dans le journal |

L'unicité est garantie par la base elle-même (`UNIQUE` sur `reference_vente`), pas seulement par le script. Les doublons sont détectés par une **clé naturelle** (numéro de facture / ligne de commande) plutôt que par comparaison de tous les champs, qui aurait écarté à tort deux ventes légitimes identiques.

---

## Technologies

- **Base de données** : Microsoft SQL Server (T‑SQL : CTE récursive, fonctions de fenêtrage, vues, contraintes)
- **ETL** : Python 3 (`pandas`, `pyodbc`)
- **Business Intelligence** : Power BI Desktop (modèle en étoile, DAX)
- **Ordonnancement** : Planificateur de tâches Windows

---

## Structure du projet

```
projet2_ventes/
├── sql/
│   ├── create_tables.sql           # Dimensions, table de faits, lien stock, vue vw_ventes
│   ├── dim_temps_population.sql    # Calendrier 2024-2027 (requête ensembliste)
│   ├── data.sql                    # Clients et historique de ventes de test
│   └── queries.sql                 # 7 requêtes d'analyse commerciale
├── python/
│   ├── config.py                   # Configuration (variables d'environnement)
│   ├── etl_ventes.py               # ETL : validation, import transactionnel, alerte
│   └── requirements.txt
├── data/
│   └── new_sales_exemple.csv       # Modèle de fichier d'entrée
├── docs/
│   └── dashboard_screenshot.png
├── dashboard/
│   └── Ventes_Stocks.pbix
├── pipeline_quotidien.bat          # Lance l'ETL (à planifier)
├── .env.example
└── README.md
```

---

## Installation

### Prérequis

- Le **projet 1 installé** (base `BaseInventaire` avec ses tables et la vue `vw_stock_actuel`)
- Python 3.9+ et l'[ODBC Driver 17 for SQL Server](https://learn.microsoft.com/fr-fr/sql/connect/odbc/download-odbc-driver-for-sql-server)
- Power BI Desktop (pour ouvrir le tableau de bord)

### 1. Base de données

Dans SSMS, exécuter dans cet ordre :

1. `sql/create_tables.sql`
2. `sql/dim_temps_population.sql` (attendu : 1 461 jours)
3. `sql/data.sql` (attendu : **1 793,89 €** de CA et **194** unités)

> Si vous relancez le script du projet 1, il supprime aussi `fait_ventes` : réexécutez ensuite les trois scripts ci-dessus.

### 2. Python

```bash
pip install -r python/requirements.txt
```

Copier `.env.example` en `.env` et adapter le nom du serveur si besoin.

---

## Utilisation

### Format du fichier d'entrée

Déposer un fichier `data/new_sales.csv` (voir `data/new_sales_exemple.csv`) avec ces colonnes :

| Colonne | Description |
|---|---|
| `reference_vente` | Identifiant unique de la vente (n° de facture ou de ligne) |
| `produit_id` | Identifiant du produit (table `produits`) |
| `client_id` | Identifiant du client (table `dim_client`) |
| `date_complete` | Date de la vente, format `AAAA-MM-JJ` |
| `quantite_vendue` | Entier strictement positif |
| `prix_unitaire` | Prix de vente (le point ou la virgule sont acceptés) |

Les séparateurs `,` et `;` sont détectés automatiquement.

### Lancer le pipeline

```bash
python python/etl_ventes.py
```
ou double-cliquer sur `pipeline_quotidien.bat`. Après exécution :

- les ventes valides sont dans `fait_ventes` et `mouvements_stock`
- le CSV traité est déplacé dans `data/archives/`
- les lignes refusées sont dans `data/rejets/`
- l'alerte est dans `exports/stock_faible_AAAA-MM-JJ.csv`
- le détail est dans `logs/etl_AAAA-MM-JJ.log`

### Planification quotidienne

Planificateur de tâches Windows → Créer une tâche de base → déclencheur quotidien (ex. 8 h 00) → action « Démarrer un programme » → `pipeline_quotidien.bat`. Un code de retour 1 signale l'échec de l'ETL.

---

## Tableau de bord Power BI

Le fichier `dashboard/Ventes_Stocks.pbix` se connecte à la base `BaseInventaire` en **mode Import** avec un modèle en étoile : `fait_ventes` au centre, reliée à `dim_temps`, `dim_client` et `vw_stock_actuel` (produits et fournisseurs).

Il présente :

- **Cartes** : chiffre d'affaires, quantité vendue, stock moyen
- **Courbe** : évolution du CA par mois
- **Barres** : top 5 des clients par CA
- **Tableau** : stock, seuil et indicateur d'alerte par produit
- **Matrice** : CA par fournisseur et par mois

Après un import de ventes, cliquer sur **Actualiser** dans Power BI Desktop pour recharger les données.

---

## Limites et pistes d'amélioration

- **Actualisation de Power BI** : en Desktop elle est manuelle. En production, publier le rapport sur le **service Power BI** avec une **passerelle de données** pour planifier l'actualisation automatique après l'ETL.
- Chargement incrémental et import en masse (`executemany`, table de transit) pour de gros volumes
- Tests unitaires de la fonction `valider` (déjà isolée de la base pour s'y prêter)
- Dimension produit dédiée avec historique des prix
- Notification par email en cas d'échec de l'ETL
