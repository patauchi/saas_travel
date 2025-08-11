-- =============================================
-- VTravel SaaS Platform - Landlord Database
-- =============================================

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- =============================================
-- TENANTS MANAGEMENT
-- =============================================

-- Tenants table
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255) UNIQUE,
    subdomain VARCHAR(100) UNIQUE NOT NULL,
    database_name VARCHAR(100) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'trial', 'pending')),
    owner_id UUID,
    settings JSONB DEFAULT '{}',
    features JSONB DEFAULT '[]',
    limits JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activated_at TIMESTAMP,
    suspended_at TIMESTAMP,
    deleted_at TIMESTAMP
);

-- Plans table
CREATE TABLE plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    billing_period VARCHAR(20) DEFAULT 'monthly' CHECK (billing_period IN ('monthly', 'yearly', 'lifetime')),
    trial_days INTEGER DEFAULT 0,
    features JSONB DEFAULT '[]',
    limits JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions table
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES plans(id),
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'canceled', 'expired', 'trial', 'past_due')),
    start_date DATE NOT NULL,
    end_date DATE,
    trial_ends_at DATE,
    canceled_at TIMESTAMP,
    payment_method VARCHAR(50),
    stripe_subscription_id VARCHAR(255),
    stripe_customer_id VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Invoices table
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id),
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'canceled', 'refunded')),
    due_date DATE,
    paid_at TIMESTAMP,
    stripe_invoice_id VARCHAR(255),
    payment_intent_id VARCHAR(255),
    line_items JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tenant domains table
CREATE TABLE tenant_domains (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    domain VARCHAR(255) UNIQUE NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    verification_token VARCHAR(255),
    ssl_status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMP
);

-- Tenant users association
CREATE TABLE tenant_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    role VARCHAR(50) DEFAULT 'member',
    permissions JSONB DEFAULT '[]',
    is_owner BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_access TIMESTAMP,
    UNIQUE(tenant_id, user_id)
);

-- Activity logs
CREATE TABLE activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100),
    entity_id VARCHAR(255),
    description TEXT,
    old_values JSONB,
    new_values JSONB,
    metadata JSONB DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System settings
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT,
    type VARCHAR(50) DEFAULT 'string',
    category VARCHAR(100),
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit logs
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID,
    event_type VARCHAR(100) NOT NULL,
    event_name VARCHAR(255),
    description TEXT,
    request_id VARCHAR(100),
    session_id VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    request_method VARCHAR(10),
    request_url TEXT,
    response_status INTEGER,
    duration_ms INTEGER,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- INDEXES
-- =============================================

CREATE INDEX idx_tenants_slug ON tenants(slug);
CREATE INDEX idx_tenants_subdomain ON tenants(subdomain);
CREATE INDEX idx_tenants_status ON tenants(status);
CREATE INDEX idx_tenants_created_at ON tenants(created_at);

CREATE INDEX idx_subscriptions_tenant_id ON subscriptions(tenant_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_end_date ON subscriptions(end_date);

CREATE INDEX idx_invoices_tenant_id ON invoices(tenant_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);

CREATE INDEX idx_tenant_users_tenant_id ON tenant_users(tenant_id);
CREATE INDEX idx_tenant_users_user_id ON tenant_users(user_id);

CREATE INDEX idx_activity_logs_tenant_id ON activity_logs(tenant_id);
CREATE INDEX idx_activity_logs_created_at ON activity_logs(created_at);
CREATE INDEX idx_activity_logs_action ON activity_logs(action);

CREATE INDEX idx_audit_logs_tenant_id ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_event_type ON audit_logs(event_type);

-- =============================================
-- FUNCTIONS AND TRIGGERS
-- =============================================

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update trigger to tables
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_plans_updated_at BEFORE UPDATE ON plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to generate invoice number
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS VARCHAR AS $$
DECLARE
    year_month VARCHAR(6);
    last_number INTEGER;
    new_number VARCHAR(50);
BEGIN
    year_month := TO_CHAR(CURRENT_DATE, 'YYYYMM');

    SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_number FROM 8) AS INTEGER)), 0) + 1
    INTO last_number
    FROM invoices
    WHERE invoice_number LIKE year_month || '-%';

    new_number := year_month || '-' || LPAD(last_number::TEXT, 5, '0');

    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- DEFAULT DATA
