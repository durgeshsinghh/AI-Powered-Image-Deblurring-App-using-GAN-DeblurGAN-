package com.deblurgan.backend.client;

import com.deblurgan.backend.exception.ImageProcessingException;
import com.deblurgan.backend.exception.MlServiceUnavailableException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientRequestException;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.util.Base64;
import java.util.Map;
import java.util.concurrent.TimeoutException;

/**
 * Thin HTTP wrapper around the deployed DeblurGAN inference API
 * (https://github.com/durgeshsinghh/AI-Powered-Image-Deblurring-App-using-GAN-DeblurGAN-,
 * default {@code https://deblurgan-api.onrender.com}). See
 * {@code ../docs/API_CONTRACT.md} for the exact contract implemented here.
 * <p>
 * Uses the service's {@code POST /deblur/base64} endpoint (JSON in, JSON
 * out) rather than its multipart {@code /deblur}, since it hands back the
 * decoded image and the model's own inference time in a single response
 * that maps directly onto this backend's own JSON contract.
 * <p>
 * The service is hosted on Render's free tier and spins down after 15
 * minutes idle, so the <em>first</em> request after a period of inactivity
 * can take 30-60s just to wake up, on top of actual inference time -- the
 * generous response timeout configured in {@link
 * com.deblurgan.backend.config.WebClientConfig} accounts for that.
 */
@Component
public class MlInferenceClient {

    private static final Logger log = LoggerFactory.getLogger(MlInferenceClient.class);

    private final WebClient webClient;

    public MlInferenceClient(WebClient mlServiceWebClient) {
        this.webClient = mlServiceWebClient;
    }

    /**
     * Sends the given image bytes to the ML service's {@code POST
     * /deblur/base64} endpoint and returns the decoded deblurred image
     * bytes it responds with.
     *
     * @throws ImageProcessingException      if the service reachable but could not process this image (its 422)
     * @throws MlServiceUnavailableException if the service cannot be reached, is waking up, or errors out
     */
    public byte[] infer(byte[] imageBytes, String filename, String contentType) {
        String requestBase64 = Base64.getEncoder().encodeToString(imageBytes);

        try {
            MlBase64Response response = webClient.post()
                    .uri("/deblur/base64")
                    .contentType(MediaType.APPLICATION_JSON)
                    .bodyValue(Map.of("image_base64", requestBase64))
                    .retrieve()
                    .bodyToMono(MlBase64Response.class)
                    .block();

            if (response == null || response.imageBase64() == null || response.imageBase64().isBlank()) {
                throw new MlServiceUnavailableException("ML service returned an empty response");
            }

            log.info("ML service reported inference time of {} ms for '{}'", response.inferenceTimeMs(), filename);
            return Base64.getDecoder().decode(response.imageBase64());
        } catch (WebClientResponseException e) {
            if (e.getStatusCode() == HttpStatus.UNPROCESSABLE_ENTITY) {
                log.warn("ML service could not process '{}': {}", filename, e.getResponseBodyAsString());
                throw new ImageProcessingException("The AI engine could not process this image. Try a different photo.");
            }
            log.error("ML service returned status {} for /deblur/base64", e.getStatusCode(), e);
            throw new MlServiceUnavailableException("ML service responded with status " + e.getStatusCode(), e);
        } catch (WebClientRequestException e) {
            boolean likelyColdStart = e.getCause() instanceof TimeoutException;
            log.error("Failed to reach ML service for /deblur/base64 (likely cold start: {})", likelyColdStart, e);
            throw new MlServiceUnavailableException(
                    likelyColdStart
                            ? "The deblurring engine is waking up from being idle (this can take up to a minute on a free-tier host). Please try again shortly."
                            : "Could not reach ML service",
                    e);
        } catch (ImageProcessingException | MlServiceUnavailableException e) {
            throw e;
        } catch (Exception e) {
            log.error("Unexpected error calling ML service /deblur/base64", e);
            throw new MlServiceUnavailableException("Unexpected error calling ML service", e);
        }
    }

    /**
     * Checks the ML service's {@code GET /health} endpoint.
     * <p>
     * Never throws - any failure (connection refused, timeout, non-200,
     * unparseable body, or the host still waking up) is treated as "not
     * healthy" and simply returns {@code false}, so a caller's own health
     * check never breaks because the downstream service is down or asleep.
     */
    public boolean checkHealth() {
        try {
            Map<?, ?> body = webClient.get()
                    .uri("/health")
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block();

            return body != null && "ok".equals(body.get("status"));
        } catch (Exception e) {
            log.warn("ML service health check failed: {}", e.getMessage());
            return false;
        }
    }
}
