# syntax=docker/dockerfile:1.6

# --------------------
# Stage 1: Base deps
# --------------------
FROM node:24.13.0-alpine3.23 AS base

WORKDIR /app

# Copy dependency files first for caching
COPY package*.json ./

# Install exact dependencies (deterministic)
RUN npm ci --no-audit --no-fund


# Stage 2: Development
# --------------------
FROM base AS development

# Copy full source for local/dev
COPY . .

# Expose app port
EXPOSE 3000

# Run app in dev/local mode
CMD ["npm", "start"]


# --------------------
# Stage 3: Production (optional, later)
# --------------------
FROM node:24.13.0-alpine3.23 AS production

# Create non-root user (prod best practice)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only required files
COPY --from=base /app/node_modules ./node_modules
COPY index.js package.json ./

USER appuser

EXPOSE 3000

CMD ["node", "index.js"]
