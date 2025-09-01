// Location: labs/lab_06_production_deployment/nginx/static/app.js

class MicroservicesDashboard {
    constructor() {
        this.init();
        this.startHealthChecks();
        this.updateUptime();
        setInterval(() => this.updateUptime(), 60000); // Update every minute
    }

    init() {
        // Initialize the dashboard
// Location: labs/lab_06_production_deployment/nginx/static/app.js

class MicroservicesDashboard {
    constructor() {
        this.init();
        this.startHealthChecks();
        this.updateUptime();
        setInterval(() => this.updateUptime(), 60000); // Update every minute
    }

    init() {
        // Initialize the dashboard
        this.updateVersion();
        this.updateEnvironment();
        this.bindEventListeners();
    }

    bindEventListeners() {
        // Smooth scrolling for navigation links
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', (e) => {
                e.preventDefault();
                const target = document.querySelector(anchor.getAttribute('href'));
                if (target) {
                    target.scrollIntoView({ behavior: 'smooth' });
                }
            });
        });

        // Service card click handlers
        document.querySelectorAll('.service-link').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                this.checkServiceHealth(link.href, link);
            });
        });
    }

    async startHealthChecks() {
        const services = [
            { name: 'User Service', url: '/api/v1/users/health' },
            { name: 'Order Service', url: '/api/v1/orders/health' },
            { name: 'Notification Service', url: '/api/v1/notifications/health' }
        ];

        const overallHealthStatus = document.getElementById('health-status');
        let healthyServices = 0;

        for (const service of services) {
            try {
                const response = await fetch(service.url);
                if (response.ok) {
                    healthyServices++;
                }
            } catch (error) {
                console.warn(`Health check failed for ${service.name}:`, error);
            }
        }

        // Update overall health status
        if (healthyServices === services.length) {
            overallHealthStatus.textContent = 'All Systems Operational';
            overallHealthStatus.className = 'status-healthy';
        } else if (healthyServices > 0) {
            overallHealthStatus.textContent = `${healthyServices}/${services.length} Services Healthy`;
            overallHealthStatus.className = 'status-loading';
        } else {
            overallHealthStatus.textContent = 'System Issues Detected';
            overallHealthStatus.className = 'status-unhealthy';
        }
    }

    async checkServiceHealth(url, linkElement) {
        const originalText = linkElement.textContent;
        linkElement.textContent = 'Checking...';
        linkElement.classList.add('loading');

        try {
            const response = await fetch(url);
            const data = await response.json();
            
            if (response.ok) {
                this.showHealthModal('Service Healthy', data, 'success');
            } else {
                this.showHealthModal('Service Unhealthy', data, 'error');
            }
        } catch (error) {
            this.showHealthModal('Connection Failed', { error: error.message }, 'error');
        } finally {
            linkElement.textContent = originalText;
            linkElement.classList.remove('loading');
        }
    }

    showHealthModal(title, data, type) {
        // Create modal if it doesn't exist
        let modal = document.getElementById('health-modal');
        if (!modal) {
            modal = this.createHealthModal();
        }

        const modalTitle = modal.querySelector('.modal-title');
        const modalBody = modal.querySelector('.modal-body');
        const modalHeader = modal.querySelector('.modal-header');

        modalTitle.textContent = title;
        modalBody.innerHTML = `<pre>${JSON.stringify(data, null, 2)}</pre>`;
        
        // Update modal styling based on type
        modalHeader.className = `modal-header ${type}`;
        
        modal.style.display = 'block';
    }

    createHealthModal() {
        const modalHTML = `
            <div id="health-modal" class="modal">
                <div class="modal-content">
                    <div class="modal-header">
                        <h3 class="modal-title">Health Check Result</h3>
                        <span class="modal-close">&times;</span>
                    </div>
                    <div class="modal-body">
                        <p>Loading...</p>
                    </div>
                </div>
            </div>
        `;
        
        document.body.insertAdjacentHTML('beforeend', modalHTML);
        const modal = document.getElementById('health-modal');
        
        // Add close functionality
        const closeBtn = modal.querySelector('.modal-close');
        closeBtn.addEventListener('click', () => {
            modal.style.display = 'none';
        });
        
        window.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.style.display = 'none';
            }
        });
        
        return modal;
    }

    updateVersion() {
        const versionElement = document.getElementById('version');
        // Try to get version from environment or default
        const version = window.APP_VERSION || '1.0.0';
        versionElement.textContent = version;
    }

    updateEnvironment() {
        const envElement = document.getElementById('environment');
        const environment = window.APP_ENVIRONMENT || 'Production';
        envElement.textContent = environment;
        
        // Add environment-specific styling
        if (environment.toLowerCase() === 'development') {
            envElement.style.color = 'var(--warning-color)';
        } else if (environment.toLowerCase() === 'staging') {
            envElement.style.color = 'var(--secondary-color)';
        } else {
            envElement.style.color = 'var(--success-color)';
        }
    }

    updateUptime() {
        const uptimeElement = document.getElementById('uptime');
        const startTime = window.APP_START_TIME || Date.now();
        const uptime = Date.now() - startTime;
        
        const days = Math.floor(uptime / (1000 * 60 * 60 * 24));
        const hours = Math.floor((uptime % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((uptime % (1000 * 60 * 60)) / (1000 * 60));
        
        let uptimeString = '';
        if (days > 0) uptimeString += `${days}d `;
        if (hours > 0) uptimeString += `${hours}h `;
        uptimeString += `${minutes}m`;
        
        uptimeElement.textContent = uptimeString;
    }

    // Utility method to show notifications
    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        // Animate in
        setTimeout(() => notification.classList.add('show'), 100);
        
        // Remove after 5 seconds
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => notification.remove(), 300);
        }, 5000);
    }
}

