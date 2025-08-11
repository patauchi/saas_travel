<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Tenant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Tymon\JWTAuth\Facades\JWTAuth;
use Tymon\JWTAuth\Exceptions\JWTException;

class AuthController extends Controller
{
    /**
     * Create a new AuthController instance.
     *
     * @return void
     */
    public function __construct()
    {
        $this->middleware("auth:api", [
            "except" => ["login", "register", "refresh"],
        ]);
    }

    /**
     * Register a new user
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "name" => "required|string|max:255",
            "email" => "required|string|email|max:255|unique:users",
            "password" => "required|string|min:6|confirmed",
            "tenant_id" => "required|exists:tenants,id",
            "role" => "in:user,admin,manager",
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

        $tenant = Tenant::find($request->tenant_id);

        if (!$tenant->isActive()) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Tenant is not active",
                ],
                403,
            );
        }

        if (!$tenant->canAddUsers()) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Tenant has reached maximum user limit",
                ],
                403,
            );
        }

        $user = User::create([
            "name" => $request->name,
            "email" => $request->email,
            "password" => Hash::make($request->password),
            "tenant_id" => $request->tenant_id,
            "role" => $request->role ?? "user",
            "phone" => $request->phone,
        ]);

        $token = JWTAuth::fromUser($user);

        return $this->respondWithToken($token, $user);
    }

    /**
     * Get a JWT via given credentials.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "email" => "required|email",
            "password" => "required|string",
            "tenant_id" => "required|exists:tenants,id",
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

        $credentials = $request->only("email", "password");
        $credentials["tenant_id"] = $request->tenant_id;
        $credentials["is_active"] = true;

        try {
            if (!($token = auth("api")->attempt($credentials))) {
                return response()->json(
                    [
                        "success" => false,
                        "message" => "Invalid credentials",
                    ],
                    401,
                );
            }
        } catch (JWTException $e) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Could not create token",
                ],
                500,
            );
        }

        $user = auth("api")->user();
        $user->updateLastLogin();

        return $this->respondWithToken($token, $user);
    }

    /**
     * Get the authenticated User.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function me()
    {
        $user = auth("api")->user();
        $user->load("tenant");

        return response()->json([
            "success" => true,
            "data" => $user,
        ]);
    }

    /**
     * Log the user out (Invalidate the token).
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function logout()
    {
        auth("api")->logout();

        return response()->json([
            "success" => true,
            "message" => "Successfully logged out",
        ]);
    }

    /**
     * Refresh a token.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function refresh()
    {
        try {
            $token = auth("api")->refresh();
            return $this->respondWithToken($token);
        } catch (JWTException $e) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Could not refresh token",
                ],
                500,
            );
        }
    }

    /**
     * Change user password
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function changePassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "current_password" => "required|string",
            "new_password" => "required|string|min:6|confirmed",
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

        $user = auth("api")->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json(
                [
                    "success" => false,
                    "message" => "Current password is incorrect",
                ],
                400,
            );
        }

        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            "success" => true,
            "message" => "Password changed successfully",
        ]);
    }

    /**
     * Update user profile
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function updateProfile(Request $request)
    {
        $user = auth("api")->user();

        $validator = Validator::make($request->all(), [
            "name" => "string|max:255",
            "phone" => "string|max:20",
            "email" => "string|email|max:255|unique:users,email," . $user->id,
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

        $user->update($request->only(["name", "phone", "email"]));

        return response()->json([
            "success" => true,
            "message" => "Profile updated successfully",
            "data" => $user,
        ]);
    }

    /**
     * Get the token array structure.
     *
     * @param string $token
     * @param User|null $user
     * @return \Illuminate\Http\JsonResponse
     */
    protected function respondWithToken($token, $user = null)
    {
        $data = [
            "access_token" => $token,
            "token_type" => "bearer",
            "expires_in" => auth("api")->factory()->getTTL() * 60,
        ];

        if ($user) {
            $data["user"] = $user;
        }

        return response()->json([
            "success" => true,
            "data" => $data,
        ]);
    }
}
