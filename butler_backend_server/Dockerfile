# Build stage
FROM dart:stable AS build
WORKDIR /app
COPY . .

# Install dependencies and compile the server executable
RUN dart pub get
RUN dart compile exe bin/main.dart -o bin/main

# Final stage
FROM debian:stable-slim

# Install ca-certificates
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Environment variables
ENV runmode=production
ENV serverid=default
ENV logging=normal
ENV role=monolith

# Copy compiled server executable
COPY --from=build /app/bin/main main

# Copy configuration files and resources
COPY --from=build /app/config/ config/
COPY --from=build /app/web/ web/
COPY --from=build /app/migrations/ migrations/

# This file is required to enable the endpoint log filter in Insights.
COPY --from=build /app/lib/src/generated/protocol.yaml lib/src/generated/protocol.yaml

# Expose port (Google Cloud Run dynamically injects PORT, but default is 8080)
EXPOSE 8080

# Define the entrypoint command with dynamic port replacement
ENTRYPOINT ["/bin/sh", "-c", "if [ -n \"$PORT\" ]; then sed -i \"s/port: 8080/port: $PORT/g\" config/production.yaml; fi && exec ./main --mode=$runmode --server-id=$serverid --logging=$logging --role=$role"]

