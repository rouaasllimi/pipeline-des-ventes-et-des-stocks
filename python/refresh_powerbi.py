import win32com.client as win32
import time
import os

chemin_pbix = r"-------------"

print("Ouverture de Power BI...")
app_powerbi = win32.gencache.EnsureDispatch('PowerBI.Application')
app_powerbi.Visible = True

print("Ouverture du rapport...")
rapport = app_powerbi.Workbooks.Open(chemin_pbix)

print("Actualisation de toutes les données...")
rapport.RefreshAll()

time.sleep(45)

print("Enregistrement du rapport...")
rapport.Save()

print("Fermeture de Power BI...")
rapport.Close()
app_powerbi.Quit()

print("Actualisation terminée avec succès.")