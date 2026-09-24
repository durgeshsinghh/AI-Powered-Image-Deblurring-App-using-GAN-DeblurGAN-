package com.deblurgan.backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Response body for {@code POST /api/v1/deblur}.
 * <p>
 * Field names/casing must match {@code docs/API_CONTRACT.md} exactly, since
 * the Flutter frontend is built against that document. Fields that are
 * {@code null} are omitted from the serialized JSON entirely (via
 * {@link JsonInclude}) so that a success response contains only
 * {@code success}/{@code originalFilename}/{@code processingTimeMs}/
 * {@code deblurredImageBase64}, and an error response contains only
 * {@code success}/{@code error} - exactly as shown in the contract.
 *
 * @param success               whether the request completed successfully
 * @param originalFilename      the original filename of the uploaded image; null on failure
 * @param processingTimeMs      total time spent processing the request, in milliseconds; null on failure
 * @param deblurredImageBase64  base64-encoded PNG bytes of the deblurred image; null on failure
 * @param error                 human-readable error message; null on success
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record DeblurResponse(
        boolean success,
        String originalFilename,
        Long processingTimeMs,
        String deblurredImageBase64,
        String error
) {

    public static DeblurResponse success(String originalFilename, long processingTimeMs, String deblurredImageBase64) {
        return new DeblurResponse(true, originalFilename, processingTimeMs, deblurredImageBase64, null);
    }

    public static DeblurResponse failure(String error) {
        return new DeblurResponse(false, null, null, null, error);
    }
}
