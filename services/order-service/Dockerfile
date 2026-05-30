FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /build
RUN apk add --no-cache maven
# WHY --from=root-pom:
# additional_contexts in docker-compose passes the repo root as "root-pom".
# We copy the root pom.xml one level up (../pom.xml) so Maven can resolve
# the com.estateflow:compose-portal parent POM declared in relativePath.
COPY --from=root-pom pom.xml ../pom.xml
COPY pom.xml .
RUN mvn dependency:go-offline -q 2>/dev/null || true
COPY src ./src
RUN mvn clean package -DskipTests -q

FROM eclipse-temurin:17-jre-alpine AS runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar

# WHY RDS CA bundle:
# DocumentDB requires TLS. The AWS RDS CA bundle contains the root certificate
# that DocumentDB uses. Without it, MongoDB driver cannot verify the server cert.
# Downloaded at build time — no runtime dependency on external URLs.
RUN apk add --no-cache wget &&     wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem     -O /app/rds-combined-ca-bundle.pem &&     chown appuser:appgroup /app/rds-combined-ca-bundle.pem &&     apk del wget

RUN chown appuser:appgroup app.jar
USER appuser
VOLUME ["/tmp"]
EXPOSE 8083
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s \
    CMD wget -qO- http://localhost:8083/actuator/health || exit 1
ENTRYPOINT ["java","-XX:+UseContainerSupport","-XX:MaxRAMPercentage=75.0","-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
