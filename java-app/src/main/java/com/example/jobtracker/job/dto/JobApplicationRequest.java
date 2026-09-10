package com.example.jobtracker.job.dto;

import com.example.jobtracker.job.ApplicationStatus;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

public record JobApplicationRequest(
        @NotBlank @Size(max = 200) String company,
        @NotBlank @Size(max = 200) String role,
        @Size(max = 200) String location,
        @DecimalMin("0.0") @Digits(integer = 10, fraction = 2) BigDecimal salary,
        @Size(max = 10) String currency,
        @NotNull ApplicationStatus status,
        @Size(max = 100) String source,
        @NotNull @PastOrPresent LocalDate applicationDate,
        LocalDate followUpDate,
        LocalDate responseDate,
        @Size(max = 2000) String notes,
        @Size(max = 500) String jobUrl
) {}
