# build stage
FROM python:3.8

# install PDM
RUN pip install -U pip setuptools wheel
RUN pip install pdm

# copy files
COPY pyproject.toml pdm.lock README.md /project/

WORKDIR /project
RUN pdm install --prod --no-lock --no-editable
RUN pdm install -G doc --no-lock --no-editable


ENV APP_PORT=8000


ADD https://github.com/jgraph/drawio-desktop/releases/download/v18.1.3/drawio-amd64-18.1.3.deb ./drawio.deb 
RUN apt update

RUN yes | apt install ./drawio.deb -S 
RUN yes | apt install -y libgbm-dev
RUN yes | apt install -y libasound2

RUN yes | apt install libasound2 xvfb

COPY ./ /project
WORKDIR /project


# RUN xvfb-run -a pdm run mkdocs build
CMD python3 -m mkdocs serve -a 0.0.0.0:${APP_PORT}
EXPOSE ${APP_PORT}
