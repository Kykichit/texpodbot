# syntax=docker/dockerfile:1.7

FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

COPY pyproject.toml README.md ./
COPY src ./src
COPY texpod_bot ./texpod_bot

RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel --wheel-dir /wheels .

FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY --from=builder /wheels /wheels
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install /wheels/*.whl && rm -rf /wheels

COPY alembic.ini ./
COPY runbooks ./runbooks
COPY migrations ./migrations

RUN groupadd --system app && useradd --system --gid app --home-dir /app --no-create-home app

USER app

CMD ["python", "-m", "app.main", "run"]
