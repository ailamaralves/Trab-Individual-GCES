FROM python:3.8

RUN pip install -r dependencias.txt

COPY . .

WORKDIR /src

CMD ["python", "src/main.py"]
