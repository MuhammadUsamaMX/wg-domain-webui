// API base URL
const API_BASE = '';

// DOM elements
const domainInput = document.getElementById('domainInput');
const addBtn = document.getElementById('addBtn');
const updateBtn = document.getElementById('updateBtn');
const domainsList = document.getElementById('domainsList');
const status = document.getElementById('status');

// Show status message
function showStatus(message, type = 'info') {
    status.textContent = message;
    status.className = `status ${type}`;
    setTimeout(() => {
        status.style.display = 'none';
    }, 5000);
}

// Load domains list
async function loadDomains() {
    try {
        const response = await fetch(`${API_BASE}/api/domains`);
        const data = await response.json();
        
        if (response.ok) {
            displayDomains(data.domains);
        } else {
            showStatus(`Error: ${data.error}`, 'error');
            domainsList.innerHTML = '<p class="empty">Failed to load domains</p>';
        }
    } catch (error) {
        showStatus(`Error loading domains: ${error.message}`, 'error');
        domainsList.innerHTML = '<p class="empty">Failed to load domains</p>';
    }
}

// Display domains in the list
function displayDomains(domains) {
    if (domains.length === 0) {
        domainsList.innerHTML = '<p class="empty">No domains configured</p>';
        return;
    }
    
    domainsList.innerHTML = domains.map(domain => `
        <div class="domain-item">
            <span class="domain-name">${escapeHtml(domain)}</span>
            <button class="btn btn-danger" onclick="removeDomain('${escapeHtml(domain)}')">Remove</button>
        </div>
    `).join('');
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Add domain
async function addDomain() {
    const domain = domainInput.value.trim();
    
    if (!domain) {
        showStatus('Please enter a domain', 'error');
        return;
    }
    
    // Basic validation
    if (!/^[a-zA-Z0-9.-]+$/.test(domain)) {
        showStatus('Invalid domain format', 'error');
        return;
    }
    
    addBtn.disabled = true;
    addBtn.textContent = 'Adding...';
    
    try {
        const response = await fetch(`${API_BASE}/api/add`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ domain: domain })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            if (data.success) {
                showStatus(data.message, 'success');
                domainInput.value = '';
                loadDomains();
            } else {
                showStatus(data.message, 'info');
            }
        } else {
            showStatus(`Error: ${data.error}`, 'error');
        }
    } catch (error) {
        showStatus(`Error: ${error.message}`, 'error');
    } finally {
        addBtn.disabled = false;
        addBtn.textContent = 'Add Domain';
    }
}

// Remove domain
async function removeDomain(domain) {
    if (!confirm(`Remove domain "${domain}"?`)) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/api/remove`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ domain: domain })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            if (data.success) {
                showStatus(data.message, 'success');
                loadDomains();
            } else {
                showStatus(data.message, 'info');
            }
        } else {
            showStatus(`Error: ${data.error}`, 'error');
        }
    } catch (error) {
        showStatus(`Error: ${error.message}`, 'error');
    }
}

// Update domains (trigger DNS resolution and nftables update)
async function updateDomains() {
    updateBtn.disabled = true;
    updateBtn.textContent = 'Updating...';
    
    try {
        const response = await fetch(`${API_BASE}/api/update`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (response.ok) {
            if (data.success) {
                const stats = data.stats;
                let message = `Update completed: ${stats.domains_resolved}/${stats.domains_processed} domains resolved`;
                if (stats.ipv4_count > 0 || stats.ipv6_count > 0) {
                    message += ` (${stats.ipv4_count} IPv4, ${stats.ipv6_count} IPv6 addresses)`;
                }
                if (stats.failed_domains.length > 0) {
                    message += `. Failed: ${stats.failed_domains.join(', ')}`;
                }
                showStatus(message, 'success');
            } else {
                showStatus(`Error: ${data.error}`, 'error');
            }
        } else {
            showStatus(`Error: ${data.error}`, 'error');
        }
    } catch (error) {
        showStatus(`Error: ${error.message}`, 'error');
    } finally {
        updateBtn.disabled = false;
        updateBtn.textContent = 'Update Now';
    }
}

// Event listeners
addBtn.addEventListener('click', addDomain);
updateBtn.addEventListener('click', updateDomains);

domainInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        addDomain();
    }
});

// Auto-refresh domains list every 10 seconds
setInterval(loadDomains, 10000);

// Initial load
loadDomains();


