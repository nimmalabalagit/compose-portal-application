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

# WHY import DocumentDB CA into JVM truststore:
# MongoDB Java driver 4.x does not support tlsCAFile in URI — it is silently ignored.
# The driver uses the JVM default truststore (cacerts) for TLS verification.
# DocumentDB uses AWS RDS CA which is NOT in the default JVM truststore.
# Fix: download global-bundle.pem, split into individual certs, import each into cacerts.
# After this, tls=true in URI works without any code change.
RUN apk add --no-cache wget openssl && \
    wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
      -O /tmp/global-bundle.pem && \
    csplit -z -f /tmp/rds-cert- /tmp/global-bundle.pem \
      '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null || true && \
    JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java)))) && \
    TRUSTSTORE="${JAVA_HOME}/lib/security/cacerts" && \
    for cert in /tmp/rds-cert-*; do \
      alias="rds-$(basename $cert)"; \
      keytool -import -trustcacerts -noprompt \
        -alias "$alias" -file "$cert" \
        -keystore "$TRUSTSTORE" \
        -storepass changeit 2>/dev/null || true; \
    done && \
    rm -f /tmp/rds-cert-* /tmp/global-bundle.pem && \
    apk del wget openssl

RUN chown appuser:appgroup app.jar
USER appuser
VOLUME ["/tmp"]
EXPOSE 8083
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s \
    CMD wget -qO- http://localhost:8083/actuator/health || exit 1
ENTRYPOINT ["java","-XX:+UseContainerSupport","-XX:MaxRAMPercentage=75.0","-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
