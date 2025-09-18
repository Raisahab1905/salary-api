# Use official Maven image with JDK 17
FROM maven:3.9.3-eclipse-temurin-17 AS build

# Set working directory inside container
WORKDIR /app

# Copy pom.xml and download dependencies first (cached)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the project
RUN mvn clean package -DskipTests

# Use a lightweight JDK 17 runtime for running the app
FROM eclipse-temurin:17-jdk-alpine

WORKDIR /app

# Copy the built jar from the build stage
COPY --from=build /app/target/*.jar ./app.jar

# Run the app
ENTRYPOINT ["java", "-jar", "app.jar"]
