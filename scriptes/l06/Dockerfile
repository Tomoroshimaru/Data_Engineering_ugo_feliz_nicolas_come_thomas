# Slim base, pinned to a full version: no build tools we do not need.
FROM python:3.13.16-slim

WORKDIR /app

# Dependencies first: this layer is rebuilt only when requirements.txt changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Created after the install, switched to before the code is copied.
RUN useradd --create-home --uid 1000 extractor
USER extractor

# Code last: a code change only rebuilds from here.
COPY --chown=extractor . .

CMD ["python", "extract_orders.py"]
