# build stage
FROM python:3.8 AS builder

# install PDM
RUN pip install -U pip setuptools wheel
RUN pip install pdm

# copy files
COPY pyproject.toml pdm.lock README.md /project/
# COPY ./ /project/

# install dependencies and project
WORKDIR /project
RUN pdm install --prod --no-lock --no-editable


# run stage
FROM python:3.8-slim-bullseye

# retrieve packages from build stage
ENV PYTHONPATH=/project/pkgs
COPY --from=builder /project/__pypackages__/3.8/lib /project/pkgs
ENV APP_PORT=8000

COPY ./ /project
WORKDIR /project
CMD python3 -m mkdocs serve -a 0.0.0.0:${APP_PORT}
# CMD python3 -m uvicorn main:app --host 0.0.0.0 --port ${APP_PORT} --workers 1 
EXPOSE ${APP_PORT}
