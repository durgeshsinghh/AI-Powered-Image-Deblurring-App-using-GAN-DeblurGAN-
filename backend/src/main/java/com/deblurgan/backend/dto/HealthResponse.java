package com.deblurgan.backend.dto;

/**
 * Response body for {@code GET /api/v1/health}.
 *
 * @param status           backend status, always {@code "UP"} if this response was produced at all
 * @param mlServiceStatus  {@code "UP"} or {@code "DOWN"} depending on whether the ML service's
 *                         {@code /health} endpoint responded successfully
 */
public record HealthResponse(String status, String mlServiceStatus) {
}
