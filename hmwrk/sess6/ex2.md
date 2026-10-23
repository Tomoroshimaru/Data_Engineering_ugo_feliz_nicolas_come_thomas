# Session 6 — Exercise 2: critique a real Dockerfile

LUBERNE Féliz — written as a group. We copied the storefront backend and the
original Dockerfile from the company repository into `scriptes/l06/ex2/`, added
a `.env` holding a fake production password, and built three versions: the
original, the original with only its base image changed, and our rewrite.

```dockerfile
1  FROM python:3.9-slim
2  WORKDIR /app
3  COPY .env .
4  COPY backend/requirements.txt ./
5  RUN pip install --no-cache-dir -r requirements.txt
6  COPY backend /app
7  CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## 1. The defects, ranked by what they cost

**D1. The production password is baked into the image (line 3).** `COPY .env .`
puts the database password in its own layer. `docker history` shows it
(`COPY .env . 12.3kB`), and `cat /app/.env` prints it in clear. It ranks first
because it is the only one we cannot fix once the image has been pushed: anyone
who pulled it keeps it, and deleting the tag does not delete the copies. The
only remedy is to treat the password as leaked and change it on the database.
And it bought nothing: the app reads `DATABASE_URL` from the environment
(`os.environ["DATABASE_URL"]` in `database.py`) and never opens that file.

**D2. The web server runs as root (no `USER` anywhere).** `whoami` prints
`root`. The storefront API faces the internet, so any bug in FastAPI, uvicorn
or our own code hands an attacker root inside the container, with write access
to the app itself.

**D3. Python 3.9 is end-of-life (line 1).** It stopped receiving security fixes
in October 2025, so every vulnerability found in it since stays open in this
image. Nothing breaks, which is why nobody acts.

**D4. The base image tag floats (line 1).** `3.9-slim` points to whatever the
latest 3.9 build on the latest Debian is. Two builds of the same file months
apart do not get the same base, and our build pulled a digest that did not
exist when the file was written. That is how "it worked last year" happens.

**D5. Everything in `backend/` is copied, and there is no `.dockerignore`
(line 6).** `/app` ended up with `.env`, `requirements.in` and
`requirements.txt` next to the code. Any stray file in that folder (a second
`.env`, a dump, a key) would ship the same way.

**D6. The `.env` layer sits above the install (lines 3 to 5).** Every password
change invalidates the cache and reinstalls all the dependencies. A slower
build, nothing worse.

**D7. The base no longer matches the dependencies, so the build fails (line 1
against `requirements.txt`).** `annotated-types==0.8.0 Requires-Python
>=3.10`. It is the most visible defect and the cheapest: the build stops, we
change one line and it works. With only the base image changed, the image
built at 310 MB, looked perfectly normal, and still held D1, D2 and D5.

## 2. What a test would have caught

| Defect | Building | Running | Looking at the image | Only a person |
|---|---|---|---|---|
| D1 secret | | | `docker history`, `cat /app/.env` | |
| D2 root | | | `whoami`, `docker inspect` (no `User`) | |
| D3 end-of-life Python | | | `python --version`, if you know the dates; a scanner such as `docker scout` | |
| D4 floating tag | | | | ✓ |
| D5 copies everything | | | `ls -a /app` | ✓ (no `.dockerignore`) |
| D6 cache order | | | | ✓ |
| D7 build fails | ✓ | | | |

None of the seven makes the running container misbehave: the app starts and
serves pages with all of them.

For what no command catches, we would put four lines in the pull-request
checklist for any Dockerfile:

- The base image names a full version (`3.12.12-slim-bookworm`), and the PR that changes the dependencies also checks the Python version they were compiled for.
- No `COPY` of a whole folder or of anything named `.env`, `key` or `secret`, and a `.dockerignore` exists.
- Dependencies are copied and installed before the code, with nothing else above them.
- There is a `USER` line before `CMD`.

## 3. The rewrite

Built and checked: 297 MB (the same size as the company's own fixed image),
`whoami` prints `storefront`, `cat /app/.env` finds nothing, and `/app` holds
only the Python files and `requirements.txt`.

```dockerfile
# D3, D4, D7: a supported Python, pinned to a full version and a Debian release,
# matching the version requirements.txt was compiled for.
FROM python:3.12.12-slim-bookworm

# Logs straight to stdout, no .pyc files written at run time.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# D6: dependencies first, nothing else above them, so only a change to
# requirements.txt reinstalls them.
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# D2: a user with no privileges, created after the install.
RUN useradd --create-home --uid 10001 storefront
USER storefront

# D5: only the application code, nothing else from the folder.
COPY --chown=storefront backend/*.py ./

# D1: no .env. DATABASE_URL is passed at run time:
#   docker run -e DATABASE_URL=... storefront
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```text
# .dockerignore — D1, D5: secrets and local clutter never enter the build context.
**/.env
**/.env.*
**/*-key.json
**/__pycache__
**/*.pyc
**/.DS_Store
**/.git
Dockerfile*
```

## 4. What it tells us about inherited code

Three of the defects were fine on the day the file was written: D3, D4 and D7.
Python 3.9 was supported, `3.9-slim` gave a sound base, and the dependencies
installed on it. Nobody made a mistake; the world moved and the file stayed
still. D1, D2 and D5 were wrong from the first day.

For somebody to notice in time, the image had to be rebuilt while things were
changing, not only when the code changed. The header of `requirements.txt`
says it was compiled with `--python-version 3.12`: someone regenerated the
dependencies for 3.12 and left the Dockerfile on 3.9. A build run on that pull
request would have failed within minutes and pointed straight at line 1. A
scheduled rebuild, say weekly, would catch the same kind of drift even when no
one touches the repository. Pinning helps too, but it is not enough on its
own: the pinned `3.12.12-slim-bookworm` we used is already seven months old
according to `docker history`, so a pin needs an owner and a date to be bumped,
or it quietly becomes the next 3.9.
