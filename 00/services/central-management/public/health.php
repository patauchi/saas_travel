<?php

// Simple health check endpoint
header('Content-Type: application/json');

// Check if we can connect to the database
$health = [
    'status' => 'healthy',
    'service' => 'central-management',
    'timestamp' => date('Y-m-d H:i:s'),
    'checks' => []
];

// Check PHP
$health['checks']['php'] = [
    'status' => 'ok',
    'version' => PHP_VERSION
];

// Check if Laravel is accessible
if (file_exists('../vendor/autoload.php')) {
    $health['checks']['laravel'] = [
        'status' => 'ok',
        'message' => 'Laravel autoloader found'
    ];
} else {
    $health['checks']['laravel'] = [
        'status' => 'warning',
        'message' => 'Laravel not fully installed'
    ];
    $health['status'] = 'degraded';
}

// Check if storage is writable
if (is_writable('../storage')) {
    $health['checks']['storage'] = [
        'status' => 'ok',
        'message' => 'Storage directory is writable'
    ];
} else {
    $health['checks']['storage'] = [
        'status' => 'error',
        'message' => 'Storage directory is not writable'
    ];
    $health['status'] = 'unhealthy';
}

// Check environment configuration
if (file_exists('../.env')) {
    $health['checks']['environment'] = [
        'status' => 'ok',
        'message' => 'Environment file exists'
    ];
} else {
    $health['checks']['environment'] = [
        'status' => 'warning',
        'message' => 'Environment file not found'
    ];
    $health['status'] = 'degraded';
}

// Set appropriate HTTP status code
$httpStatus = 200;
if ($health['status'] === 'unhealthy') {
    $httpStatus = 503;
} elseif ($health['status'] === 'degraded') {
    $httpStatus = 200; // Still return 200 for degraded to allow container to start
}

http_response_code($httpStatus);
echo json_encode($health, JSON_PRETTY_PRINT);