// Add CSS for modal and notifications
const additionalStyles = `
    .modal {
        display: none;
        position: fixed;
        z-index: 1000;
        left: 0;
        top: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(0, 0, 0, 0.5);
    }
    
    .modal-content {
        background-color: var(--surface);
        margin: 5% auto;
        padding: 0;
        border-radius: 0.5rem;
        width: 90%;
        max-width: 600px;
        box-shadow: var(--shadow-lg);
    }
    
    .modal-header {
        padding: 1rem 1.5rem;
        border-bottom: 1px solid var(--border);
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    
    .modal-header.success {
        background-color: var(--success-color);
        color: white;
    }
    
    .modal-header.error {
        background-color: var(--error-color);
        color: white;
    }
    
    .modal-title {
        margin: 0;
        font-size: 1.25rem;
    }
    
    .modal-close {
        font-size: 2rem;
        cursor: pointer;
        opacity: 0.7;
    }
    
    .modal-close:hover {
        opacity: 1;
    }
    
    .modal-body {
        padding: 1.5rem;
        max-height: 400px;
        overflow-y: auto;
    }
    
    .modal-body pre {
        background: var(--background);
        padding: 1rem;
        border-radius: 0.25rem;
        font-size: 0.875rem;
        overflow-x: auto;
    }
    
    .notification {
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 1rem 1.5rem;
        border-radius: 0.5rem;
        color: white;
        font-weight: 500;
        z-index: 1001;
        transform: translateX(100%);
        transition: transform 0.3s ease;
    }
    
    .notification.show {
        transform: translateX(0);
    }
    
    .notification.success {
        background-color: var(--success-color);
    }
    
    .notification.error {
        background-color: var(--error-color);
    }
    
    .notification.info {
        background-color: var(--primary-color);
    }
`;

// Add the additional styles to the page
const styleSheet = document.createElement('style');
styleSheet.textContent = additionalStyles;
document.head.appendChild(styleSheet);

// Initialize dashboard when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.dashboard = new MicroservicesDashboard();
});

// Set app start time for uptime calculation
window.APP_START_TIME = Date.now();

// Expose some global functions for debugging
window.checkAllServices = async () => {
    const services = [
        '/api/v1/users/health',
        '/api/v1/orders/health',
        '/api/v1/notifications/health'
    ];
    
    const results = {};
    for (const service of services) {
        try {
            const response = await fetch(service);
            results[service] = {
                status: response.status,
                ok: response.ok,
                data: await response.json()
            };
        } catch (error) {
            results[service] = { error: error.message };
        }
    }
    
    console.table(results);
    return results;
};