FROM ubuntu:20.04

RUN apt-get update -y && apt-get install -y tree

RUN mkdir -p test/nested && \
    cd test && \
    touch nested/a.txt b.txt

RUN echo "current path: `pwd`"

RUN ls --format=across

RUN tree src/

WORKDIR /src

CMD ["python", "src/main.py"]