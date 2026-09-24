package com.deblurgan.backend.exception;

/**
 * Thrown when the ML inference service accepted the request but could not
 * produce a result for this particular image (its {@code 422} response,
 * e.g. an unreadable or unusual image it failed to process). Distinct from
 * {@link MlServiceUnavailableException}, which means the service itself
 * could not be reached at all.
 */
public class ImageProcessingException extends RuntimeException {

    public ImageProcessingException(String message) {
        super(message);
    }
}
