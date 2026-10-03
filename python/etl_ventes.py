"""ETL quotidien des ventes.

1. Lit les nouvelles ventes dans data/new_sales.csv
2. Valide chaque ligne (produit, client, date, quantité, prix, doublon)
3. Insère les lignes valides dans fait_ventes ET mouvements_stock,
   dans UNE SEULE transaction (tout ou rien)
4. Écrit les lignes refusées dans data/rejets/ avec le motif du refus
5. Archive le fichier traité
6. Exporte la liste des produits à réapprovisionner (exports/)

Le code de sortie vaut 0 si tout s'est bien passé, 1 sinon
(utile pour le Planificateur de tâches et le fichier .bat).
"""
import logging
import shutil
import sys
from datetime import datetime

import pandas as pd
import pyodbc

import config

COLONNES = ["reference_vente", "produit_id", "client_id",
            "date_complete", "quantite_vendue", "prix_unitaire"]

log = logging.getLogger("etl_ventes")

SQL_ALERTE = f"""
    SELECT produit            AS [Produit],
           fournisseur        AS [Fournisseur],
           email_contact      AS [Email fournisseur],
           stock_actuel       AS [Stock actuel],
           en_commande        AS [Déjà commandé],
           seuil_reapprovisionnement AS [Seuil],
           {config.NIVEAU_CIBLE} * seuil_reapprovisionnement
               - (stock_actuel + en_commande) AS [Quantité à commander]
    FROM dbo.vw_stock_actuel
    WHERE stock_actuel + en_commande < seuil_reapprovisionnement
    ORDER BY stock_actuel ASC
"""


# --------------------------------------------------------------------------
# Journalisation
# --------------------------------------------------------------------------
def configurer_logs():
    config.DOSSIER_LOGS.mkdir(parents=True, exist_ok=True)
    fichier = config.DOSSIER_LOGS / f"etl_{datetime.now():%Y-%m-%d}.log"
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[logging.FileHandler(fichier, encoding="utf-8"), logging.StreamHandler()],
    )


# --------------------------------------------------------------------------
# Extraction
# --------------------------------------------------------------------------
def lire_csv(chemin):
    """Lit le CSV (séparateur , ou ; détecté automatiquement) sans rien convertir."""
    df = pd.read_csv(chemin, dtype=str, sep=None, engine="python", encoding="utf-8-sig")
    df.columns = [c.strip().lower() for c in df.columns]
    manquantes = [c for c in COLONNES if c not in df.columns]
    if manquantes:
        raise ValueError(f"Colonnes manquantes dans le CSV : {', '.join(manquantes)}")
    return df[COLONNES]


# --------------------------------------------------------------------------
# Validation (fonction pure : testable sans base de données)
# --------------------------------------------------------------------------
def valider(brut, produits, clients, date_min, date_max, refs_existantes):
    """Sépare les lignes en valides, rejetées (avec motif) et doublons ignorés.

    Un doublon (référence déjà en base ou répétée dans le fichier) n'est pas
    une erreur : il est ignoré, ce qui rend l'ETL rejouable sans risque.
    Renvoie (valides, rejets, nb_doublons).
    """
    df = brut.copy()
    for col in COLONNES:
        df[col] = df[col].str.strip()

    df["produit_id"] = pd.to_numeric(df["produit_id"], errors="coerce")
    df["client_id"] = pd.to_numeric(df["client_id"], errors="coerce")
    df["quantite_vendue"] = pd.to_numeric(df["quantite_vendue"], errors="coerce")
    df["prix_unitaire"] = pd.to_numeric(df["prix_unitaire"].str.replace(",", ".", regex=False),
                                        errors="coerce")
    df["date_complete"] = pd.to_datetime(df["date_complete"], format="%Y-%m-%d", errors="coerce")

    motif = pd.Series("", index=df.index)

    def marquer(masque, texte):
        motif[masque & (motif == "")] = texte

    ref_vide = df["reference_vente"].isna() | (df["reference_vente"] == "")
    marquer(ref_vide, "Référence de vente manquante")
    marquer(~ref_vide & df["reference_vente"].isin(list(refs_existantes)), "DOUBLON")
    marquer(~ref_vide & df.duplicated("reference_vente", keep="first"), "DOUBLON")
    marquer(~df["produit_id"].isin(list(produits)), "Produit inconnu")
    marquer(~df["client_id"].isin(list(clients)), "Client inconnu")
    marquer(df["date_complete"].isna()
            | (df["date_complete"] < pd.Timestamp(date_min))
            | (df["date_complete"] > pd.Timestamp(date_max)),
            "Date invalide ou hors calendrier (format attendu AAAA-MM-JJ)")
    marquer(df["quantite_vendue"].isna() | (df["quantite_vendue"] <= 0)
            | (df["quantite_vendue"] % 1 != 0), "Quantité invalide (entier > 0 attendu)")
    marquer(df["prix_unitaire"].isna() | (df["prix_unitaire"] < 0), "Prix invalide")

    est_doublon = motif == "DOUBLON"
    est_rejet = (motif != "") & ~est_doublon
    valides = df[motif == ""]
    rejets = brut[est_rejet].assign(motif=motif[est_rejet])
    return valides, rejets, int(est_doublon.sum())


