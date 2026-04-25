# Stage 1: Build the application
FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /build

# Copy the pom files first to leverage Docker cache for dependencies
COPY pom.xml .
COPY verifier-service/pom.xml verifier-service/
COPY verifier-application/pom.xml verifier-application/

# Download dependencies (this will be cached unless poms change)
RUN mvn dependency:go-offline -B

# Copy the source code
COPY verifier-service/src verifier-service/src
COPY verifier-application/src verifier-application/src

# Build the application
RUN mvn package -DskipTests -B

# Stage 2: Run the application
FROM eclipse-temurin:21-jre

# Install curl for health checks
USER 0
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 8080

WORKDIR /app

COPY scripts/entrypoint.sh /app/

# Add CA cert(s) into /certs-app so the entrypoint will import them into Java cacerts at startup
COPY certs/root_ca_vi.crt /certs-app/root_ca_vi.crt
#RUN mkdir -p /certs-app && chmod 755 /certs-app && chmod 644 /certs-app/root_ca_vi.crt || true
COPY --from=build /build/verifier-application/target/*.jar /app/app.jar

RUN set -uxe && \
    chmod g=u /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

# All image-specific envvars can easiliy be printed out by simply running:
#     podman inspect <IMAGE_NAME> --format='{{json .Config.Env}}' | jq -r '.[]|select(startswith("ISSUER_"))'
ENV JAVA_BOOTCLASSPATH="./lib"
VOLUME ${JAVA_BOOTCLASSPATH}

USER 1001

ENTRYPOINT ["/app/entrypoint.sh", "app.jar"]
