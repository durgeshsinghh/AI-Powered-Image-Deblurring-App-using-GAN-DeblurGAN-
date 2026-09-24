package com.deblurgan.backend.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Wire shape of the deployed DeblurGAN API's {@code POST /deblur/base64}
 * response (see
 * https://github.com/durgeshsinghh/AI-Powered-Image-Deblurring-App-using-GAN-DeblurGAN-).
 * Field names on that service are snake_case, hence the explicit mapping.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
record MlBase64Response(
        @JsonProperty("image_base64") String imageBase64,
        @JsonProperty("inference_time_ms") Double inferenceTimeMs) {
}
