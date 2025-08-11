<?php

declare(strict_types=1);

use Stancl\Tenancy\Database\Models\Domain;
use Stancl\Tenancy\Database\Models\Tenant;

return [
    "tenant_model" => \App\Models\Tenant::class,
    "id_generator" => Stancl\Tenancy\UUIDGenerator::class,

    "domain_model" => Domain::class,

    /**
     * The list of domains hosting your central app.
     *
     * Only relevant if you're using the domain or subdomain identification middleware.
     */
    "central_domains" => [
        "127.0.0.1",
        "localhost",
        "central-management",
        env("APP_URL", "http://localhost:8001"),
    ],

    /**
     * Tenancy bootstrappers are executed when tenancy is initialized.
     * Their responsibility is making Laravel features tenant-aware.
     *
     * To configure their behavior, see the config keys below.
     */
    "bootstrappers" => [
        Stancl\Tenancy\Bootstrappers\DatabaseTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\CacheTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\FilesystemTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\QueueTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\RedisTenancyBootstrapper::class,
    ],

    /**
     * Database tenancy config. Used by DatabaseTenancyBootstrapper.
     */
    "database" => [
        "central_connection" => "pgsql",

        /**
         * Connection used as a "template" for the dynamically created tenant database connection.
         * Note: don't name your template connection tenant. That name is reserved by package.
         */
        "template_tenant_connection" => "pgsql_tenant",

        /**
         * Tenant database names are created like this:
         * prefix + tenant_id + suffix.
         */
        "prefix" => "",
        "suffix" => "",

        /**
         * TenantDatabaseManagers are classes that handle the creation & deletion of tenant databases.
         * For PostgreSQL with schemas, we use PostgreSQLSchemaManager
         */
        "managers" => [
            "pgsql" =>
                Stancl\Tenancy\TenantDatabaseManagers\PostgreSQLSchemaManager::class,
        ],

        /**
         * Use a different database server for the tenant databases.
         * Using a separate server is good for scaling, but adds complexity.
         */
        "tenant_database_cluster" => env("TENANCY_DB_CLUSTER", false),
    ],

    /**
     * Cache tenancy config. Used by CacheTenancyBootstrapper.
     *
     * This works for all cache stores except dynamodb.
     */
    "cache" => [
        "tag_base" => "tenant", // This tag_base, followed by the tenant_id, will form a tag that will be applied on each cache call.
    ],

    /**
     * Filesystem tenancy config. Used by FilesystemTenancyBootstrapper.
     */
    "filesystem" => [
        /**
         * Each disk listed in the 'disks' array will be suffixed by the tenant's tenant key,
         * to avoid tenant conflicts in storage.
         */
        "disks" => [
            "local",
            "public",
            // 's3',
        ],

        /**
         * Use this for local disks.
         */
        "root_override" => [
            // Disks whose roots should be overridden after storage_path() is suffixed.
            "local" => "%storage_path%/app/",
            "public" => "%storage_path%/app/public/",
        ],

        /**
         * Should storage_path() be suffixed.
         *
         * Note: Disabling this will likely break local disk tenancy. Only disable this if you're using an external file storage service like S3.
         *
         * For the vast majority of applications, this feature should be enabled. But in some
         * edge cases, it can cause issues (like using Passport with Vapor - see #196), so
         * you may want to disable this if you are experiencing these edge case issues.
         */
        "suffix_storage_path" => true,

        /**
         * By default, asset() calls are made multi-tenant too. You can use asset_unaware() and global_asset() to use
         * the global behaviour of asset().
         *
         * You can disable this by setting it to false. This essentially makes asset() behave like asset_unaware().
         */
        "asset_helper_tenancy" => true,
    ],

    /**
     * Redis tenancy config. Used by RedisTenancyBootstrapper.
     *
     * Note: You need phpredis to use Redis tenancy.
     *
     * Note: You don't need to use this if you're using Redis only for cache.
     * Redis tenancy is only relevant if you're using Redis for things like jobs, Broadcasting, etc.
     */
    "redis" => [
        "prefix_base" => "tenant",
        "prefixed_connections" => [
            // Redis connections whose keys are prefixed, to separate one tenant's keys from another.
            "default",
            "cache",
            "queue",
        ],
    ],

    /**
     * Features are classes that provide additional functionality
     * not needed for the tenancy to be bootstrapped. They are run
     * regardless of whether tenancy has been initialized.
     *
     * See the documentation page for each class to find out more.
     */
    "features" => [
        // Stancl\Tenancy\Features\UserImpersonation::class,
        // Stancl\Tenancy\Features\TelescopeTags::class,
        // Stancl\Tenancy\Features\UniversalRoutes::class,
        // Stancl\Tenancy\Features\TenantConfig::class,
        // Stancl\Tenancy\Features\CrossDomainRedirect::class,
        // Stancl\Tenancy\Features\ViteBundler::class,
    ],

    /**
     * Should tenancy routes be registered.
     *
     * Tenancy routes include tenant asset routes. By default, this route is
     * enabled. But it may be useful to disable them if you use external
     * storage (e.g. S3 / Cloudfront) for static assets.
     */
    "routes" => true,

    /**
     * Parameters used by the tenants:migrate command.
     */
    "migration_parameters" => [
        "--force" => true, // This needs to be true to run migrations in production.
        "--path" => [database_path("migrations/tenant")],
        "--schema" => "public", // The default PostgreSQL schema
    ],

    /**
     * Parameters used by the tenants:seed command.
     */
    "seeder_parameters" => [
        "--class" => "TenantDatabaseSeeder", // Tenant seeder class
        "--force" => true,
    ],
];
