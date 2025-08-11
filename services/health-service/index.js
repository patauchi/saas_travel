const express = require('express');
const axios = require('axios');
const cors = require('cors');
const helmet = require('helmet');
const { Client } = require('pg');
const redis = require('redis');
const amqp = require('amqplib');
const winston = require('winston');
const rateLimit = require('express-rate-limit');

// Initialize Express app
const app = express();
const port = process.env.PORT || 3000;

// Configure Winston logger
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console({
            format: winston.format.simple()
        }),
        new winston.transports.File({
            filename: '/var/log/health-service.log',
            level: 'error'
        })
    ]
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minute
    max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/health', limiter);

// Service configurations
const services = {
    'postgres-landlord': {
        name: 'PostgreSQL Landlord',
        type: 'database',
        check: async () => {
            const client = new Client({
                host: 'postgres-landlord',
                port: 5432,
                user: process.env.DB_USERNAME || 'vtravel',
                password: process.env.DB_PASSWORD || 'vtravel123',
                database: 'vtravel_landlord',
                connectionTimeoutMillis: 5000
            });
            try {
                await client.connect();
                await client.query('SELECT 1');
                await client.end();
                return { status: 'healthy', message: 'Connected successfully' };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'postgres-tenant': {
        name: 'PostgreSQL Tenant',
        type: 'database',
        check: async () => {
            const client = new Client({
                host: 'postgres-tenant',
                port: 5432,
                user: process.env.DB_USERNAME || 'vtravel',
                password: process.env.DB_PASSWORD || 'vtravel123',
                database: 'tenant_template',
                connectionTimeoutMillis: 5000
            });
            try {
                await client.connect();
                await client.query('SELECT 1');
                await client.end();
                return { status: 'healthy', message: 'Connected successfully' };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'redis': {
        name: 'Redis Cache',
        type: 'cache',
        check: async () => {
            const client = redis.createClient({
                url: 'redis://redis:6379',
                socket: {
                    connectTimeout: 5000
                }
            });
            try {
                await client.connect();
                await client.ping();
                await client.quit();
                return { status: 'healthy', message: 'Connected successfully' };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'rabbitmq': {
        name: 'RabbitMQ',
        type: 'queue',
        check: async () => {
            try {
                const connection = await amqp.connect({
                    hostname: 'rabbitmq',
                    port: 5672,
                    username: 'admin',
                    password: 'admin123',
                    heartbeat: 10,
                    connectionTimeout: 5000
                });
                await connection.close();
                return { status: 'healthy', message: 'Connected successfully' };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'auth-service': {
        name: 'Auth Service',
        type: 'microservice',
        check: async () => {
            try {
                const response = await axios.get('http://auth-service:9000/health', {
                    timeout: 5000
                });
                return {
                    status: response.status === 200 ? 'healthy' : 'unhealthy',
                    message: `Response status: ${response.status}`
                };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'tenant-service': {
        name: 'Tenant Service',
        type: 'microservice',
        check: async () => {
            try {
                const response = await axios.get('http://tenant-service:9000/health', {
                    timeout: 5000
                });
                return {
                    status: response.status === 200 ? 'healthy' : 'unhealthy',
                    message: `Response status: ${response.status}`
                };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'crm-service': {
        name: 'CRM Service',
        type: 'microservice',
        check: async () => {
            try {
                const response = await axios.get('http://crm-service:9000/health', {
                    timeout: 5000
                });
                return {
                    status: response.status === 200 ? 'healthy' : 'unhealthy',
                    message: `Response status: ${response.status}`
                };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'sales-service': {
        name: 'Sales Service',
        type: 'microservice',
        check: async () => {
            try {
                const response = await axios.get('http://sales-service:9000/health', {
                    timeout: 5000
                });
                return {
                    status: response.status === 200 ? 'healthy' : 'unhealthy',
                    message: `Response status: ${response.status}`
                };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'financial-service': {
        name: 'Financial Service',
        type: 'microservice',
        check: async () => {
            try {
                const response = await axios.get('http://financial-service:9000/health', {
                    timeout: 5000
                });
                return {
                    status: response.status === 200 ? 'healthy' : 'unhealthy',
                    message: `Response status: ${response.status}`
                };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'operations-service': {
        name: 'Operations Service',
        type: 'microservice',
        check: async () => {
            try {
                const response = await axios.get('http://operations-service:9000/health', {
                    timeout: 5000
                });
                return {
                    status: response.status === 200 ? 'healthy' : 'unhealthy',
                    message: `Response status: ${response.status}`
                };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'communication-service': {
        name: 'Communication Service',
        type: 'microservice',
        check: async () => {
            try {
                const response = await axios.get('http://communication-service:9000/health', {
                    timeout: 5000
                });
                return {
                    status: response.status === 200 ? 'healthy' : 'unhealthy',
                    message: `Response status: ${response.status}`
                };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    },
    'minio': {
        name: 'MinIO Storage',
        type: 'storage',
        check: async () => {
            try {
                const response = await axios.get('http://minio:9000/minio/health/live', {
                    timeout: 5000
                });
                return {
                    status: response.status === 200 ? 'healthy' : 'unhealthy',
                    message: 'MinIO is operational'
                };
            } catch (error) {
                return { status: 'unhealthy', message: error.message };
            }
        }
    }
};

// Perform health checks for specified services
async function performHealthChecks(serviceList = null) {
    const servicesToCheck = serviceList || Object.keys(services);
    const results = {};
    const promises = [];

    for (const serviceId of servicesToCheck) {
        if (services[serviceId]) {
            promises.push(
                services[serviceId].check()
                    .then(result => {
                        results[serviceId] = {
                            ...result,
                            name: services[serviceId].name,
                            type: services[serviceId].type,
                            timestamp: new Date().toISOString()
                        };
                    })
                    .catch(error => {
                        results[serviceId] = {
                            status: 'error',
                            name: services[serviceId].name,
                            type: services[serviceId].type,
                            message: error.message,
                            timestamp: new Date().toISOString()
                        };
                    })
            );
        }
    }

    await Promise.all(promises);
    return results;
}

// Routes
app.get('/health', async (req, res) => {
    try {
        const critical = ['postgres-landlord', 'postgres-tenant', 'redis'];
        const results = await performHealthChecks(critical);

        const allHealthy = Object.values(results).every(r => r.status === 'healthy');
        const statusCode = allHealthy ? 200 : 503;

        res.status(statusCode).json({
            status: allHealthy ? 'healthy' : 'unhealthy',
            timestamp: new Date().toISOString(),
            services: results,
            summary: {
                total: Object.keys(results).length,
                healthy: Object.values(results).filter(r => r.status === 'healthy').length,
                unhealthy: Object.values(results).filter(r => r.status === 'unhealthy').length
            }
        });
    } catch (error) {
        logger.error('Health check error:', error);
        res.status(500).json({
            status: 'error',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

app.get('/health/services', async (req, res) => {
    try {
        const results = await performHealthChecks();

        const allHealthy = Object.values(results).every(r => r.status === 'healthy');
        const statusCode = allHealthy ? 200 : 503;

        res.status(statusCode).json({
            status: allHealthy ? 'healthy' : 'degraded',
            timestamp: new Date().toISOString(),
            environment: process.env.NODE_ENV || 'development',
            services: results,
            summary: {
                total: Object.keys(results).length,
                healthy: Object.values(results).filter(r => r.status === 'healthy').length,
                unhealthy: Object.values(results).filter(r => r.status === 'unhealthy').length,
                error: Object.values(results).filter(r => r.status === 'error').length
            },
            categories: {
                databases: Object.entries(results)
                    .filter(([_, v]) => v.type === 'database')
                    .reduce((acc, [k, v]) => ({ ...acc, [k]: v }), {}),
                microservices: Object.entries(results)
                    .filter(([_, v]) => v.type === 'microservice')
                    .reduce((acc, [k, v]) => ({ ...acc, [k]: v }), {}),
                infrastructure: Object.entries(results)
                    .filter(([_, v]) => ['cache', 'queue', 'storage'].includes(v.type))
                    .reduce((acc, [k, v]) => ({ ...acc, [k]: v }), {})
            }
        });
    } catch (error) {
        logger.error('Service health check error:', error);
        res.status(500).json({
            status: 'error',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

app.get('/health/:service', async (req, res) => {
    const serviceId = req.params.service;

    if (!services[serviceId]) {
        return res.status(404).json({
            status: 'error',
            message: `Service '${serviceId}' not found`,
            timestamp: new Date().toISOString()
        });
    }

    try {
        const result = await services[serviceId].check();
        const statusCode = result.status === 'healthy' ? 200 : 503;

        res.status(statusCode).json({
            service: serviceId,
            name: services[serviceId].name,
            type: services[serviceId].type,
            ...result,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        logger.error(`Health check error for ${serviceId}:`, error);
        res.status(500).json({
            service: serviceId,
            status: 'error',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
    try {
        const results = await performHealthChecks();
        let metrics = '# HELP service_health Service health status (1 = healthy, 0 = unhealthy)\n';
        metrics += '# TYPE service_health gauge\n';

        for (const [serviceId, result] of Object.entries(results)) {
            const value = result.status === 'healthy' ? 1 : 0;
            metrics += `service_health{service="${serviceId}",name="${result.name}",type="${result.type}"} ${value}\n`;
        }

        res.set('Content-Type', 'text/plain');
        res.send(metrics);
    } catch (error) {
        logger.error('Metrics generation error:', error);
        res.status(500).send('Error generating metrics');
    }
});

// Liveness probe
app.get('/live', (req, res) => {
    res.status(200).json({
        status: 'alive',
        timestamp: new Date().toISOString()
    });
});

// Readiness probe
app.get('/ready', async (req, res) => {
    try {
        // Check only critical dependencies
        const critical = ['redis'];
        const results = await performHealthChecks(critical);
        const allHealthy = Object.values(results).every(r => r.status === 'healthy');

        if (allHealthy) {
            res.status(200).json({
                status: 'ready',
                timestamp: new Date().toISOString()
            });
        } else {
            res.status(503).json({
                status: 'not ready',
                timestamp: new Date().toISOString(),
                failed: Object.entries(results)
                    .filter(([_, v]) => v.status !== 'healthy')
                    .map(([k, _]) => k)
            });
        }
    } catch (error) {
        res.status(503).json({
            status: 'not ready',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Start server
app.listen(port, '0.0.0.0', () => {
    logger.info(`Health Service running on port ${port}`);
    logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
    logger.info(`Monitoring ${Object.keys(services).length} services`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    logger.info('SIGTERM signal received: closing HTTP server');
    process.exit(0);
});

process.on('SIGINT', () => {
    logger.info('SIGINT signal received: closing HTTP server');
    process.exit(0);
});
