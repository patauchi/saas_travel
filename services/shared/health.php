<?php
// Simple health check endpoint for PHP services
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle OPTIONS request for CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

// Get service name from environment variable or use default
$serviceName = getenv('SERVICE_NAME') ?: 'unknown-service';
$servicePort = getenv('PORT') ?: '9000';

// Basic health check response
$response = [
    'status' => 'healthy',
    'service' => $serviceName,
    'timestamp' => date('c'),
    'uptime' => time() - $_SERVER['REQUEST_TIME'],
    'environment' => [
        'php_version' => PHP_VERSION,
        'os' => PHP_OS,
        'server' => $_SERVER['SERVER_SOFTWARE'] ?? 'PHP Built-in Server'
    ],
    'checks' => []
];

// Check database connection if configured
$dbHost = getenv('DB_HOST');
if ($dbHost) {
    try {
        $dbConnection = @pg_connect(
            "host=" . $dbHost .
            " port=" . (getenv('DB_PORT') ?: '5432') .
            " dbname=" . (getenv('DB_DATABASE') ?: 'postgres') .
            " user=" . (getenv('DB_USERNAME') ?: 'postgres') .
            " password=" . (getenv('DB_PASSWORD') ?: '')
        );

        if ($dbConnection) {
            $response['checks']['database'] = [
                'status' => 'connected',
                'host' => $dbHost
            ];
            pg_close($dbConnection);
        } else {
            $response['checks']['database'] = [
                'status' => 'disconnected',
                'host' => $dbHost,
                'error' => 'Could not connect'
            ];
        }
    } catch (Exception $e) {
        $response['checks']['database'] = [
            'status' => 'error',
            'host' => $dbHost,
            'error' => $e->getMessage()
        ];
    }
}

// Check Redis connection if configured
$redisHost = getenv('REDIS_HOST');
if ($redisHost && class_exists('Redis')) {
    try {
        $redis = new Redis();
        $connected = @$redis->connect($redisHost, getenv('REDIS_PORT') ?: 6379, 1);

        if ($connected) {
            $response['checks']['redis'] = [
                'status' => 'connected',
                'host' => $redisHost
            ];
            $redis->close();
        } else {
            $response['checks']['redis'] = [
                'status' => 'disconnected',
                'host' => $redisHost
            ];
        }
    } catch (Exception $e) {
        $response['checks']['redis'] = [
            'status' => 'error',
            'host' => $redisHost,
            'error' => $e->getMessage()
        ];
    }
}

// Set appropriate HTTP status code
http_response_code(200);

// Output JSON response
echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
?>
