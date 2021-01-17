FROM golang:latest

RUN go get -u -d gocv.io/x/gocv

WORKDIR /go/src/gocv.io/x/gocv

COPY ./Makefile .
RUN make install

WORKDIR /go/src/api

RUN go get -u gorm.io/gorm
RUN go get -u gorm.io/driver/sqlite

COPY ./src .

EXPOSE 9000

CMD [ "go", "run", "main.go" ]