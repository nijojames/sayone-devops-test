const express = require('express');

const app = express();

// Read from environment (works in local + prod)
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Basic health / root endpoint
app.get('/', (req, res) => {
    res.json({
        status: 'OK',
        message: 'DevOps Machine Test App',
        environment: NODE_ENV
    });
});

// Optional health check endpoint (useful for Docker/K8s)
app.get('/health', (req, res) => {
    res.status(200).send('healthy');
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT} in ${NODE_ENV} mode`);
});
