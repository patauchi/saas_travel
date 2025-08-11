<?php
// Simple login endpoint for testing
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

// Get the JSON input
$input = json_decode(file_get_contents('php://input'), true);

// Check for required fields
if (!isset($input['email']) || !isset($input['password'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Email and password are required'
    ]);
    exit();
}

// Simple hardcoded validation for admin user
if ($input['email'] === 'admin@vtravel.com' && $input['password'] === 'admin123') {
    // Generate a simple token (in production, use proper JWT)
    $token = base64_encode(json_encode([
        'user_id' => 1,
        'email' => 'admin@vtravel.com',
        'role' => 'super_admin',
        'exp' => time() + 3600
    ]));

    echo json_encode([
        'success' => true,
        'data' => [
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => 3600,
            'user' => [
                'id' => 1,
                'name' => 'Super Admin',
                'email' => 'admin@vtravel.com',
                'role' => 'super_admin',
                'tenant_id' => 1
            ]
        ]
    ]);
} else {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid credentials'
    ]);
}