-- =============================================

-- Insert default plans
INSERT INTO plans (name, display_name, description, price, billing_period, trial_days, features, limits, is_default, sort_order)
VALUES
    ('free', 'Free Plan', 'Perfect for getting started', 0, 'monthly', 14,
     '["5 users", "1 GB storage", "Basic support", "Email integration"]'::jsonb,
     '{"users": 5, "storage_gb": 1, "api_calls_per_month": 1000, "emails_per_month": 100}'::jsonb,
     true, 1),

    ('starter', 'Starter Plan', 'Great for small agencies', 29.99, 'monthly', 14,
     '["25 users", "10 GB storage", "Priority support", "API access", "WhatsApp integration", "Custom domain"]'::jsonb,
     '{"users": 25, "storage_gb": 10, "api_calls_per_month": 10000, "emails_per_month": 1000}'::jsonb,
     false, 2),

    ('professional', 'Professional Plan', 'For growing agencies', 99.99, 'monthly', 14,
     '["100 users", "100 GB storage", "24/7 support", "Advanced API", "All integrations", "Custom reports", "White label"]'::jsonb,
     '{"users": 100, "storage_gb": 100, "api_calls_per_month": 100000, "emails_per_month": 10000}'::jsonb,
     false, 3),

    ('enterprise', 'Enterprise Plan', 'Unlimited everything', 299.99, 'monthly', 30,
     '["Unlimited users", "Unlimited storage", "Dedicated support", "Custom features", "SLA", "Training", "Custom integrations"]'::jsonb,
     '{"users": -1, "storage_gb": -1, "api_calls_per_month": -1, "emails_per_month": -1}'::jsonb,
     false, 4);

-- Insert system settings
INSERT INTO system_settings (key, value, type, category, description, is_public)
VALUES
    ('app_name', 'VTravel', 'string', 'general', 'Application name', true),
    ('app_version', '1.0.0', 'string', 'general', 'Application version', true),
    ('maintenance_mode', 'false', 'boolean', 'general', 'Maintenance mode status', true),
    ('allow_registration', 'true', 'boolean', 'auth', 'Allow new tenant registration', false),
    ('default_language', 'en', 'string', 'localization', 'Default language', true),
    ('default_timezone', 'UTC', 'string', 'localization', 'Default timezone', true),
    ('max_file_size', '10485760', 'integer', 'storage', 'Maximum file size in bytes (10MB)', false),
    ('session_lifetime', '120', 'integer', 'auth', 'Session lifetime in minutes', false),
    ('password_min_length', '8', 'integer', 'auth', 'Minimum password length', false),
    ('enable_2fa', 'false', 'boolean', 'auth', 'Enable two-factor authentication', false);

-- Create demo tenant for development
INSERT INTO tenants (slug, name, subdomain, database_name, status, settings, features)
VALUES
    ('demo', 'Demo Agency', 'demo', 'tenant_demo', 'active',
     '{"theme": "default", "language": "en", "timezone": "UTC"}'::jsonb,
     '["crm", "sales", "financial", "operations", "communication"]'::jsonb);

-- Create subscription for demo tenant
INSERT INTO subscriptions (tenant_id, plan_id, status, start_date, trial_ends_at)
SELECT
    t.id,
    p.id,
    'trial',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '14 days'
FROM tenants t, plans p
WHERE t.slug = 'demo' AND p.name = 'professional';

-- =============================================
-- GRANTS
-- =============================================

-- Grant permissions to the application user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vtravel;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO vtravel;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO vtravel;
