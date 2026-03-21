@echo off
echo Starting CityFix LLM Server...
cd cityfix_llm
echo Running on http://localhost:8008
..\.venv\Scripts\python.exe -m uvicorn server:app --host 0.0.0.0 --port 8008
pause
