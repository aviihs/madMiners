# Build from the repo root:  docker build -f server/Dockerfile -t mad-miners-server .
FROM dart:stable AS build
WORKDIR /src
COPY packages/mad_miners_core packages/mad_miners_core
COPY server server
WORKDIR /src/server
RUN dart pub get && dart compile exe bin/server.dart -o /out/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/server /app/server
ENV PORT=8080 MM_DATA_FILE=/data/accounts.json
EXPOSE 8080
CMD ["/app/server"]
