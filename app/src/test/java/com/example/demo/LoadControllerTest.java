package com.example.demo;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Nested;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@AutoConfigureMockMvc
class LoadControllerTest {

    @Nested
    @SpringBootTest
    @AutoConfigureMockMvc
    @TestPropertySource(properties = "app.simulate-load.enabled=false")
    class WhenDisabled {

        @Autowired
        private MockMvc mockMvc;

        @Test
        void returnsDisabledMessage() throws Exception {
            mockMvc.perform(get("/simulate-load"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.enabled").value(false));
        }
    }

    @Nested
    @SpringBootTest
    @AutoConfigureMockMvc
    @TestPropertySource(properties = {
            "app.simulate-load.enabled=true",
            "app.simulate-load.iterations=1000"
    })
    class WhenEnabled {

        @Autowired
        private MockMvc mockMvc;

        @Test
        void doesBoundedDeterministicWork() throws Exception {
            mockMvc.perform(get("/simulate-load"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.enabled").value(true))
                    .andExpect(jsonPath("$.iterations").value(1000))
                    .andExpect(jsonPath("$.checksum").exists());
        }
    }
}
