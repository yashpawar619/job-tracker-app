package com.example.jobtracker.job;

import com.example.jobtracker.common.PageResponse;
import com.example.jobtracker.job.dto.JobApplicationRequest;
import com.example.jobtracker.job.dto.JobApplicationResponse;
import com.example.jobtracker.job.dto.StatsResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/applications")
@RequiredArgsConstructor
@Tag(name = "Job Applications", description = "Track and manage your job applications")
public class JobApplicationController {

    private final JobApplicationService service;

    @Operation(summary = "Create a new job application")
    @PostMapping
    public ResponseEntity<JobApplicationResponse> create(@Valid @RequestBody JobApplicationRequest request) {
        JobApplicationResponse created = service.create(request);
        return ResponseEntity.created(URI.create("/api/applications/" + created.id())).body(created);
    }

    @Operation(summary = "List job applications (paged, optionally filtered)")
    @GetMapping
    public PageResponse<JobApplicationResponse> list(
            @RequestParam(required = false) ApplicationStatus status,
            @RequestParam(required = false) String q,
            @PageableDefault(size = 20, sort = "applicationDate", direction = Sort.Direction.DESC) Pageable pageable
    ) {
        return service.list(status, q, pageable);
    }

    @Operation(summary = "Get one job application by id")
    @GetMapping("/{id}")
    public JobApplicationResponse get(@PathVariable UUID id) {
        return service.get(id);
    }

    @Operation(summary = "Update a job application")
    @PutMapping("/{id}")
    public JobApplicationResponse update(@PathVariable UUID id, @Valid @RequestBody JobApplicationRequest request) {
        return service.update(id, request);
    }

    @Operation(summary = "Delete a job application")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        service.delete(id);
    }

    @Operation(summary = "Applications with follow-ups due today or earlier")
    @GetMapping("/follow-ups")
    public List<JobApplicationResponse> followUps() {
        return service.followUpsDue();
    }

    @Operation(summary = "Aggregate stats for the current user")
    @GetMapping("/stats")
    public StatsResponse stats() {
        return service.stats();
    }
}
