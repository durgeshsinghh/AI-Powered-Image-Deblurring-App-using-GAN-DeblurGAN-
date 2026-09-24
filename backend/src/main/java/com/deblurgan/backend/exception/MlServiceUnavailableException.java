package com.deblurgan.backend.exception;

/**
 * Thrown when the Python ML inference microservice cannot be reached, or
 * responds with a non-2xx status, while processing a deblur request.
 */
public class MlServiceUnavailableException extends RuntimeException {

    public MlServiceUnavailableException(String message) {
        super(message);
    }

    public MlServiceUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
