FROM golang:1.26.3-alpine AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /lobby .
FROM alpine:3.23
RUN adduser -D -u 10002 lobby
COPY --from=build /lobby /usr/local/bin/lobby
USER lobby
ENV LOBBY_LISTEN=0.0.0.0:8096
EXPOSE 8096
ENTRYPOINT ["/usr/local/bin/lobby"]
