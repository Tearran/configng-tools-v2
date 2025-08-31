(function () {
        const container = document.getElementById('nav-container');
        if (!container) return;
    
        fetch('/json/nav.json',
        { cache: 'no-cache'
        })
            .then(res => {
                if (!res.ok) throw new Error('HTTP ' + res.status);
                return res.json();
        })
            .then(navItems => {
                if (!Array.isArray(navItems) || navItems.length === 0) {
                    container.innerHTML = '<p>No navigation items found.</p>';
                    return;
                }
    
                const ul = document.createElement('ul');
                ul.className = 'nav-list';
    
                navItems.forEach(item => {
                    const li = document.createElement('li');
                    const a = document.createElement('a');
                    a.className = 'nav-link';
                    a.href = item.href || '#';
                    a.textContent = item.label || '';
                    li.appendChild(a);
                    ul.appendChild(li);
                });
    
                container.innerHTML = '';
                container.appendChild(ul);
        })
            .catch(err => {
                console.error('Nav load error', err);
                container.innerHTML = '<p>Error loading navigation.</p>';
        });
})();
    