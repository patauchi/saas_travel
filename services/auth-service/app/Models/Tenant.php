<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Tenant extends Model
{
    use HasFactory, SoftDeletes;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'slug',
        'domain',
        'database',
        'status',
        'plan',
        'trial_ends_at',
        'subscription_ends_at',
        'settings',
        'metadata',
        'owner_id',
        'max_users',
        'max_storage',
        'features',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'trial_ends_at' => 'datetime',
        'subscription_ends_at' => 'datetime',
        'settings' => 'array',
        'metadata' => 'array',
        'features' => 'array',
        'max_users' => 'integer',
        'max_storage' => 'integer',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'database',
    ];

    /**
     * Get the users for the tenant.
     */
    public function users()
    {
        return $this->hasMany(User::class);
    }

    /**
     * Get the owner of the tenant.
     */
    public function owner()
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    /**
     * Check if tenant is active
     */
    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    /**
     * Check if tenant is in trial
     */
    public function isInTrial(): bool
    {
        return $this->trial_ends_at && $this->trial_ends_at->isFuture();
    }

    /**
     * Check if tenant subscription is valid
     */
    public function hasValidSubscription(): bool
    {
        return $this->subscription_ends_at && $this->subscription_ends_at->isFuture();
    }

    /**
     * Check if tenant can add more users
     */
    public function canAddUsers(): bool
    {
        if (!$this->max_users) {
            return true;
        }
        return $this->users()->count() < $this->max_users;
    }

    /**
     * Get tenant by domain
     */
    public static function findByDomain(string $domain)
    {
        return static::where('domain', $domain)->first();
    }

    /**
     * Get tenant by slug
     */
    public static function findBySlug(string $slug)
    {
        return static::where('slug', $slug)->first();
    }

    /**
     * Generate database name for tenant
     */
    public function generateDatabaseName(): string
    {
        return 'tenant_' . $this->slug;
    }

    /**
     * Scope for active tenants
     */
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    /**
     * Scope for suspended tenants
     */
    public function scopeSuspended($query)
    {
        return $query->where('status', 'suspended');
    }

    /**
     * Boot method
     */
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($tenant) {
            if (!$tenant->database) {
                $tenant->database = $tenant->generateDatabaseName();
            }
            if (!$tenant->status) {
                $tenant->status = 'pending';
            }
        });
    }
}
