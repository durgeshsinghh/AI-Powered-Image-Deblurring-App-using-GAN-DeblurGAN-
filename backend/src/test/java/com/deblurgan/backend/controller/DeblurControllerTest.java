package com.deblurgan.backend.controller;

import com.deblurgan.backend.client.MlInferenceClient;
import com.deblurgan.backend.dto.DeblurResponse;
import com.deblurgan.backend.exception.UnsupportedFileTypeException;
import com.deblurgan.backend.service.DeblurService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Controller-slice tests for {@code POST /api/v1/deblur}, verifying the
 * HTTP-level contract described in {@code ../docs/API_CONTRACT.md}: status
 * codes and JSON response shape. {@link DeblurService} is mocked so these
 * tests exercise only routing, multipart binding, and exception-to-response
 * translation (see {@link com.deblurgan.backend.exception.GlobalExceptionHandler}).
 */
@WebMvcTest(DeblurController.class)
class DeblurControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private DeblurService deblurService;

    @MockBean
    private MlInferenceClient mlInferenceClient;

    @Test
    void validPngUpload_returns200WithExpectedJsonShape() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "image", "photo.png", MediaType.IMAGE_PNG_VALUE, "fake-png-bytes".getBytes());

        when(deblurService.deblur(any())).thenReturn(
                DeblurResponse.success("photo.png", 842L, "iVBORw0KGgoAAAANSUhEUgAA"));

        mockMvc.perform(multipart("/api/v1/deblur").file(file))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.originalFilename").value("photo.png"))
                .andExpect(jsonPath("$.processingTimeMs").value(842))
                .andExpect(jsonPath("$.deblurredImageBase64").value("iVBORw0KGgoAAAANSUhEUgAA"));
    }

    @Test
    void wrongContentType_returns400() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "image", "note.txt", MediaType.TEXT_PLAIN_VALUE, "not an image".getBytes());

        when(deblurService.deblur(any()))
                .thenThrow(new UnsupportedFileTypeException("Unsupported file type. Use JPG or PNG."));

        mockMvc.perform(multipart("/api/v1/deblur").file(file))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error").value("Unsupported file type. Use JPG or PNG."));
    }

    @Test
    void missingFilePart_returns400() throws Exception {
        mockMvc.perform(multipart("/api/v1/deblur"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));
    }
}
