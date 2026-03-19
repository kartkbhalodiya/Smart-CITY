FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all app files
COPY . .

# Create required directories
RUN mkdir -p saved_model data

# HuggingFace Spaces requires non-root user
RUN useradd -m appuser && chown -R appuser /app
USER appuser

# HuggingFace Spaces REQUIRES port 7860
EXPOSE 7860

CMD ["./start.sh"]
