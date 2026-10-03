@echo off
rem Pipeline quotidien : ETL des ventes + export de l'alerte stock.
rem A planifier avec le Planificateur de taches Windows.
rem Si "python" n'est pas dans le PATH, mettre son chemin complet ci-dessous.

cd /d "%~dp0"

echo [%date% %time%] Lancement de l'ETL...
python python\etl_ventes.py
if errorlevel 1 (
    echo [%date% %time%] ERREUR : l'ETL a echoue. Voir le dossier logs.
    exit /b 1
)

echo [%date% %time%] Pipeline termine.
exit /b 0
