package com.deblurgan.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Entry point for the DeblurGAN backend orchestration service.
 * <p>
 * This service exposes a REST API consumed by the Flutter mobile app and, in
 * turn, forwards uploaded images to the Python ML inference microservice for
 * deblurring. See {@code ../docs/API_CONTRACT.md} at the project root for the
 * fixed contract this service implements.
 */
@SpringBootApplication
public class BackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(BackendApplication.class, args);
    }

}
