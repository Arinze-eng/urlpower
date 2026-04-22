FROM golang:1.22-alpine AS build
WORKDIR /src
COPY . .
RUN go build -o /out/signalserver ./cmd/signalserver

FROM alpine:3.20
WORKDIR /app
COPY --from=build /out/signalserver /app/signalserver
EXPOSE 5601/tcp
EXPOSE 3478/udp
ENTRYPOINT ["/app/signalserver", "-http", ":5601", "-relay", ":3478"]
