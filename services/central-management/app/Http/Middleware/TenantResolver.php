<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Log;

class TenantResolver
{
    /**
     * Cache TTL for tenant configuration (5 minutes)
     */
    private const CACHE_TTL = 300;

    /**
     * Maximum number of retries for fetching tenant config
     */
    private const MAX_RETRIES = 2;

    /**
     * Circuit breaker threshold
     */
    private const CIRCUIT_BREAKER_THRESHOLD = 5;

    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @return mixed
     */
    public function handle(Request $request, Closure $next)
    {
        // Check circuit breaker
        if ($this->isCircuitOpen()) {
            return $this->errorResponse("Service temporarily unavailable", 503);
        }

        // Extract tenant ID from request
        $tenantId = $this->extractTenantId($request);

        if (!$tenantId) {
            return $this->errorResponse("Tenant not specified", 400);
        }

        // Get tenant configuration
        $tenantConfig = $this->getTenantConfiguration($tenantId);

        if (!$tenantConfig) {
            return $this->errorResponse("Invalid tenant", 403);
        }

        // Check if tenant is active
        if (!$this->isTenantActive($tenantConfig)) {
            return $this->errorResponse("Tenant is not active", 403);
        }

        // Configure database connection for this request
        $this->configureTenantDatabase($tenantConfig);

        // Add tenant info to request
        $request->merge(["tenant" => $tenantConfig]);
        $request->attributes->set("tenant_id", $tenantId);
        $request->attributes->set("tenant_config", $tenantConfig);

        // Log tenant access
        $this->logTenantAccess($tenantId, $request);

        return $next($request);
    }

    /**
     * Extract tenant ID from various sources
     *
     * @param Request $request
     * @return string|null
     */
    private function extractTenantId(Request $request): ?string
    {
        // Priority 1: From header
        if ($request->hasHeader("X-Tenant-ID")) {
            return $request->header("X-Tenant-ID");
        }

        // Priority 2: From JWT token
        if ($user = $request->user()) {
            if (isset($user->tenant_id)) {
                return $user->tenant_id;
            }
        }

        // Priority 3: From subdomain
        $host = $request->getHost();
        if (preg_match("/^([a-z0-9]+(-[a-z0-9]+)*)\./", $host, $matches)) {
            // Skip common subdomains
            if (!in_array($matches[1], ["www", "api", "app", "admin"])) {
                return $matches[1];
            }
        }

        // Priority 4: From query parameter (only for GET requests)
        if ($request->isMethod("GET") && $request->has("tenant_id")) {
            return $request->query("tenant_id");
        }

        // Priority 5: From route parameter
        if ($request->route("tenant_id")) {
            return $request->route("tenant_id");
        }

        return null;
    }

    /**
     * Get tenant configuration from central management service
     *
     * @param string $tenantId
     * @return array|null
     */
    private function getTenantConfiguration(string $tenantId): ?array
    {
        $cacheKey = "tenant_config_{$tenantId}";

        return Cache::remember($cacheKey, self::CACHE_TTL, function () use (
            $tenantId,
        ) {
            $attempts = 0;
            $lastError = null;

            while ($attempts < self::MAX_RETRIES) {
                try {
                    $response = Http::timeout(5)
                        ->withHeaders([
                            "X-Service-Token" => $this->getServiceToken(),
                            "Accept" => "application/json",
                            "X-Request-ID" => request()->header(
                                "X-Request-ID",
                                uniqid(),
                            ),
                        ])
                        ->get(
                            $this->getCentralManagementUrl() .
                                "/api/tenants/{$tenantId}",
                        );

                    if ($response->successful()) {
                        $data = $response->json();
                        if (isset($data["success"]) && $data["success"]) {
                            $this->resetCircuitBreaker();
                            return $data["data"];
                        }
                    }

                    // Log unsuccessful response
                    Log::warning("Failed to fetch tenant configuration", [
                        "tenant_id" => $tenantId,
                        "status" => $response->status(),
                        "response" => $response->body(),
                        "attempt" => $attempts + 1,
                    ]);
                } catch (\Exception $e) {
                    $lastError = $e;
                    Log::error("Exception fetching tenant configuration", [
                        "tenant_id" => $tenantId,
                        "error" => $e->getMessage(),
                        "attempt" => $attempts + 1,
                    ]);
                }

                $attempts++;

                // Exponential backoff
                if ($attempts < self::MAX_RETRIES) {
                    usleep(100000 * pow(2, $attempts)); // 100ms, 200ms, 400ms...
                }
            }

            // Increment circuit breaker counter
            $this->incrementCircuitBreaker();

            return null;
        });
    }

