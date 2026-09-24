package com.deblurgan.backend.service;

import com.deblurgan.backend.client.MlInferenceClient;
import com.deblurgan.backend.dto.DeblurResponse;
import com.deblurgan.backend.exception.UnsupportedFileTypeException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.Base64;
import java.util.Set;

/**
 * Orchestrates a single deblur request: validates the uploaded file, calls
 * the ML inference service, times the round trip, and assembles the JSON
 * response returned to the Flutter app.
 */
@Service
public class DeblurService {

    private static final Logger log = LoggerFactory.getLogger(DeblurService.class);

    private static final Set<String> SUPPORTED_CONTENT_TYPES = Set.of("image/jpeg", "image/png");

    private final MlInferenceClient mlInferenceClient;

    public DeblurService(MlInferenceClient mlInferenceClient) {
        this.mlInferenceClient = mlInferenceClient;
    }

    public DeblurResponse deblur(MultipartFile image) {
        validate(image);

        long start = System.currentTimeMillis();
        byte[] originalBytes;
        try {
            originalBytes = image.getBytes();
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to read uploaded file", e);
        }

        byte[] deblurredBytes = mlInferenceClient.infer(originalBytes, image.getOriginalFilename(), image.getContentType());
        long elapsedMs = System.currentTimeMillis() - start;

        String base64Image = Base64.getEncoder().encodeToString(deblurredBytes);

        log.info("Deblurred '{}' ({} bytes -> {} bytes) in {} ms",
                image.getOriginalFilename(), originalBytes.length, deblurredBytes.length, elapsedMs);

        return DeblurResponse.success(image.getOriginalFilename(), elapsedMs, base64Image);
    }

    private void validate(MultipartFile image) {
        if (image == null || image.isEmpty()) {
            throw new UnsupportedFileTypeException("No image file was provided.");
        }

        String contentType = image.getContentType();
        if (contentType == null || !SUPPORTED_CONTENT_TYPES.contains(contentType.toLowerCase())) {
            throw new UnsupportedFileTypeException("Unsupported file type. Use JPG or PNG.");
        }
    }
}
