FROM python:3.12-alpine
WORKDIR /app
RUN pip install --no-cache-dir "psycopg[binary]==3.2.3" "redis==5.2.1"
COPY app.py .
CMD ["python", "app.py"]
