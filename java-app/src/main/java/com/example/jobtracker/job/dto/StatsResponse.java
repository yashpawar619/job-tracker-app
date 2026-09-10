package com.example.jobtracker.job.dto;

import com.example.jobtracker.job.ApplicationStatus;

import java.util.Map;

public record StatsResponse(
        long total,
        Map<ApplicationStatus, Long> byStatus,
        double responseRate,
        long followUpsDue
) {}
