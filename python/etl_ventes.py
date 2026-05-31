"""
Script ETL avec prévention des doublons et archivage CSV
- Lit les ventes depuis new_sales.csv
- Vérifie si chaque vente existe déjà dans fait_ventes (tous les champs)
- Ignore les doublons, insère uniquement les nouvelles ventes
- Renomme le fichier CSV après traitement
- Exporte un CSV des stocks faibles quotidiennement
"""

import pyodbc
import pandas as pd
from datetime import date
import os
import shutil

# 1. CONNEXION À LA BASE DE DONNÉES

chaine_connexion = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost\\SQLEXPRESS;"
    "DATABASE=BaseInventaire;"
    "Trusted_Connection=yes;"
)
conn = pyodbc.connect(chaine_connexion)
curseur = conn.cursor()


# 2. LECTURE DU CSV

def lire_ventes_csv(chemin_csv):
    """Lit le fichier CSV et retourne une liste de tuples (produit_id, client_id, date_complete, quantite_vendue, prix_unitaire)"""
    if not os.path.exists(chemin_csv):
        print(f"Fichier introuvable : {chemin_csv}")
        return None
    df = pd.read_csv(chemin_csv)
    colonnes_requises = ['produit_id', 'client_id', 'date_complete', 'quantite_vendue', 'prix_unitaire']
    if not all(col in df.columns for col in colonnes_requises):
        print("Le CSV ne contient pas toutes les colonnes requises. Attendues : produit_id, client_id, date_complete, quantite_vendue, prix_unitaire")
        return None
    return list(df[colonnes_requises].itertuples(index=False, name=None))


# 3. VÉRIFICATION SI LA VENTE EXISTE DÉJÀ

def vente_existe(prod_id, client_id, date_vente, qte, prix):
    """Retourne True si une vente identique existe déjà dans fait_ventes"""
    requete = """
    SELECT COUNT(*) FROM fait_ventes
    WHERE produit_id = ? AND client_id = ? AND date_complete = ?
      AND quantite_vendue = ? AND prix_unitaire = ?
    """
    curseur.execute(requete, (prod_id, client_id, date_vente, qte, prix))
    compte = curseur.fetchone()[0]
    return compte > 0


# 4. INSERTION UNIQUEMENT DES NOUVELLES VENTES

def inserer_nouvelles_ventes(liste_ventes):
    """Insère les ventes non doublons dans fait_ventes et mouvements_stock"""
    insertion_fait = """
    INSERT INTO fait_ventes (produit_id, client_id, date_complete, quantite_vendue, prix_unitaire)
    VALUES (?, ?, ?, ?, ?)
    """
    insertion_mvt = """
    INSERT INTO mouvements_stock (id_produit, quantite_variation, type_mouvement, date_creation)
    VALUES (?, ?, 'VENTE', ?)
    """
    nb_nouvelles = 0
    nb_doublons = 0
    for vente in liste_ventes:
        prod_id, client_id, date_vente, qte, prix = vente
        if vente_existe(prod_id, client_id, date_vente, qte, prix):
            print(f"Doublon ignoré : Produit {prod_id}, Client {client_id}, Date {date_vente}, Quantité {qte}")
            nb_doublons += 1
            continue
        curseur.execute(insertion_fait, (prod_id, client_id, date_vente, qte, prix))
        curseur.execute(insertion_mvt, (prod_id, -qte, date_vente))
        nb_nouvelles += 1
    conn.commit()
    print(f"{nb_nouvelles} nouvelle(s) vente(s) insérée(s). {nb_doublons} doublon(s) ignoré(s).")
    return nb_nouvelles

# 5. ARCHIVAGE DU CSV APRÈS TRAITEMENT

def archiver_csv(chemin_csv):
    """Renomme le fichier CSV avec la date du jour pour éviter un retraitement"""
    if not os.path.exists(chemin_csv):
        return
    horodatage = date.today().strftime("%Y-%m-%d")
    nom_archive = f"traite_{horodatage}_{os.path.basename(chemin_csv)}"
    chemin_archive = os.path.join(os.path.dirname(chemin_csv), nom_archive)
    shutil.move(chemin_csv, chemin_archive)
    print(f"CSV archivé sous : {chemin_archive}")


# 6. RAPPORT DE STOCK FAIBLE (inchangé en logique)

def obtenir_stock_faible():
    """Calcule le stock actuel et retourne les produits sous le seuil de réapprovisionnement"""
    requete = """
    WITH stock_calc AS (
        SELECT 
            id_produit,
            SUM(CASE WHEN type_mouvement = 'ENTREE' THEN quantite_variation ELSE 0 END) 
            - SUM(CASE WHEN type_mouvement IN ('SORTIE','VENTE') THEN ABS(quantite_variation) ELSE 0 END) 
            AS stock_actuel
        FROM mouvements_stock
        GROUP BY id_produit
    )
    SELECT 
        p.nom AS produit_nom,
        s.stock_actuel,
        p.seuil_reapprovisionnement,
        f.nom AS fournisseur_nom,
        f.email_contact
    FROM produits p
    JOIN stock_calc s ON p.id = s.id_produit
    JOIN fournisseurs f ON p.id_fournisseur = f.id
    WHERE s.stock_actuel < p.seuil_reapprovisionnement
    ORDER BY s.stock_actuel ASC
    """
    return pd.read_sql(requete, conn)

def exporter_stock_faible_csv(df):
    """Exporte le DataFrame des stocks faibles dans un fichier CSV daté"""
    if df.empty:
        print("Aucun produit en stock faible aujourd'hui.")
        return
    nom_fichier = f"stock_faible_{date.today()}.csv"
    df.to_csv(nom_fichier, index=False, encoding='utf-8-sig')
    print(f"Fichier CSV d'alerte stock faible enregistré : {nom_fichier}")


# 7. EXÉCUTION PRINCIPALE

if __name__ == "__main__":
    fichier_csv = "new_sales.csv"   # Placez ce fichier dans le même dossier

    donnees_ventes = lire_ventes_csv(fichier_csv)
    if donnees_ventes:
        inserer_nouvelles_ventes(donnees_ventes)
        archiver_csv(fichier_csv)    # Évite de retraiter le même fichier

    df_stock_faible = obtenir_stock_faible()
    exporter_stock_faible_csv(df_stock_faible)

    curseur.close()
    conn.close()
    print("ETL terminé.")