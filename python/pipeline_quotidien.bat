@echo off

cd /d "%~dp0"

echo Running ETL...
python etl_sales.py

echo ETL done. Waiting 10 seconds before refreshing Power BI...
timeout /t 10

echo Refreshing Power BI...
python refresh_powerbi.py

echo Done.
pause