# --------------------------------------------------------------------------
# Chargement
# --------------------------------------------------------------------------
def charger_referentiels(conn):
    cur = conn.cursor()
    cur.execute("SELECT id FROM dbo.produits")
    produits = {r[0] for r in cur.fetchall()}
    cur.execute("SELECT client_id FROM dbo.dim_client")
    clients = {r[0] for r in cur.fetchall()}
    cur.execute("SELECT MIN(date_complete), MAX(date_complete) FROM dbo.dim_temps")
    date_min, date_max = cur.fetchone()
    cur.execute("SELECT reference_vente FROM dbo.fait_ventes")
    refs = {r[0] for r in cur.fetchall()}
    return produits, clients, date_min, date_max, refs


def charger_ventes(conn, valides):
    """Insère chaque vente dans fait_ventes puis son mouvement de stock lié.

    Pas de commit ici : l'appelant valide (ou annule) l'ensemble du lot.
    """
    cur = conn.cursor()
    for v in valides.itertuples(index=False):
        date_vente = v.date_complete.date()
        qte = int(v.quantite_vendue)
        cur.execute(
            """INSERT INTO dbo.fait_ventes
                   (reference_vente, produit_id, client_id, date_complete, quantite_vendue, prix_unitaire)
               OUTPUT INSERTED.vente_id
               VALUES (?, ?, ?, ?, ?, ?)""",
            (v.reference_vente, int(v.produit_id), int(v.client_id),
             date_vente, qte, round(float(v.prix_unitaire), 2)),
        )
        id_vente = cur.fetchone()[0]
        cur.execute(
            """INSERT INTO dbo.mouvements_stock
                   (id_produit, quantite_variation, type_mouvement, date_creation, id_vente)
               VALUES (?, ?, 'VENTE', ?, ?)""",
            (int(v.produit_id), -qte, date_vente, id_vente),
        )
    return len(valides)


def verifier_stock_negatif(conn):
    cur = conn.cursor()
    cur.execute("SELECT produit, stock_actuel FROM dbo.vw_stock_actuel WHERE stock_actuel < 0")
    for produit, stock in cur.fetchall():
        log.warning("Stock négatif pour '%s' : %s (vérifier les ventes importées)", produit, stock)


# --------------------------------------------------------------------------
# Fichiers de sortie
# --------------------------------------------------------------------------
def exporter_rejets(rejets, nom_source):
    config.DOSSIER_REJETS.mkdir(parents=True, exist_ok=True)
    chemin = config.DOSSIER_REJETS / f"rejets_{datetime.now():%Y-%m-%d_%H%M%S}_{nom_source}"
    rejets.to_csv(chemin, index=False, sep=";", encoding="utf-8-sig")
    log.warning("%d ligne(s) rejetée(s) -> %s", len(rejets), chemin)


def archiver_csv(chemin):
    config.DOSSIER_ARCHIVES.mkdir(parents=True, exist_ok=True)
    cible = config.DOSSIER_ARCHIVES / f"traite_{datetime.now():%Y-%m-%d_%H%M%S}_{chemin.name}"
    shutil.move(str(chemin), str(cible))
    log.info("CSV archivé : %s", cible)


def exporter_stock_faible(conn):
    cur = conn.cursor()
    cur.execute(SQL_ALERTE)
    colonnes = [c[0] for c in cur.description]
    lignes = [tuple(r) for r in cur.fetchall()]
    if not lignes:
        log.info("Aucun produit à réapprovisionner.")
        return
    config.DOSSIER_EXPORTS.mkdir(parents=True, exist_ok=True)
    chemin = config.DOSSIER_EXPORTS / f"stock_faible_{datetime.now():%Y-%m-%d}.csv"
    pd.DataFrame(lignes, columns=colonnes).to_csv(chemin, index=False, sep=";", encoding="utf-8-sig")
    log.info("Alerte stock faible : %d produit(s) -> %s", len(lignes), chemin)


# --------------------------------------------------------------------------
# Programme principal
# --------------------------------------------------------------------------
def main():
    configurer_logs()
    log.info("Démarrage de l'ETL")
    conn = pyodbc.connect(config.CONN_STR)
    try:
        fichier = config.FICHIER_VENTES
        if fichier.exists():
            brut = lire_csv(fichier)
            log.info("%d ligne(s) lues dans %s", len(brut), fichier.name)

            valides, rejets, nb_doublons = valider(brut, *charger_referentiels(conn))
            nb_inserees = charger_ventes(conn, valides)
            conn.commit()   # le lot est validé en une seule fois
            log.info("%d vente(s) insérée(s), %d doublon(s) ignoré(s), %d ligne(s) rejetée(s)",
                     nb_inserees, nb_doublons, len(rejets))

            if len(rejets):
                exporter_rejets(rejets, fichier.name)
            archiver_csv(fichier)
            verifier_stock_negatif(conn)
        else:
            log.info("Aucun fichier %s à traiter", fichier.name)

        exporter_stock_faible(conn)
        log.info("ETL terminé")
        return 0
    except Exception:
        conn.rollback()   # rien n'est enregistré si une erreur survient
        log.exception("Échec de l'ETL : aucune vente n'a été enregistrée")
        return 1
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
