@echo off
echo ============================================
echo  CityFix LLM - Setup and Train
echo ============================================

echo [1/4] Creating virtual environment...
python -m venv venv
call venv\Scripts\activate

echo [2/4] Installing dependencies...
pip install -r requirements.txt

echo [3/4] Preparing training data...
python data\prepare_data.py

echo [4/4] Training model (takes 2-5 minutes)...
python train.py

echo.
echo ============================================
echo  Training complete! Start server with:
echo  uvicorn server:app --host 0.0.0.0 --port 8001
echo ============================================
pause
