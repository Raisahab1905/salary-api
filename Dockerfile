# Use official Maven image with JDK 17
FROM maven:3.9.3-eclipse-temurin-17 AS build

# Set working directory inside container
WORKDIR /app

# Copy pom.xml and download dependencies first (cached)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the project (create a reproducible build)
RUN mvn clean package -DskipTests -Dmaven.test.skip=true

# Use a lightweight JRE instead of JDK for runtime
FROM eclipse-temurin:17-jre-alpine

# Security best practices - run as non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring

WORKDIR /app

# Copy the built jar from the build stage
COPY --from=build --chown=spring:spring /app/target/*.jar app.jar

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Better JVM options for containers
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"

# Run the app with better signal handling
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
