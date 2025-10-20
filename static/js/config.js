document.getElementById('configForm').addEventListener('submit', async function(e) {
    e.preventDefault();
    
    const optionalPackages = Array.from(document.querySelectorAll('.optional-checkbox:checked'))
        .map(checkbox => checkbox.value);
    
    const formData = {
        username: document.getElementById('username').value,
        hostname: document.getElementById('hostname').value,
        timezone: document.getElementById('timezone').value,
        keymap: document.getElementById('keymap').value,
        desktop_environment: document.getElementById('desktop_environment').value,
        aur_helper: document.getElementById('aur_helper').value,
        install_type: document.getElementById('install_type').value,
        optional_packages: optionalPackages
    };
    
    try {
        const response = await fetch('/generate-config', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(formData)
        });
        
        const data = await response.json();
        
        document.getElementById('configOutput').value = data.config;
        document.getElementById('outputSection').style.display = 'block';
        
        document.getElementById('outputSection').scrollIntoView({ behavior: 'smooth' });
    } catch (error) {
        alert('Error generating configuration: ' + error.message);
    }
});

document.getElementById('copyBtn').addEventListener('click', function() {
    const output = document.getElementById('configOutput');
    output.select();
    document.execCommand('copy');
    
    this.textContent = 'Copied!';
    setTimeout(() => {
        this.textContent = 'Copy to Clipboard';
    }, 2000);
});

document.getElementById('downloadBtn').addEventListener('click', function() {
    const content = document.getElementById('configOutput').value;
    const blob = new Blob([content], { type: 'text/plain' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'setup.conf';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
});
