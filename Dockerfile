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
RUN pdm install -G doc --no-lock --no-editable


# run stage
FROM python:3.8-slim-bullseye

# retrieve packages from build stage
ENV PYTHONPATH=/project/pkgs
COPY --from=builder /project/__pypackages__/3.8/lib /project/pkgs
ENV APP_PORT=8000

ADD https://github.com/jgraph/drawio-desktop/releases/download/v18.1.3/drawio-amd64-18.1.3.deb ./drawio.deb 
RUN apt update
# RUN apt install libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils  libatspi2.0-0  libsecret-1-0 
# RUN dpkg --configure -a
RUN yes | apt install ./drawio.deb 
COPY ./ /project
WORKDIR /project



CMD python3 -m mkdocs serve -a 0.0.0.0:${APP_PORT}
EXPOSE ${APP_PORT}
