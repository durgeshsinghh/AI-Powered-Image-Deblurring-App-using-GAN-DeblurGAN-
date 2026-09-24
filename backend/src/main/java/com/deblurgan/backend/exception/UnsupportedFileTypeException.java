package com.deblurgan.backend.exception;

/**
 * Thrown when an uploaded file is missing, empty, or not one of the accepted
 * image content types (image/jpeg, image/png).
 */
public class UnsupportedFileTypeException extends RuntimeException {

    public UnsupportedFileTypeException(String message) {
        super(message);
    }
}
