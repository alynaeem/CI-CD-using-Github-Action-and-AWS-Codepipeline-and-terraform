# ─────────────────────────────────────────────────────────────────────────────
# Multi-stage Dockerfile — Product Microservice
# Final image target: < 200 MB
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-17-alpine AS build
WORKDIR /app

# Cache dependencies layer separately from source code
COPY pom.xml .
RUN mvn dependency:go-offline -B --no-transfer-progress

COPY src ./src
RUN mvn clean package -DskipTests -B --no-transfer-progress

# ── Stage 2: Runtime (minimal Alpine JRE) ────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

COPY --from=build /app/target/store-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8080

# Docker-native liveness check (mirrors Actuator /health)
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1

# Container-aware JVM: respect cgroup memory limits, use 75% of available RAM
ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-jar", "app.jar"]
