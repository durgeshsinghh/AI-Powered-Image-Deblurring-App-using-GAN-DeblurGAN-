package com.deblurgan.backend.config;

import io.netty.channel.ChannelOption;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import java.time.Duration;

/**
 * Configures the {@link WebClient} used to call the DeblurGAN ML inference
 * service. The base URL comes from the {@code ml.service.url} property,
 * itself sourced from the {@code ML_SERVICE_URL} environment variable (see
 * {@code application.yml}), defaulting to the deployed service at
 * {@code https://deblurgan-api.onrender.com}.
 * <p>
 * Timeouts are deliberately generous: that service is hosted on Render's
 * free tier and spins down after 15 minutes idle, so the first request
 * after inactivity can take 30-60s just to wake the container, before any
 * actual inference happens.
 */
@Configuration
public class WebClientConfig {

    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(15);
    private static final Duration RESPONSE_TIMEOUT = Duration.ofSeconds(100);

    @Bean
    public WebClient mlServiceWebClient(@Value("${ml.service.url}") String baseUrl) {
        HttpClient httpClient = HttpClient.create()
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, (int) CONNECT_TIMEOUT.toMillis())
                .responseTimeout(RESPONSE_TIMEOUT);

        return WebClient.builder()
                .baseUrl(baseUrl)
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }
}
