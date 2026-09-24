package com.deblurgan.backend.exception;

import com.deblurgan.backend.dto.DeblurResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;

/**
 * Translates exceptions raised anywhere in the request-handling pipeline
 * into the JSON error shape described in {@code ../docs/API_CONTRACT.md}:
 * {@code {"success": false, "error": "..."}}.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(UnsupportedFileTypeException.class)
    public ResponseEntity<DeblurResponse> handleUnsupportedFileType(UnsupportedFileTypeException e) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(DeblurResponse.failure(e.getMessage()));
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<DeblurResponse> handleMissingParameter(MissingServletRequestParameterException e) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(DeblurResponse.failure("Required part '" + e.getParameterName() + "' is missing."));
    }

    @ExceptionHandler(MissingServletRequestPartException.class)
    public ResponseEntity<DeblurResponse> handleMissingPart(MissingServletRequestPartException e) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(DeblurResponse.failure("Required part '" + e.getRequestPartName() + "' is missing."));
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<DeblurResponse> handleUnsupportedMediaType(HttpMediaTypeNotSupportedException e) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(DeblurResponse.failure("Request must be multipart/form-data with an 'image' part."));
    }

    @ExceptionHandler(MlServiceUnavailableException.class)
    public ResponseEntity<DeblurResponse> handleMlServiceUnavailable(MlServiceUnavailableException e) {
        log.error("ML service unavailable", e);
        return ResponseEntity.status(HttpStatus.BAD_GATEWAY)
                .body(DeblurResponse.failure(e.getMessage() != null
                        ? e.getMessage()
                        : "Deblurring engine is unavailable. Try again shortly."));
    }

    @ExceptionHandler(ImageProcessingException.class)
    public ResponseEntity<DeblurResponse> handleImageProcessing(ImageProcessingException e) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY)
                .body(DeblurResponse.failure(e.getMessage()));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<DeblurResponse> handleMaxUploadSizeExceeded(MaxUploadSizeExceededException e) {
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE)
                .body(DeblurResponse.failure("File exceeds the 10MB limit."));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<DeblurResponse> handleGenericException(Exception e) {
        log.error("Unexpected server error", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(DeblurResponse.failure("Unexpected server error."));
    }
}
