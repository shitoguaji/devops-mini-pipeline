# syntax=docker/dockerfile:1.7

# ---- Builder 阶段：用完整Python镜像 ----
FROM python:3.13-slim AS builder
WORKDIR /app
COPY server.py .

# ---- Runtime 阶段：用distroless进一步瘦身 ----
FROM python:3.13-slim AS runtime
WORKDIR /app
COPY --from=builder /app/server.py /app/server.py
ENV PORT=8000
EXPOSE 8000
ENTRYPOINT ["python3", "/app/server.py"]