# Multi-stage build so the final image only ships a JRE + the built jar,
# not the whole Maven/JDK toolchain.

FROM eclipse-temurin:17-jdk AS build
WORKDIR /build

# Cache dependency resolution separately from source changes.
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN chmod +x mvnw && ./mvnw -q dependency:go-offline -DskipTests || true

COPY src src
RUN ./mvnw -q clean package -DskipTests

FROM eclipse-temurin:17-jre AS run
WORKDIR /app
COPY --from=build /build/target/backend-0.0.1-SNAPSHOT.jar app.jar

# Render sets $PORT at runtime; Spring Boot must bind to it.
ENV SERVER_PORT=${PORT:-8080}
EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java -Dserver.port=${PORT:-8080} -jar app.jar"]
