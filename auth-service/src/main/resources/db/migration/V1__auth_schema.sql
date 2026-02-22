-- ─── EXTENSIONS ───────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── TENANTS ──────────────────────────────────────────────────────────────────
CREATE TABLE tenants (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                    VARCHAR(100) NOT NULL,
    email                   VARCHAR(100) NOT NULL UNIQUE,
    phone                   VARCHAR(20),
    subdomain               VARCHAR(50) UNIQUE,
    is_group                BOOLEAN NOT NULL DEFAULT FALSE,
    status                  VARCHAR(30) NOT NULL DEFAULT 'PENDING_VERIFICATION',
    -- PENDING_VERIFICATION, TRIAL, ACTIVE, SUSPENDED, DELETED
    trial_starts_at         TIMESTAMP,
    trial_ends_at           TIMESTAMP,
    deleted_at              TIMESTAMP,
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─── TENANT SUBSCRIPTIONS ─────────────────────────────────────────────────────
CREATE TABLE tenant_subscriptions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    plan                    VARCHAR(20) NOT NULL DEFAULT 'TRIAL',
    -- TRIAL, BASIC, PROFESSIONAL, ENTERPRISE
    status                  VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    -- ACTIVE, EXPIRED, CANCELLED
    starts_at               TIMESTAMP NOT NULL,
    ends_at                 TIMESTAMP,
    max_properties          INT NOT NULL DEFAULT 1,
    max_rooms               INT NOT NULL DEFAULT 20,
    max_users               INT NOT NULL DEFAULT 5,
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─── PROPERTIES ───────────────────────────────────────────────────────────────
-- Lightweight reference here for auth scoping
-- Full property details will be in property-service
CREATE TABLE properties (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    name                    VARCHAR(100) NOT NULL,
    status                  VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    -- ACTIVE, INACTIVE, DELETED
    deleted_at              TIMESTAMP,
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─── USERS ────────────────────────────────────────────────────────────────────
CREATE TABLE users (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id                   UUID NOT NULL REFERENCES tenants(id),
    property_id                 UUID REFERENCES properties(id),
    -- NULL = tenant-level user (group owner/manager)
    -- NOT NULL = property-level user (front desk, housekeeping)
    email                       VARCHAR(100) NOT NULL,
    phone                       VARCHAR(20),
    first_name                  VARCHAR(50) NOT NULL,
    last_name                   VARCHAR(50) NOT NULL,
    designation                 VARCHAR(100),
    status                      VARCHAR(30) NOT NULL DEFAULT 'PENDING_INVITATION',
    -- PENDING_INVITATION, ACTIVE, LOCKED, SUSPENDED, DELETED
    is_tenant_owner             BOOLEAN NOT NULL DEFAULT FALSE,
    email_verified              BOOLEAN NOT NULL DEFAULT FALSE,
    email_verified_at           TIMESTAMP,
    force_password_change       BOOLEAN NOT NULL DEFAULT TRUE,
    failed_login_attempts       INT NOT NULL DEFAULT 0,
    locked_at                   TIMESTAMP,
    last_login_at               TIMESTAMP,
    last_login_ip               VARCHAR(45),
    deleted_at                  TIMESTAMP,
    created_at                  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, email)
);

-- ─── USER PASSWORDS ───────────────────────────────────────────────────────────
CREATE TABLE user_passwords (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL REFERENCES users(id),
    password_hash           VARCHAR(255) NOT NULL,
    is_current              BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─── USER SESSIONS ────────────────────────────────────────────────────────────
CREATE TABLE user_sessions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL REFERENCES users(id),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    property_id             UUID REFERENCES properties(id),
    refresh_token_hash      VARCHAR(255) NOT NULL,
    token_family            UUID NOT NULL DEFAULT uuid_generate_v4(),
    -- token family for refresh token rotation attack detection
    device_info             VARCHAR(255),
    ip_address              VARCHAR(45),
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at              TIMESTAMP NOT NULL,
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─── ROLES ────────────────────────────────────────────────────────────────────
CREATE TABLE roles (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id               UUID REFERENCES tenants(id),
    -- NULL = system predefined role
    name                    VARCHAR(50) NOT NULL,
    description             VARCHAR(255),
    scope                   VARCHAR(20) NOT NULL DEFAULT 'PROPERTY',
    -- TENANT = group level, PROPERTY = property level
    is_system_role          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, name)
);

-- ─── PERMISSIONS ──────────────────────────────────────────────────────────────
CREATE TABLE permissions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module                  VARCHAR(50) NOT NULL,
    -- PROPERTY, RESERVATION, BILLING, HOUSEKEEPING, REPORT, USER, SETTLEMENT
    action                  VARCHAR(50) NOT NULL,
    -- CREATE, READ, UPDATE, DELETE, APPROVE, EXPORT
    description             VARCHAR(255),
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(module, action)
);

-- ─── ROLE PERMISSIONS ─────────────────────────────────────────────────────────
CREATE TABLE role_permissions (
    role_id                 UUID NOT NULL REFERENCES roles(id),
    permission_id           UUID NOT NULL REFERENCES permissions(id),
    PRIMARY KEY (role_id, permission_id)
);

