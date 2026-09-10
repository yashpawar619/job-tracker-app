package com.example.jobtracker.job;

import com.example.jobtracker.common.Auditable;
import com.example.jobtracker.user.User;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(
        name = "job_applications",
        indexes = {
                @Index(name = "idx_job_applications_user_id", columnList = "user_id"),
                @Index(name = "idx_job_applications_status", columnList = "status"),
                @Index(name = "idx_job_applications_follow_up_date", columnList = "follow_up_date")
        }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class JobApplication extends Auditable {

    @Id
    @GeneratedValue
    @Column(columnDefinition = "uuid")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 200)
    private String company;

    @Column(nullable = false, length = 200)
    private String role;

    @Column(length = 200)
    private String location;

    @Column(precision = 12, scale = 2)
    private BigDecimal salary;

    @Column(length = 10)
    private String currency;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private ApplicationStatus status;

    @Column(length = 100)
    private String source;

    @Column(name = "application_date", nullable = false)
    private LocalDate applicationDate;

    @Column(name = "follow_up_date")
    private LocalDate followUpDate;

    @Column(name = "response_date")
    private LocalDate responseDate;

    @Column(length = 2000)
    private String notes;

    @Column(name = "job_url", length = 500)
    private String jobUrl;
}
