package com.estateflow.gateway.filter;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.UUID;

// WHY this filter:
// Every request gets a UUID correlation ID.
// It propagates through all downstream services via HTTP header.
// In Grafana Loki, you can filter logs by correlationId to trace
// one user request across 4 microservices — critical for debugging.

@Component
public class CorrelationIdFilter implements GlobalFilter, Ordered {

    private static final Logger log =
            LoggerFactory.getLogger(CorrelationIdFilter.class);

    private static final String CORRELATION_HEADER =
            "X-Correlation-ID";

    @Override
    public Mono<Void> filter(
            ServerWebExchange exchange,
            GatewayFilterChain chain
    ) {

        String correlationId = exchange.getRequest()
                .getHeaders()
                .getFirst(CORRELATION_HEADER);

        if (correlationId == null || correlationId.isBlank()) {
            correlationId = UUID.randomUUID().toString();
        }

        final String finalCorrelationId = correlationId;

        ServerHttpRequest mutatedRequest = exchange.getRequest()
                .mutate()
                .header(CORRELATION_HEADER, finalCorrelationId)
                .build();

        log.info(
                "request method={} path={} correlationId={}",
                exchange.getRequest().getMethod(),
                exchange.getRequest().getPath(),
                finalCorrelationId
        );

        return chain.filter(
                exchange.mutate()
                        .request(mutatedRequest)
                        .build()
        ).doFinally(signalType ->
                log.info(
                        "response correlationId={} signal={}",
                        finalCorrelationId,
                        signalType
                )
        );
    }

    @Override
    public int getOrder() {
        return -1; // Run before all other filters
    }
}
