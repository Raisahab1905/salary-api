# Use official Maven image with JDK 17
FROM maven:3.9.3-eclipse-temurin-17 AS build

WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre-alpine

# Install dependencies for wait script
RUN apk add --no-cache curl bash netcat-openbsd

# Copy and set up scripts FIRST (as root)
COPY wait-for.sh /usr/local/bin/wait-for
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/wait-for /usr/local/bin/docker-entrypoint.sh

# THEN create non-root user and switch
RUN addgroup -S spring && adduser -S spring -G spring
USER spring

WORKDIR /app
COPY --from=build --chown=spring:spring /app/target/*.jar app.jar

# Health check (optional but recommended)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Use wait script as entrypoint wrapper
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]