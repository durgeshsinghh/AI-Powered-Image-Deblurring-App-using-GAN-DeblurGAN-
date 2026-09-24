package com.deblurgan.backend.controller;

import com.deblurgan.backend.client.MlInferenceClient;
import com.deblurgan.backend.dto.DeblurResponse;
import com.deblurgan.backend.dto.HealthResponse;
import com.deblurgan.backend.service.DeblurService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * REST endpoints consumed by the Flutter app. See
 * {@code ../docs/API_CONTRACT.md} for the fixed request/response contract.
 */
@RestController
public class DeblurController {

    private final DeblurService deblurService;
    private final MlInferenceClient mlInferenceClient;

    public DeblurController(DeblurService deblurService, MlInferenceClient mlInferenceClient) {
        this.deblurService = deblurService;
        this.mlInferenceClient = mlInferenceClient;
    }

    @PostMapping(value = "/api/v1/deblur", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public DeblurResponse deblur(@RequestParam("image") MultipartFile image) {
        return deblurService.deblur(image);
    }

    @GetMapping("/api/v1/health")
    public HealthResponse health() {
        boolean mlUp = mlInferenceClient.checkHealth();
        return new HealthResponse("UP", mlUp ? "UP" : "DOWN");
    }
}
