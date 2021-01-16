FROM golang:latest

COPY ./src /go/src/api
COPY ./data /data

WORKDIR /go/src/api

EXPOSE 9000

CMD [ "go", "run", "main.go" ]