    /**
     * Configure tenant database connection
     *
     * @param array $tenantConfig
     * @return void
     */
    private function configureTenantDatabase(array $tenantConfig): void
    {
        // Configure tenant database connection
        Config::set([
            "database.connections.tenant" => [
                "driver" => "pgsql",
                "host" =>
                    $tenantConfig["database_host"] ??
                    env("TENANCY_DB_HOST", "postgres-tenants"),
                "port" =>
                    $tenantConfig["database_port"] ??
                    env("TENANCY_DB_PORT", "5432"),
                "database" => $tenantConfig["database_name"],
                "username" =>
                    $tenantConfig["database_username"] ??
                    env("DB_USERNAME", "laravel_user"),
                "password" => $this->getDatabasePassword(),
                "charset" => "utf8",
                "prefix" => "",
                "prefix_indexes" => true,
                "schema" => "public",
                "sslmode" => "prefer",
                "search_path" => "public",
            ],
        ]);

        // Set as default connection for this request
        Config::set("database.default", "tenant");

        // Update cache configuration to be tenant-specific
        Config::set(
            "cache.prefix",
            "tenant_" . $tenantConfig["tenant_id"] . "_",
        );

        // Update session configuration
        Config::set(
            "session.cookie",
            "tenant_" . $tenantConfig["tenant_id"] . "_session",
        );
    }

    /**
     * Check if tenant is active
     *
     * @param array $tenantConfig
     * @return bool
     */
    private function isTenantActive(array $tenantConfig): bool
    {
        return isset($tenantConfig["status"]) &&
            $tenantConfig["status"] === "active";
    }

    /**
     * Check if circuit breaker is open
     *
     * @return bool
     */
    private function isCircuitOpen(): bool
    {
        $failures = Cache::get("tenant_resolver_failures", 0);
        return $failures >= self::CIRCUIT_BREAKER_THRESHOLD;
    }

    /**
     * Increment circuit breaker counter
     *
     * @return void
     */
    private function incrementCircuitBreaker(): void
    {
        $failures = Cache::get("tenant_resolver_failures", 0);
        Cache::put("tenant_resolver_failures", $failures + 1, 300); // Reset after 5 minutes
    }

    /**
     * Reset circuit breaker
     *
     * @return void
     */
    private function resetCircuitBreaker(): void
    {
        Cache::forget("tenant_resolver_failures");
    }

    /**
     * Log tenant access for auditing
     *
     * @param string $tenantId
     * @param Request $request
     * @return void
     */
    private function logTenantAccess(string $tenantId, Request $request): void
    {
        if (config("app.debug")) {
            Log::info("Tenant access", [
                "tenant_id" => $tenantId,
                "method" => $request->method(),
                "path" => $request->path(),
                "ip" => $request->ip(),
                "user_agent" => $request->userAgent(),
            ]);
        }
    }

    /**
     * Get service token for inter-service communication
     *
     * @return string
     */
    private function getServiceToken(): string
    {
        return config(
            "app.service_token",
            env("SERVICE_TOKEN", "default-service-token"),
        );
    }

    /**
     * Get central management service URL
     *
     * @return string
     */
    private function getCentralManagementUrl(): string
    {
        return config(
            "app.central_management_url",
            env("CENTRAL_MANAGEMENT_URL", "http://central-management"),
        );
    }

    /**
     * Get database password
     *
     * @return string
     */
    private function getDatabasePassword(): string
    {
        // Try to read from Docker secret first
        $secretPath = "/run/secrets/postgres_password";
        if (file_exists($secretPath)) {
            return trim(file_get_contents($secretPath));
        }

        return env("DB_PASSWORD", "password");
    }

    /**
     * Return error response
     *
     * @param string $message
     * @param int $status
     * @return \Illuminate\Http\JsonResponse
     */
    private function errorResponse(string $message, int $status)
    {
        return response()->json(
            [
                "success" => false,
                "message" => $message,
                "error_code" => $this->getErrorCode($status),
            ],
            $status,
        );
    }

    /**
     * Get error code based on status
     *
     * @param int $status
     * @return string
     */
    private function getErrorCode(int $status): string
    {
        return match ($status) {
            400 => "TENANT_NOT_SPECIFIED",
            403 => "INVALID_TENANT",
            503 => "SERVICE_UNAVAILABLE",
            default => "UNKNOWN_ERROR",
        };
    }
}
