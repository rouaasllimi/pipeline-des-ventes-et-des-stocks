"""Configuration du pipeline ETL.

Les paramètres sensibles ou propres à la machine viennent de variables
d'environnement (ou d'un fichier .env si python-dotenv est installé).
"""
import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:  # python-dotenv est optionnel
    pass

# --- Base de données (authentification Windows) ---
DB_DRIVER = os.getenv("DB_DRIVER", "ODBC Driver 17 for SQL Server")
DB_SERVER = os.getenv("DB_SERVER", r"localhost\SQLEXPRESS")
DB_NAME = os.getenv("DB_NAME", "BaseInventaire1")

CONN_STR = (
    f"DRIVER={{{DB_DRIVER}}};"
    f"SERVER={DB_SERVER};"
    f"DATABASE={DB_NAME};"
    "Trusted_Connection=yes;"
)

# --- Dossiers (chemins relatifs à la racine du projet, donc indépendants
#     du dossier depuis lequel le script est lancé, ex. Planificateur de tâches) ---
RACINE = Path(__file__).resolve().parent.parent
FICHIER_VENTES = Path(os.getenv("FICHIER_VENTES", RACINE / "data" / "new_sales.csv"))
DOSSIER_ARCHIVES = RACINE / "data" / "archives"
DOSSIER_REJETS = RACINE / "data" / "rejets"
DOSSIER_EXPORTS = RACINE / "exports"
DOSSIER_LOGS = RACINE / "logs"

# --- Règle de réapprovisionnement (identique au projet 1) ---
NIVEAU_CIBLE = 2
