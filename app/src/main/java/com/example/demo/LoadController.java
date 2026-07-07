package com.example.demo;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Optional endpoint used to reproduce a CPU-heavy request in a controlled way.
 * It is off by default and only does a bounded, fixed amount of work when enabled,
 * so the effect is deterministic and reversible (used for the incident scenario).
 */
@RestController
public class LoadController {

    private final AppProperties props;

    public LoadController(AppProperties props) {
        this.props = props;
    }

    @GetMapping("/simulate-load")
    public Map<String, Object> simulateLoad() {
        AppProperties.SimulateLoad cfg = props.simulateLoad();
        if (!cfg.enabled()) {
            return Map.of("enabled", false, "message", "simulate-load is disabled");
        }

        long start = System.nanoTime();
        double acc = 0;
        for (long i = 1; i <= cfg.iterations(); i++) {
            acc += Math.sqrt(i);
        }
        long elapsedMs = (System.nanoTime() - start) / 1_000_000;

        return Map.of(
                "enabled", true,
                "iterations", cfg.iterations(),
                "elapsedMs", elapsedMs,
                "checksum", Math.round(acc));
    }
}
