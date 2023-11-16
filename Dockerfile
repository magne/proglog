FROM golang:1.21.4-alpine AS build
WORKDIR /go/src/proglog
RUN GRPC_HEALTH_PROBE_VERSION=v0.4.22 && \
    wget -qO/go/bin/grpc_health_probe \
    https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-amd64 && \
    chmod +x /go/bin/grpc_health_probe
COPY go.* .
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /go/bin/proglog ./cmd/proglog

FROM scratch
COPY --from=build /go/bin/proglog /bin/proglog
COPY --from=build /go/bin/grpc_health_probe /bin/grpc_health_probe
COPY --from=build /go/src/proglog/test/model.conf /etc/proglog/model.conf
COPY --from=build /go/src/proglog/test/policy.csv /etc/proglog/policy.csv
ENTRYPOINT ["/bin/proglog"]
