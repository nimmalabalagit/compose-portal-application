# Stage 1: Build
ARG BUILD_DATE
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /build
RUN apk add --no-cache maven
COPY --from=root-pom pom.xml ../pom.xml
COPY pom.xml .
RUN mvn dependency:go-offline -q 2>/dev/null || true
COPY src ./src
RUN mvn clean package -DskipTests -q

# Stage 2: Runtime
# WHY full JRE not jlink:
# jlink error: java.beans.PropertyEditorSupport not found at runtime.
# Spring Cloud Gateway + Netty + Reactor use java.desktop, java.sql,
# and other modules that cannot be enumerated at build time.
# eclipse-temurin:17-jre-alpine includes ALL modules — safe for reactive stack.
FROM eclipse-temurin:17-jre-alpine AS runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar
RUN chown appuser:appgroup app.jar
USER appuser
VOLUME ["/tmp"]
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
