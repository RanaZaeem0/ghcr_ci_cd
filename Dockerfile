# ---------- Base Layer ----------
FROM python:3.9-slim AS base

# Disable Python buffering and .pyc files
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies (cached unless changed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libopenblas-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ---------- Dependencies Layer ----------
FROM base AS deps

# Copy only requirements (so cache isn’t invalidated by code changes)
COPY requirements.txt .

# Install dependencies using pip cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ---------- Final Application Layer ----------
FROM base AS final

WORKDIR /app

# Copy installed packages only (avoid stdlib duplication)
COPY --from=deps /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages

# Copy app source last (so code changes don’t rebuild deps)
COPY . .

# Create and switch to non-root user
RUN useradd -m appuser
USER appuser

EXPOSE 8000

# Lightweight healthcheck
HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["python", "app.py"]
