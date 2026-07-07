package com.example.demo;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class VersionController {

    private final AppProperties props;

    public VersionController(AppProperties props) {
        this.props = props;
    }

    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of(
                "version", props.version(),
                "commit", props.commit(),
                "environment", props.environment(),
                "buildTime", props.buildTime());
    }
}
