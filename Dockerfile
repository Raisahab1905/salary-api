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

# Copy wait script
COPY wait-for.sh /usr/local/bin/wait-for
RUN chmod +x /usr/local/bin/wait-for

# Create non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring

WORKDIR /app
COPY --from=build --chown=spring:spring /app/target/*.jar app.jar

# Use wait script as entrypoint wrapper
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
