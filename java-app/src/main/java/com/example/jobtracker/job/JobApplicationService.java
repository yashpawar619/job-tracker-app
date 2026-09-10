package com.example.jobtracker.job;

import com.example.jobtracker.common.PageResponse;
import com.example.jobtracker.exception.ResourceNotFoundException;
import com.example.jobtracker.job.dto.JobApplicationRequest;
import com.example.jobtracker.job.dto.JobApplicationResponse;
import com.example.jobtracker.job.dto.StatsResponse;
import com.example.jobtracker.security.CurrentUser;
import com.example.jobtracker.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class JobApplicationService {

    private final JobApplicationRepository repository;
    private final CurrentUser currentUser;

    @Transactional
    public JobApplicationResponse create(JobApplicationRequest req) {
        User user = currentUser.get();
        JobApplication app = JobApplication.builder()
                .user(user)
                .company(req.company())
                .role(req.role())
                .location(req.location())
                .salary(req.salary())
                .currency(req.currency())
                .status(req.status())
                .source(req.source())
                .applicationDate(req.applicationDate())
                .followUpDate(req.followUpDate())
                .responseDate(req.responseDate())
                .notes(req.notes())
                .jobUrl(req.jobUrl())
                .build();
        return JobApplicationResponse.from(repository.save(app));
    }

    @Transactional(readOnly = true)
    public JobApplicationResponse get(UUID id) {
        return JobApplicationResponse.from(findOwned(id));
    }

    @Transactional(readOnly = true)
    public PageResponse<JobApplicationResponse> list(ApplicationStatus status, String q, Pageable pageable) {
        UUID userId = currentUser.get().getId();
        var page = (StringUtils.hasText(q))
                ? repository.search(userId, q, pageable)
                : (status != null)
                    ? repository.findByUserIdAndStatus(userId, status, pageable)
                    : repository.findByUserId(userId, pageable);
        return PageResponse.from(page.map(JobApplicationResponse::from));
    }

    @Transactional
    public JobApplicationResponse update(UUID id, JobApplicationRequest req) {
        JobApplication app = findOwned(id);
        app.setCompany(req.company());
        app.setRole(req.role());
        app.setLocation(req.location());
        app.setSalary(req.salary());
        app.setCurrency(req.currency());
        app.setStatus(req.status());
        app.setSource(req.source());
        app.setApplicationDate(req.applicationDate());
        app.setFollowUpDate(req.followUpDate());
        app.setResponseDate(req.responseDate());
        app.setNotes(req.notes());
        app.setJobUrl(req.jobUrl());
        return JobApplicationResponse.from(app);
    }

    @Transactional
    public void delete(UUID id) {
        JobApplication app = findOwned(id);
        repository.delete(app);
    }

    @Transactional(readOnly = true)
    public List<JobApplicationResponse> followUpsDue() {
        UUID userId = currentUser.get().getId();
        return repository.findFollowUpsDue(userId, LocalDate.now())
                .stream().map(JobApplicationResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public StatsResponse stats() {
        UUID userId = currentUser.get().getId();
        long total = repository.countByUserId(userId);

        Map<ApplicationStatus, Long> byStatus = new EnumMap<>(ApplicationStatus.class);
        long responded = 0;
        for (ApplicationStatus s : ApplicationStatus.values()) {
            long count = repository.countByUserIdAndStatus(userId, s);
            byStatus.put(s, count);
            if (s != ApplicationStatus.APPLIED) {
                responded += count;
            }
        }
        double responseRate = total == 0 ? 0.0 : (double) responded / total;
        long followUps = repository.findFollowUpsDue(userId, LocalDate.now()).size();
        return new StatsResponse(total, byStatus, Math.round(responseRate * 10000.0) / 10000.0, followUps);
    }

    private JobApplication findOwned(UUID id) {
        UUID userId = currentUser.get().getId();
        return repository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Job application not found: " + id));
    }
}
