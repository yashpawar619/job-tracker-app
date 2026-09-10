CREATE TABLE job_applications (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company           VARCHAR(200) NOT NULL,
    role              VARCHAR(200) NOT NULL,
    location          VARCHAR(200),
    salary            NUMERIC(12, 2),
    currency          VARCHAR(10),
    status            VARCHAR(30) NOT NULL,
    source            VARCHAR(100),
    application_date  DATE NOT NULL,
    follow_up_date    DATE,
    response_date     DATE,
    notes             VARCHAR(2000),
    job_url           VARCHAR(500),
    created_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_job_applications_user_id ON job_applications (user_id);
CREATE INDEX idx_job_applications_status ON job_applications (status);
CREATE INDEX idx_job_applications_follow_up_date ON job_applications (follow_up_date);
