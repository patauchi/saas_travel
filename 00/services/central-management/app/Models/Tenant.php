<?php

namespace App\Models;

use Stancl\Tenancy\Database\Models\Tenant as BaseTenant;
use Stancl\Tenancy\Contracts\TenantWithDatabase;
use Stancl\Tenancy\Database\Concerns\HasDatabase;
use Stancl\Tenancy\Database\Concerns\HasDomains;

class Tenant extends BaseTenant implements TenantWithDatabase
{
    use HasDatabase, HasDomains;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<string>
     */
    protected $fillable = [
        'id',
        'name',
        'email',
        'phone',
        'address',
        'city',
        'state',
        'country',
        'postal_code',
        'plan',
        'status',
        'trial_ends_at',
        'subscription_ends_at',
        'data',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'data' => 'array',
        'trial_ends_at' => 'datetime',
        'subscription_ends_at' => 'datetime',
    ];

    /**
     * Get the database name for this tenant.
     * For PostgreSQL schemas, we use the same database but different schemas.
     *
     * @return string
     */
    public function database(): string
    {
        // For PostgreSQL schema separation, we return the tenant ID
        // which will be used as the schema name
        return $this->getTenantKey();
    }

    /**
     * Get the tenant's schema name.
     *
     * @return string
     */
    public function getSchemaName(): string
    {
        return 'tenant_' . $this->getTenantKey();
    }

    /**
     * Check if tenant is active.
     *
     * @return bool
     */
    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    /**
     * Check if tenant is in trial period.
     *
     * @return bool
     */
    public function isOnTrial(): bool
    {
        return $this->trial_ends_at && $this->trial_ends_at->isFuture();
    }

    /**
     * Check if tenant has an active subscription.
     *
     * @return bool
     */
    public function hasActiveSubscription(): bool
    {
        return $this->subscription_ends_at && $this->subscription_ends_at->isFuture();
    }

    /**
     * Get tenant's current plan.
     *
     * @return string
     */
    public function getPlan(): string
    {
        return $this->plan ?? 'free';
    }

    /**
     * Update tenant's plan.
     *
     * @param string $plan
     * @return bool
     */
    public function updatePlan(string $plan): bool
    {
        return $this->update(['plan' => $plan]);
    }

    /**
     * Suspend tenant.
     *
     * @return bool
     */
    public function suspend(): bool
    {
        return $this->update(['status' => 'suspended']);
    }

    /**
     * Activate tenant.
     *
     * @return bool
     */
    public function activate(): bool
    {
        return $this->update(['status' => 'active']);
    }

    /**
     * Get tenant configuration.
     *
     * @param string|null $key
     * @return mixed
     */
    public function getConfig(?string $key = null)
    {
        $data = $this->data ?? [];

        if ($key === null) {
            return $data;
        }

        return data_get($data, $key);
    }

    /**
     * Set tenant configuration.
     *
     * @param string $key
     * @param mixed $value
     * @return bool
     */
    public function setConfig(string $key, $value): bool
    {
        $data = $this->data ?? [];
        data_set($data, $key, $value);

        return $this->update(['data' => $data]);
    }

    /**
     * Get tenant's database connection configuration.
     *
     * @return array
     */
    public function getDatabaseConfig(): array
    {
        return [
            'driver' => 'pgsql',
            'host' => env('TENANCY_DB_HOST', env('DB_HOST', 'postgres-tenants')),
            'port' => env('TENANCY_DB_PORT', env('DB_PORT', 5432)),
            'database' => env('TENANCY_DB_DATABASE', env('DB_DATABASE', 'postgres')),
            'username' => env('TENANCY_DB_USERNAME', env('DB_USERNAME', 'laravel_user')),
            'password' => env('TENANCY_DB_PASSWORD', env('DB_PASSWORD', '')),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'schema' => $this->getSchemaName(),
            'sslmode' => 'prefer',
        ];
    }

    /**
     * Bootstrap tenant-specific configurations.
     *
     * @return void
     */
    public function bootstrap(): void
    {
        // Set tenant-specific configurations here
        config([
            'app.name' => $this->name,
            'mail.from.name' => $this->name,
            'tenant.id' => $this->id,
            'tenant.name' => $this->name,
            'tenant.plan' => $this->plan,
        ]);
    }

    /**
     * Create default data for new tenant.
     *
     * @return void
     */
    public function createDefaultData(): void
    {
        // This method can be called after tenant creation
        // to set up default data, settings, users, etc.
        tenancy()->initialize($this);

        // Create default admin user
        // Create default settings
        // Create default roles and permissions
        // etc.

        tenancy()->end();
    }
}
