# Use Node.js 18 LTS as base image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
# Use npm install if package-lock.json doesn't exist, otherwise use npm ci
RUN if [ -f package-lock.json ]; then \
        npm ci --only=production; \
    else \
        npm install --only=production; \
    fi && \
    npm cache clean --force

# Copy application code
COPY . .

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Start the application
# Uses npm start from package.json, or override with CMD in docker run
CMD ["npm", "start"]

