#!/bin/bash
set -e

# Train model if weights don't exist
if [ ! -f "saved_model/cityfix.pt" ]; then
    echo "========================================="
    echo "  No model found. Starting training..."
    echo "========================================="
    python train.py
    echo "Training complete!"
fi

echo "========================================="
echo "  Starting CityFix LLM on port 7860..."
echo "========================================="

# HuggingFace Spaces uses port 7860
exec uvicorn server:app --host 0.0.0.0 --port 7860
