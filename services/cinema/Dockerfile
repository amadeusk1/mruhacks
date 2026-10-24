FROM golang:1.26.3-alpine AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /cinema .
FROM alpine:3.23
RUN apk add --no-cache ca-certificates ffmpeg && adduser -D -u 10001 cinema
COPY --from=build /cinema /usr/local/bin/cinema
USER cinema
ENV CINEMA_LISTEN=0.0.0.0:8095
EXPOSE 8095
ENTRYPOINT ["/usr/local/bin/cinema"]
