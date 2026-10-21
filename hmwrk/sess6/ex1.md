# Session 6 — Exercise 1: containerise a job, and prove it travels

LUBERNE Féliz — written as a group. The job is the course's `extract_orders.py`
(we had no lesson 3 extractor of our own yet), reading the connection string
and the table name from the environment. Everything is in `scriptes/l06/`.
Built on 2026-10-21 with Docker 29.7.2, on an Apple Silicon Mac.

## The table

| | Naive | Ours |
|---|---|---|
| Size | 2.19 GB | 623 MB |
| Rebuild after a code change | 48.9 s | 2.6 s |
| `whoami` | `root` | `extractor` |

The naive image was `FROM python:3.13`, `COPY . .`, then `pip install`. A blank
line added to the Python file changed the `COPY` layer, so the 30-second
`pip install` above it ran again. Once we copied `requirements.txt` and
installed before copying the code, the same blank line only rebuilt the last
layer: 19 times faster. The slim base took the size from 2.19 GB to 623 MB; of
those 623 MB, the base is 43 MB and the rest is pandas, pyarrow and psycopg.

## Our Dockerfile

```dockerfile
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
```

With a `.dockerignore` that keeps `.env`, `.env.*`, key files and `out/` out of
the build context.

## The leak

We put a `.env` with a fake password in the folder and built without a
`.dockerignore`:

```text
$ docker run --rm --entrypoint sh extractor:2026-10-21 -c 'cat /app/.env'
DATABASE_URL=postgresql://admin:FAKE-not-a-real-password@prod-db:5432/marketplace
```

With the `.dockerignore`, rebuilt:

```text
$ docker run --rm --entrypoint sh extractor:2026-10-21 -c 'cat /app/.env'
cat: /app/.env: No such file or directory
```

Had we pushed the first image, deleting it from Docker Hub would not have been
enough: anyone could have pulled it in the meantime, so we would have had to
treat the password as leaked, change it on the database, and push a clean
image.

## Mounted from

```text
44136fa355b3: Mounted from airbyte/manifest-server
```

Docker Hub already held that exact layer, with the same digest, in Airbyte's
public repository. Our Docker knew it because it had pulled Airbyte's images
for lesson 3, so instead of uploading the layer it asked Docker Hub to link it
from there. The ten other layers were uploaded. On the pull, the same layer
came back as `Already exists`, because Airbyte's images are still on the
laptop.

## The digests

After the push:

```text
2026-10-21: digest: sha256:a9e6cd62dfe039d29969922179e1c2d9d99055c16f5ae6df2ee046e464f3fe38
```

We then deleted both tags from the laptop (`Deleted: sha256:a9e6cd62…`, and
`docker images` found no extractor left), pulled it back (`Pull complete` on
each layer) and got:

```text
Digest: sha256:a9e6cd62dfe039d29969922179e1c2d9d99055c16f5ae6df2ee046e464f3fe38
```

They match, so what we ran at the end was exactly what we built: it read
`42859 rows -> /data/product.parquet` from the company database. That digest is
also the one of the build made with the `.dockerignore`, so the published
image is the clean one. (42,859 and not 42,858: the test product we added in
lesson 3's Airbyte exercise is still in the database.)

## Why a date and not `latest`

`latest` is a label that moves every time someone pushes, so a scheduler that
runs `latest` next month may run different code from what we tested today; a
date names one build, and the digest underneath it proves which.
