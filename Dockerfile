FROM maven:3.8.6-openjdk-11 AS build
WORKDIR /app
COPY . .
RUN mvn clean install -DskipTests \
    -Djdk.module.illegalAccess=permit \
    -DcompilerArgs=-J--add-opens=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED

EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/target/ecos-api.jar"]