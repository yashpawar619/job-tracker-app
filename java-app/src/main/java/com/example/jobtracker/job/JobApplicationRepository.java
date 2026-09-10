package com.example.jobtracker.job;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface JobApplicationRepository extends JpaRepository<JobApplication, UUID> {

    Optional<JobApplication> findByIdAndUserId(UUID id, UUID userId);

    Page<JobApplication> findByUserId(UUID userId, Pageable pageable);

    Page<JobApplication> findByUserIdAndStatus(UUID userId, ApplicationStatus status, Pageable pageable);

    @Query("""
        SELECT a FROM JobApplication a
        WHERE a.user.id = :userId
          AND (LOWER(a.company) LIKE LOWER(CONCAT('%', :q, '%'))
               OR LOWER(a.role) LIKE LOWER(CONCAT('%', :q, '%')))
    """)
    Page<JobApplication> search(@Param("userId") UUID userId, @Param("q") String q, Pageable pageable);

    @Query("""
        SELECT a FROM JobApplication a
        WHERE a.user.id = :userId
          AND a.followUpDate IS NOT NULL
          AND a.followUpDate <= :today
          AND a.status IN (com.example.jobtracker.job.ApplicationStatus.APPLIED,
                           com.example.jobtracker.job.ApplicationStatus.INTERVIEW)
        ORDER BY a.followUpDate ASC
    """)
    List<JobApplication> findFollowUpsDue(@Param("userId") UUID userId, @Param("today") LocalDate today);

    long countByUserId(UUID userId);

    long countByUserIdAndStatus(UUID userId, ApplicationStatus status);
}
