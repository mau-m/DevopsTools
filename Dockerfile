# ---------- Build ----------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B -ntp dependency:go-offline
COPY src/ src/
RUN mvn -B -ntp clean package -DskipTests
        
# ---------- Runtime ----------
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
        
# usuario no root
RUN useradd -r -u 1001 appuser && chown appuser /app
USER appuser
        
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
