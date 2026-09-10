package com.example.jobtracker.job;

import com.example.jobtracker.exception.ResourceNotFoundException;
import com.example.jobtracker.job.dto.JobApplicationRequest;
import com.example.jobtracker.job.dto.JobApplicationResponse;
import com.example.jobtracker.security.CurrentUser;
import com.example.jobtracker.user.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class JobApplicationServiceTest {

    @Mock JobApplicationRepository repository;
    @Mock CurrentUser currentUser;
    @InjectMocks JobApplicationService service;

    private User user;

    @BeforeEach
    void setUp() {
        user = User.builder().id(UUID.randomUUID()).email("t@x.com").build();
    }

    @Test
    void create_persists_and_returns_response() {
        when(currentUser.get()).thenReturn(user);
        when(repository.save(any(JobApplication.class))).thenAnswer(inv -> {
            JobApplication a = inv.getArgument(0);
            a.setId(UUID.randomUUID());
            return a;
        });

        JobApplicationRequest req = new JobApplicationRequest(
                "Google", "SWE", "Remote", null, null,
                ApplicationStatus.APPLIED, "LinkedIn",
                LocalDate.now(), null, null, null, null);

        JobApplicationResponse res = service.create(req);

        assertThat(res.company()).isEqualTo("Google");
        assertThat(res.status()).isEqualTo(ApplicationStatus.APPLIED);
    }

    @Test
    void get_notFound_throws() {
        when(currentUser.get()).thenReturn(user);
        when(repository.findByIdAndUserId(any(), any())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.get(UUID.randomUUID()))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