-- ─── USER ROLES ───────────────────────────────────────────────────────────────
CREATE TABLE user_roles (
    user_id                 UUID NOT NULL REFERENCES users(id),
    role_id                 UUID NOT NULL REFERENCES roles(id),
    property_id             UUID REFERENCES properties(id),
    -- NULL = tenant-level role assignment
    -- NOT NULL = property-level role assignment
    assigned_at             TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at              TIMESTAMP,
    assigned_by             UUID REFERENCES users(id),
    PRIMARY KEY (user_id, role_id)
);

-- ─── OTP TOKENS ───────────────────────────────────────────────────────────────
CREATE TABLE otp_tokens (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL REFERENCES users(id),
    token_hash              VARCHAR(255) NOT NULL,
    type                    VARCHAR(30) NOT NULL,
    -- EMAIL_VERIFICATION, PASSWORD_RESET, MFA_LOGIN
    is_used                 BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at              TIMESTAMP NOT NULL,
    created_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─── AUDIT LOGS ───────────────────────────────────────────────────────────────
CREATE TABLE audit_logs (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id               UUID REFERENCES tenants(id),
    property_id             UUID REFERENCES properties(id),
    user_id                 UUID REFERENCES users(id),
    action                  VARCHAR(50) NOT NULL,
    -- LOGIN, LOGOUT, PASSWORD_CHANGE, ROLE_ASSIGNED, TOKEN_REFRESH etc.
    entity_type             VARCHAR(50),
    entity_id               UUID,
    old_value               JSONB,
    new_value               JSONB,
    ip_address              VARCHAR(45),
    user_agent              VARCHAR(255),
    status                  VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
    -- SUCCESS, FAILED
    created_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─── INDEXES ──────────────────────────────────────────────────────────────────
CREATE INDEX idx_tenants_subdomain ON tenants(subdomain);
CREATE INDEX idx_tenants_status ON tenants(status);
CREATE INDEX idx_properties_tenant_id ON properties(tenant_id);
CREATE INDEX idx_users_tenant_id ON users(tenant_id);
CREATE INDEX idx_users_property_id ON users(property_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_user_passwords_user_id ON user_passwords(user_id);
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_refresh_token ON user_sessions(refresh_token_hash);
CREATE INDEX idx_user_sessions_token_family ON user_sessions(token_family);
CREATE INDEX idx_otp_tokens_user_id ON otp_tokens(user_id);
CREATE INDEX idx_otp_tokens_type ON otp_tokens(type);
CREATE INDEX idx_audit_logs_tenant_id ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);

-- ─── SEED SYSTEM ROLES ────────────────────────────────────────────────────────
INSERT INTO roles (id, name, description, scope, is_system_role) VALUES
-- Tenant/Group level roles
(uuid_generate_v4(), 'GROUP_OWNER',         'Hotel group owner, full access to all properties',     'TENANT',   TRUE),
(uuid_generate_v4(), 'GROUP_MANAGER',       'Manages operations across all properties',             'TENANT',   TRUE),
(uuid_generate_v4(), 'GROUP_ACCOUNTANT',    'Finance and settlements across all properties',        'TENANT',   TRUE),
-- Property level roles
(uuid_generate_v4(), 'PROPERTY_GM',         'General manager of a single property',                 'PROPERTY', TRUE),
(uuid_generate_v4(), 'FRONT_DESK',          'Handles reservations, check-in and check-out',         'PROPERTY', TRUE),
(uuid_generate_v4(), 'HOUSEKEEPING',        'Manages room cleaning and status',                     'PROPERTY', TRUE),
(uuid_generate_v4(), 'PROPERTY_ACCOUNTANT', 'Manages billing and reports for a property',           'PROPERTY', TRUE);

-- ─── SEED PERMISSIONS ─────────────────────────────────────────────────────────
INSERT INTO permissions (module, action) VALUES
-- Property
('PROPERTY', 'CREATE'), ('PROPERTY', 'READ'), ('PROPERTY', 'UPDATE'), ('PROPERTY', 'DELETE'),
-- Room
('ROOM', 'CREATE'), ('ROOM', 'READ'), ('ROOM', 'UPDATE'), ('ROOM', 'DELETE'),
-- Reservation
('RESERVATION', 'CREATE'), ('RESERVATION', 'READ'), ('RESERVATION', 'UPDATE'), ('RESERVATION', 'DELETE'), ('RESERVATION', 'APPROVE'),
-- Billing
('BILLING', 'CREATE'), ('BILLING', 'READ'), ('BILLING', 'UPDATE'), ('BILLING', 'APPROVE'), ('BILLING', 'EXPORT'),
-- Housekeeping
('HOUSEKEEPING', 'CREATE'), ('HOUSEKEEPING', 'READ'), ('HOUSEKEEPING', 'UPDATE'),
-- Report
('REPORT', 'READ'), ('REPORT', 'EXPORT'),
-- User
('USER', 'CREATE'), ('USER', 'READ'), ('USER', 'UPDATE'), ('USER', 'DELETE'),
-- Settlement
('SETTLEMENT', 'CREATE'), ('SETTLEMENT', 'READ'), ('SETTLEMENT', 'APPROVE'), ('SETTLEMENT', 'EXPORT'),
-- Audit
('AUDIT', 'READ');

-- ─── SEED SUBSCRIPTION PLANS ──────────────────────────────────────────────────
-- These will be referenced when tenant registers
-- TRIAL:        1 property,   20 rooms,  5 users,  30 days
-- BASIC:        1 property,   50 rooms,  10 users
-- PROFESSIONAL: 5 properties, 200 rooms, 50 users
-- ENTERPRISE:   unlimited