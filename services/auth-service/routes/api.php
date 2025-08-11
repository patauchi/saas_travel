<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\TenantController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

// Health check
Route::get('/health', function () {
    return response()->json([
        'success' => true,
        'service' => 'auth-service',
        'status' => 'healthy',
        'timestamp' => now()->toIso8601String()
    ]);
});

// Public tenant lookup
Route::post('/tenant/lookup', [TenantController::class, 'findBySlugOrDomain']);

// Authentication routes
Route::group(['prefix' => 'auth'], function () {
    Route::post('login', [AuthController::class, 'login']);
    Route::post('register', [AuthController::class, 'register']);
    Route::post('logout', [AuthController::class, 'logout']);
    Route::post('refresh', [AuthController::class, 'refresh']);

    // Protected auth routes
    Route::middleware('auth:api')->group(function () {
        Route::get('me', [AuthController::class, 'me']);
        Route::put('profile', [AuthController::class, 'updateProfile']);
        Route::post('change-password', [AuthController::class, 'changePassword']);
    });
});

// Tenant management routes (protected)
Route::middleware('auth:api')->group(function () {
    Route::apiResource('tenants', TenantController::class);

    // Additional tenant routes
    Route::post('tenants/{id}/activate', [TenantController::class, 'activate']);
    Route::post('tenants/{id}/suspend', [TenantController::class, 'suspend']);
    Route::post('tenants/{id}/restore', [TenantController::class, 'restore']);
    Route::get('tenants/{id}/users', [TenantController::class, 'users']);
    Route::post('tenants/{id}/users', [TenantController::class, 'addUser']);
    Route::delete('tenants/{id}/users/{userId}', [TenantController::class, 'removeUser']);
});

// User management routes (for admins)
Route::middleware(['auth:api'])->prefix('users')->group(function () {
    Route::get('/', function (Request $request) {
        $user = auth('api')->user();

        if (!$user->isAdmin()) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized'
            ], 403);
        }

        $users = \App\Models\User::where('tenant_id', $user->tenant_id)
            ->paginate($request->per_page ?? 15);

        return response()->json([
            'success' => true,
            'data' => $users
        ]);
    });

    Route::post('/', function (Request $request) {
        $user = auth('api')->user();

        if (!$user->isAdmin()) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized'
            ], 403);
        }

        $validator = \Illuminate\Support\Facades\Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users',
            'password' => 'required|min:6',
            'role' => 'in:user,manager,admin'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $newUser = \App\Models\User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => \Illuminate\Support\Facades\Hash::make($request->password),
            'tenant_id' => $user->tenant_id,
            'role' => $request->role ?? 'user',
            'is_active' => true
        ]);

        return response()->json([
            'success' => true,
            'data' => $newUser
        ], 201);
    });

    Route::put('/{id}', function (Request $request, $id) {
        $user = auth('api')->user();

        if (!$user->isAdmin()) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized'
            ], 403);
        }

        $targetUser = \App\Models\User::where('tenant_id', $user->tenant_id)
            ->find($id);

        if (!$targetUser) {
            return response()->json([
                'success' => false,
                'message' => 'User not found'
            ], 404);
        }

        $validator = \Illuminate\Support\Facades\Validator::make($request->all(), [
            'name' => 'string|max:255',
            'email' => 'email|unique:users,email,' . $id,
            'role' => 'in:user,manager,admin',
            'is_active' => 'boolean'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $targetUser->update($request->only(['name', 'email', 'role', 'is_active']));

        return response()->json([
            'success' => true,
            'data' => $targetUser
        ]);
    });

    Route::delete('/{id}', function ($id) {
        $user = auth('api')->user();

        if (!$user->isAdmin()) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized'
            ], 403);
        }

        $targetUser = \App\Models\User::where('tenant_id', $user->tenant_id)
            ->find($id);

        if (!$targetUser) {
            return response()->json([
                'success' => false,
                'message' => 'User not found'
            ], 404);
        }

        if ($targetUser->id === $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Cannot delete yourself'
            ], 400);
        }

        $targetUser->delete();

        return response()->json([
            'success' => true,
            'message' => 'User deleted successfully'
        ]);
    });
});

// Get current tenant info
Route::middleware('auth:api')->get('/current-tenant', function () {
    $user = auth('api')->user();
    $tenant = \App\Models\Tenant::find($user->tenant_id);

    if (!$tenant) {
        return response()->json([
            'success' => false,
            'message' => 'Tenant not found'
        ], 404);
    }

    return response()->json([
        'success' => true,
        'data' => [
            'id' => $tenant->id,
            'name' => $tenant->name,
            'slug' => $tenant->slug,
            'domain' => $tenant->domain,
            'plan' => $tenant->plan,
            'features' => $tenant->features,
            'trial_ends_at' => $tenant->trial_ends_at,
            'subscription_ends_at' => $tenant->subscription_ends_at,
            'user_count' => $tenant->users()->count(),
            'max_users' => $tenant->max_users
        ]
    ]);
});

// Plans information (public)
Route::get('/plans', function () {
    return response()->json([
        'success' => true,
        'data' => [
            [
                'id' => 'basic',
                'name' => 'Basic',
                'price' => 29.99,
                'currency' => 'USD',
                'billing_period' => 'monthly',
                'features' => [
                    'max_users' => 5,
                    'max_storage' => '1GB',
                    'bookings' => true,
                    'reports' => false,
                    'api_access' => false,
                    'custom_domain' => false,
                    'support' => 'email'
                ]
            ],
            [
                'id' => 'professional',
                'name' => 'Professional',
                'price' => 99.99,
                'currency' => 'USD',
                'billing_period' => 'monthly',
                'features' => [
                    'max_users' => 25,
                    'max_storage' => '10GB',
                    'bookings' => true,
                    'reports' => true,
                    'api_access' => true,
                    'custom_domain' => false,
                    'support' => 'priority'
                ]
            ],
            [
                'id' => 'enterprise',
                'name' => 'Enterprise',
                'price' => 299.99,
                'currency' => 'USD',
                'billing_period' => 'monthly',
                'features' => [
                    'max_users' => 'unlimited',
                    'max_storage' => 'unlimited',
                    'bookings' => true,
                    'reports' => true,
                    'api_access' => true,
                    'custom_domain' => true,
                    'support' => 'dedicated'
                ]
            ]
        ]
    ]);
});
