# golang debian buster 1.13.6 linux/amd64
# https://github.com/docker-library/golang/blob/master/1.14/buster/Dockerfile
FROM golang@sha256:887e9114176491998d0cc9ba9cc16f5e395065e3b5422a6d9351168810942181 as builder

# Ensure ca-certficates are up to date                     
RUN update-ca-certificates

WORKDIR $GOPATH/src/mypackage/myapp/

# use modules
COPY go.mod .

ENV GO111MODULE=on
RUN go mod download
RUN go mod verify

COPY . .

# Build the static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/bin/server .

FROM perl:5.26
RUN cpanm Carton \
    && mkdir -p /usr/src/app

WORKDIR /usr/src/app
COPY cpanfile /usr/src/app
RUN carton install
COPY . /usr/src/app
COPY --from=builder /go/bin/server /usr/src/app/server

CMD [ "/usr/src/app/server" ]
