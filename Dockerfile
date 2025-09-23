# Use official Maven image with JDK 17 to build the application
FROM maven:3.9.3-eclipse-temurin-17 AS build

# Set working directory inside container
WORKDIR /app

# Copy pom.xml and download dependencies first (cached)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build the application
COPY src ./src
RUN mvn clean package -DskipTests

# Use a lightweight JDK 17 runtime for running the app
FROM eclipse-temurin:17-jdk-alpine

# Set the working directory
WORKDIR /app

# Copy the built jar from the build stage
COPY --from=build /app/target/*.jar ./app.jar

# Expose the application port (optional, useful if you intend to access it externally)
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
