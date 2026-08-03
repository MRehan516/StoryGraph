FROM python:3.12-slim

# ffmpeg is NOT included in the default Python slim image or in
# Railway/Render's Python buildpacks. Every frame-extraction and export call
# in this app shells out to the ffmpeg binary -- without this line the app
# builds and boots fine, then fails on the very first branch attempt with
# "ffmpeg: command not found", which is a much worse time to find out.
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# SQLite file needs a writable, and ideally persistent, directory -- on
# Railway/Render attach a volume mounted at /data if you want the DB to
# survive redeploys, not just process restarts within one deploy.
ENV DB_PATH=/data/storygraph.db
RUN mkdir -p /data

# Single worker -- deliberate. Even with SQLite, this app's B2/Genblaze
# clients are constructed once per process; running multiple workers
# multiplies preflight calls and background-task scheduling in ways this
# code was not built to coordinate. Don't raise this without also revisiting
# the DB access pattern.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
