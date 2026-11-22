# Build from the repo root:  docker build -f server/Dockerfile -t mad-miners-server .
# The server needs the shared game rules in packages/mad_miners_core, so the
# build context is the whole repo, not just server/.
FROM dart:stable AS build
WORKDIR /src
COPY packages/mad_miners_core packages/mad_miners_core
COPY server server
WORKDIR /src/server
RUN dart pub get && dart compile exe bin/server.dart -o /out/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/server /app/server
COPY --from=build /src/server/database/migrations /app/database/migrations
# DATABASE_URL (and optionally MM_GOOGLE_CLIENT_IDS) come from the host.
ENV PORT=8080 \
    MM_MIGRATIONS_DIR=/app/database/migrations \
    MM_LAN_DISCOVERY=off
EXPOSE 8080
CMD ["/app/server"]
