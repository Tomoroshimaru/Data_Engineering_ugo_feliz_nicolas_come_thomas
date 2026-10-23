# D3, D4, D5: a supported Python, pinned to a full version and a Debian release,
# matching the version requirements.txt was compiled for.
FROM python:3.12.12-slim-bookworm

# Logs straight to stdout, no .pyc files written at run time.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# D7: dependencies first, nothing else above them, so only a change to
# requirements.txt reinstalls them.
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# D2: a user with no privileges, created after the install.
RUN useradd --create-home --uid 10001 storefront
USER storefront

# D6: only the application code, nothing else from the folder.
COPY --chown=storefront backend/*.py ./

# D1: no .env. DATABASE_URL is passed at run time:
#   docker run -e DATABASE_URL=... storefront
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
