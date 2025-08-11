<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class TenantController extends Controller
{
    /**
     * Create a new TenantController instance.
     *
     * @return void
     */
    public function __construct()
    {
        $this->middleware("auth:api");
    }

    /**
     * Display a listing of tenants.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function index(Request $request)
    {
        $user = auth("api")->user();

        if (!$user->isSuperAdmin()) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Unauthorized",
                ],
                403,
            );
        }

        $query = Tenant::query();

        if ($request->has("status")) {
            $query->where("status", $request->status);
        }

        if ($request->has("search")) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where("name", "like", "%{$search}%")
                    ->orWhere("slug", "like", "%{$search}%")
                    ->orWhere("domain", "like", "%{$search}%");
            });
        }

        $tenants = $query
            ->withCount("users")
            ->paginate($request->per_page ?? 15);

        return response()->json([
            "success" => true,
            "data" => $tenants,
        ]);
    }

    /**
     * Store a newly created tenant.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "name" => "required|string|max:255",
            "slug" =>
                'required|string|max:255|unique:tenants,slug|regex:/^[a-z0-9-]+$/',
            "domain" => "nullable|string|max:255|unique:tenants,domain",
            "plan" => "required|in:basic,professional,enterprise",
            "owner_email" => "required|email",
            "owner_name" => "required|string|max:255",
            "owner_password" => "required|string|min:6",
            "trial_days" => "integer|min:0|max:90",
        ]);

        if ($validator->fails()) {
            return response()->json(
                [
                    "success" => false,
                    "errors" => $validator->errors(),
                ],
                422,
            );
        }

        DB::beginTransaction();

        try {
            // Create tenant
            $tenant = Tenant::create([
                "name" => $request->name,
                "slug" => $request->slug,
                "domain" => $request->domain,
                "plan" => $request->plan,
                "status" => "pending",
                "trial_ends_at" => $request->trial_days
                    ? now()->addDays($request->trial_days)
                    : null,
                "settings" => $request->settings ?? [],
                "features" => $this->getFeaturesForPlan($request->plan),
                "max_users" => $this->getMaxUsersForPlan($request->plan),
                "max_storage" => $this->getMaxStorageForPlan($request->plan),
            ]);

            // Create owner user
            $owner = User::create([
                "name" => $request->owner_name,
                "email" => $request->owner_email,
                "password" => Hash::make($request->owner_password),
                "tenant_id" => $tenant->id,
                "role" => "admin",
                "is_active" => true,
            ]);

            // Update tenant with owner
            $tenant->owner_id = $owner->id;
            $tenant->save();

            // Create tenant database
            $this->createTenantDatabase($tenant);

            // Activate tenant
            $tenant->status = "active";
            $tenant->save();

            DB::commit();

            return response()->json(
                [
                    "success" => true,
                    "message" => "Tenant created successfully",
                    "data" => $tenant->load("owner"),
                ],
                201,
            );
        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json(
                [
                    "success" => false,
                    "message" => "Failed to create tenant",
                    "error" => $e->getMessage(),
                ],
                500,
            );
        }
    }

    /**
     * Display the specified tenant.
     *
     * @param  int  $id
     * @return \Illuminate\Http\JsonResponse
     */
    public function show($id)
    {
        $user = auth("api")->user();
        $tenant = Tenant::with(["owner", "users"])->find($id);

        if (!$tenant) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Tenant not found",
                ],
                404,
            );
        }

        // Check authorization
        if (!$user->isSuperAdmin() && $user->tenant_id !== $tenant->id) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Unauthorized",
                ],
                403,
            );
        }

        return response()->json([
            "success" => true,
            "data" => $tenant,
        ]);
    }

    /**
     * Update the specified tenant.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\JsonResponse
     */
    public function update(Request $request, $id)
    {
        $user = auth("api")->user();
        $tenant = Tenant::find($id);

        if (!$tenant) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Tenant not found",
                ],
                404,
            );
        }

        // Check authorization
        if (
            !$user->isSuperAdmin() &&
            (!$user->isAdmin() || $user->tenant_id !== $tenant->id)
        ) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Unauthorized",
                ],
                403,
            );
        }

        $validator = Validator::make($request->all(), [
            "name" => "string|max:255",
            "domain" => "string|max:255|unique:tenants,domain," . $id,
            "plan" => "in:basic,professional,enterprise",
            "status" => "in:active,suspended,cancelled",
            "settings" => "array",
            "max_users" => "integer|min:1",
            "max_storage" => "integer|min:1",
        ]);

        if ($validator->fails()) {
            return response()->json(
                [
                    "success" => false,
                    "errors" => $validator->errors(),
                ],
                422,
            );
        }

        // Update plan features if plan changed
        if ($request->has("plan") && $request->plan !== $tenant->plan) {
            $request->merge([
                "features" => $this->getFeaturesForPlan($request->plan),
                "max_users" => $this->getMaxUsersForPlan($request->plan),
                "max_storage" => $this->getMaxStorageForPlan($request->plan),
            ]);
        }

        $tenant->update($request->all());

        return response()->json([
            "success" => true,
            "message" => "Tenant updated successfully",
            "data" => $tenant,
        ]);
    }

    /**
     * Remove the specified tenant.
     *
     * @param  int  $id
     * @return \Illuminate\Http\JsonResponse
     */
    public function destroy($id)
    {
        $user = auth("api")->user();

        if (!$user->isSuperAdmin()) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Unauthorized",
                ],
                403,
            );
        }

        $tenant = Tenant::find($id);

        if (!$tenant) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Tenant not found",
                ],
                404,
            );
        }

        // Soft delete tenant
        $tenant->delete();

        return response()->json([
            "success" => true,
            "message" => "Tenant deleted successfully",
        ]);
    }

    /**
     * Get tenant by slug or domain
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function findBySlugOrDomain(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "identifier" => "required|string",
        ]);

        if ($validator->fails()) {
            return response()->json(
                [
                    "success" => false,
                    "errors" => $validator->errors(),
                ],
                422,
            );
        }

        $tenant = Tenant::where("slug", $request->identifier)
            ->orWhere("domain", $request->identifier)
            ->first();

        if (!$tenant) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Tenant not found",
                ],
                404,
            );
        }

        return response()->json([
            "success" => true,
            "data" => [
                "id" => $tenant->id,
                "name" => $tenant->name,
                "slug" => $tenant->slug,
                "domain" => $tenant->domain,
                "status" => $tenant->status,
                "trial_ends_at" => $tenant->trial_ends_at,
            ],
        ]);
    }

    /**
     * Create database for tenant
     *
     * @param Tenant $tenant
     * @return void
     */
    private function createTenantDatabase(Tenant $tenant)
    {
        $databaseName = $tenant->database;

        // Create database
        DB::statement("CREATE DATABASE IF NOT EXISTS `{$databaseName}`");

        // You would typically run migrations here for the tenant database
        // This is a simplified version
    }

    /**
     * Get features for plan
     *
     * @param string $plan
     * @return array
     */
    private function getFeaturesForPlan(string $plan): array
    {
        $features = [
            "basic" => [
                "users" => true,
                "bookings" => true,
                "reports" => false,
                "api_access" => false,
                "custom_domain" => false,
            ],
            "professional" => [
                "users" => true,
                "bookings" => true,
                "reports" => true,
                "api_access" => true,
                "custom_domain" => false,
            ],
            "enterprise" => [
                "users" => true,
                "bookings" => true,
                "reports" => true,
                "api_access" => true,
                "custom_domain" => true,
            ],
        ];

        return $features[$plan] ?? $features["basic"];
    }

    /**
     * Get max users for plan
     *
     * @param string $plan
     * @return int
     */
    private function getMaxUsersForPlan(string $plan): int
    {
        $limits = [
            "basic" => 5,
            "professional" => 25,
            "enterprise" => null, // unlimited
        ];

        return $limits[$plan] ?? 5;
    }

    /**
     * Get max storage for plan (in MB)
     *
     * @param string $plan
     * @return int
     */
    private function getMaxStorageForPlan(string $plan): int
    {
        $limits = [
            "basic" => 1024, // 1GB
            "professional" => 10240, // 10GB
            "enterprise" => null, // unlimited
        ];

        return $limits[$plan] ?? 1024;
    }
}
