package com.example.jobtracker.job.dto;

import com.example.jobtracker.job.ApplicationStatus;
import com.example.jobtracker.job.JobApplication;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record JobApplicationResponse(
        UUID id,
        String company,
        String role,
        String location,
        BigDecimal salary,
        String currency,
        ApplicationStatus status,
        String source,
        LocalDate applicationDate,
        LocalDate followUpDate,
        LocalDate responseDate,
        String notes,
        String jobUrl,
        Instant createdAt,
        Instant updatedAt
) {
    public static JobApplicationResponse from(JobApplication a) {
        return new JobApplicationResponse(
                a.getId(),
                a.getCompany(),
                a.getRole(),
                a.getLocation(),
                a.getSalary(),
                a.getCurrency(),
                a.getStatus(),
                a.getSource(),
                a.getApplicationDate(),
                a.getFollowUpDate(),
                a.getResponseDate(),
                a.getNotes(),
                a.getJobUrl(),
                a.getCreatedAt(),
                a.getUpdatedAt()
        );
    }
}
