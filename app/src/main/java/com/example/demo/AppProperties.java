package com.example.demo;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Application metadata and feature flags, all driven by environment variables so the
 * same image behaves differently per environment.
 */
@ConfigurationProperties(prefix = "app")
public record AppProperties(
        String version,
        String commit,
        String environment,
        String buildTime,
        SimulateLoad simulateLoad) {

    public record SimulateLoad(boolean enabled, long iterations) {
    }
}
