const tablet = document.getElementById('tablet');
const views = ['overview', 'invoices', 'employees'];
let state = null;
let toastTimer;

const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mk_mekaniker';
async function nui(name, data = {}) {
    try {
        const response = await fetch(`https://${resource}/${name}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
        });
        return await response.json();
    } catch {
        return { ok: false, message: 'Forbindelsen til spillet fejlede.' };
    }
}
function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
}
function money(value) {
    return `${new Intl.NumberFormat('da-DK').format(Number(value) || 0)} kr.`;
}
function notify(message, type = 'inform') {
    const toast = document.getElementById('toast');
    toast.textContent = message || 'Udført.';
    toast.className = `toast ${type}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.add('hidden'), 2600);
}
function showView(view) {
    const allowed = state?.isBoss ? views : views.filter(item => item !== 'employees');
    if (!allowed.includes(view)) view = 'overview';
    document.querySelectorAll('.view').forEach(element => element.classList.toggle('active', element.id === `view-${view}`));
    document.querySelectorAll('.nav-item').forEach(element => element.classList.toggle('active', element.dataset.view === view));
    document.getElementById('page-title').textContent = ({ overview: 'Overblik', invoices: 'Fakturaer', employees: 'Medarbejdere' })[view];
}
function renderInvoices(target) {
    const rows = state?.invoiceHistory || [];
    if (!rows.length) {
        target.innerHTML = '<div class="empty-state">Ingen fakturaer er registreret endnu.</div>';
        return;
    }
    target.innerHTML = rows.map(invoice => {
        const date = invoice.created_at ? new Date(invoice.created_at.replace(' ', 'T')).toLocaleDateString('da-DK') : '—';
        const party = state.isBoss ? `Kunde · ${escapeHtml(invoice.target_citizenid || 'ukendt')}` : `Sendt · ${date}`;
        return `<div class="invoice-row"><div class="invoice-person"><span class="mini-avatar">${escapeHtml((invoice.reason || 'F').slice(0, 1).toUpperCase())}</span><div><strong>${escapeHtml(invoice.reason || 'Reparation')}</strong><small>${party}</small></div></div><span class="invoice-reason">${state.isBoss ? `Oprettet ${date}` : `Faktura #${escapeHtml(invoice.id)}`}</span><strong class="invoice-amount">${money(invoice.amount)}</strong></div>`;
    }).join('');
}
function renderEmployees() {
    const employees = state?.employees || [];
    document.getElementById('stat-employees').textContent = employees.length;
    document.getElementById('employee-count-label').textContent = `${employees.length} medarbejder${employees.length === 1 ? '' : 'e'}`;
    const container = document.getElementById('employee-list');
    if (!employees.length) {
        container.innerHTML = '<div class="empty-state">Der er endnu ingen medarbejdere på holdet.</div>';
        return;
    }
    const gradeOptions = (selected) => (state.grades || []).map(grade => `<option value="${escapeHtml(grade.value)}" ${Number(grade.value) === Number(selected) ? 'selected' : ''}>${escapeHtml(grade.label)}</option>`).join('');
    container.innerHTML = employees.map(employee => `<div class="employee-row"><div class="avatar">${escapeHtml((employee.name || '?').trim().slice(0, 1).toUpperCase())}</div><div class="employee-main"><strong>${escapeHtml(employee.name)}</strong><small>${escapeHtml(employee.rank || `Rank ${employee.grade}`)} · ${escapeHtml(employee.citizenid)}</small></div><div class="employee-actions"><select aria-label="Vælg rank for ${escapeHtml(employee.name)}" data-grade-id="${escapeHtml(employee.citizenid)}">${gradeOptions(employee.grade)}</select><button class="small-button" data-fire="${escapeHtml(employee.citizenid)}">Fyr</button></div></div>`).join('');
}
function render(data) {
    state = data;
    document.querySelectorAll('.boss-only').forEach(element => element.classList.toggle('hidden', !data.isBoss));
    document.getElementById('employee-name').textContent = data.name || 'Mekaniker';
    document.getElementById('employee-rank').textContent = data.rank || 'Medarbejder';
    document.getElementById('avatar').textContent = (data.name || 'M').trim().slice(0, 1).toUpperCase();
    document.getElementById('welcome-name').textContent = 'Værkstedsstatus';
    document.getElementById('duty-dot').classList.toggle('online', !!data.onDuty);
    document.getElementById('duty-dot').title = data.onDuty ? 'På arbejde' : 'Ikke på arbejde';
    document.querySelector('.shift-tag').innerHTML = `<i></i> ${data.onDuty ? 'PÅ ARBEJDE' : 'IKKE PÅ VAGT'}`;
    document.getElementById('stat-invoices').textContent = data.stats?.invoices || 0;
    document.getElementById('stat-revenue').textContent = money(data.stats?.revenue);
    document.getElementById('today-label').textContent = new Date().toLocaleDateString('da-DK', { weekday: 'long', day: 'numeric', month: 'long' });
    renderInvoices(document.getElementById('overview-invoices'));
    renderInvoices(document.getElementById('invoice-history'));
    renderEmployees();
}
function closeModal() { document.getElementById('modal-backdrop').classList.add('hidden'); }
function openModal({ title, description, fields, submitLabel, onSubmit }) {
    document.getElementById('modal-title').textContent = title;
    document.getElementById('modal-description').textContent = description;
    const form = document.getElementById('modal-form');
    form.innerHTML = fields.map(field => `<div class="field"><label for="field-${escapeHtml(field.name)}">${escapeHtml(field.label)}</label>${field.type === 'select' ? `<select id="field-${escapeHtml(field.name)}" name="${escapeHtml(field.name)}" required>${field.options.map(option => `<option value="${escapeHtml(option.value)}">${escapeHtml(option.label)}</option>`).join('')}</select>` : `<input id="field-${escapeHtml(field.name)}" name="${escapeHtml(field.name)}" type="${escapeHtml(field.type || 'text')}" ${field.min != null ? `min="${field.min}"` : ''} ${field.max != null ? `max="${field.max}"` : ''} ${field.maxlength ? `maxlength="${field.maxlength}"` : ''} placeholder="${escapeHtml(field.placeholder || '')}" required>`}</div>`).join('') + `<div class="form-actions"><button type="button" class="secondary-button" id="cancel-modal">Annuller</button><button type="submit" class="primary-button">${escapeHtml(submitLabel)}</button></div>`;
    form.onsubmit = async event => {
        event.preventDefault();
        const values = Object.fromEntries(new FormData(form).entries());
        closeModal();
        const result = await onSubmit(values);
        notify(result.message || (result.ok ? 'Handling gennemført.' : 'Handlingen mislykkedes.'), result.ok ? 'success' : 'error');
        if (result.ok) await refresh();
    };
    document.getElementById('cancel-modal').addEventListener('click', closeModal);
    document.getElementById('modal-backdrop').classList.remove('hidden');
}
async function refresh() {
    const result = await nui('refresh');
    if (result.ok && result.data) render(result.data);
    else if (result.message) notify(result.message, 'error');
}
function createInvoice() {
    openModal({
        title: 'Ny faktura', description: 'Kunden skal stå tæt på dig og bekræfte betalingen.', submitLabel: 'Send faktura',
        fields: [
            { name: 'amount', label: 'Beløb (kr.)', type: 'number', min: 50, max: 50000, placeholder: 'F.eks. 1250' },
            { name: 'reason', label: 'Beskrivelse', type: 'text', maxlength: 200, placeholder: 'F.eks. Reparation af motor' },
        ],
        onSubmit: values => nui('invoice', { amount: Number(values.amount), reason: values.reason }),
    });
}
function hireEmployee() {
    openModal({
        title: 'Ansæt medarbejder', description: 'Vælg start-rang. Den nærmeste spiller bliver ansat.', submitLabel: 'Ansæt',
        fields: [{ name: 'grade', label: 'Start-rang', type: 'select', options: state.grades || [] }],
        onSubmit: values => nui('hire', { grade: values.grade }),
    });
}
window.addEventListener('message', event => {
    if (event.data.action === 'open') { render(event.data.data); tablet.classList.remove('hidden'); showView('overview'); }
    if (event.data.action === 'close') { tablet.classList.add('hidden'); closeModal(); }
});
document.querySelectorAll('.nav-item').forEach(button => button.addEventListener('click', () => showView(button.dataset.view)));
document.querySelectorAll('[data-goto]').forEach(button => button.addEventListener('click', () => showView(button.dataset.goto)));
document.getElementById('close-button').addEventListener('click', () => nui('close'));
document.getElementById('refresh-button').addEventListener('click', refresh);
document.getElementById('new-invoice-button').addEventListener('click', createInvoice);
document.getElementById('invoice-page-button').addEventListener('click', createInvoice);
document.getElementById('hire-button').addEventListener('click', hireEmployee);
document.getElementById('modal-close').addEventListener('click', closeModal);
document.getElementById('modal-backdrop').addEventListener('click', event => { if (event.target.id === 'modal-backdrop') closeModal(); });
document.getElementById('employee-list').addEventListener('change', async event => {
    if (!event.target.matches('[data-grade-id]')) return;
    const result = await nui('setGrade', { citizenid: event.target.dataset.gradeId, grade: event.target.value });
    notify(result.message, result.ok ? 'success' : 'error');
    if (result.ok) await refresh();
});
document.getElementById('employee-list').addEventListener('click', async event => {
    const button = event.target.closest('[data-fire]');
    if (!button || !confirm('Er du sikker på, at medarbejderen skal fyres?')) return;
    const result = await nui('fire', { citizenid: button.dataset.fire });
    notify(result.message, result.ok ? 'success' : 'error');
    if (result.ok) await refresh();
});
document.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
        if (!document.getElementById('modal-backdrop').classList.contains('hidden')) closeModal();
        else if (!document.getElementById('customizer').classList.contains('hidden')) nui('closeShop');
        else nui('close');
    }
});

const customizer = document.getElementById('customizer');
let shopState = null;
let shopToastTimer;
function shopNotify(message, type = 'inform') {
    const toast = document.getElementById('shop-toast');
    toast.textContent = message || 'Udført.';
    toast.className = `toast ${type}`;
    clearTimeout(shopToastTimer);
    shopToastTimer = setTimeout(() => toast.classList.add('hidden'), 2800);
}
function renderShop(data) {
    shopState = data;
    document.getElementById('customizer-vehicle').textContent = data.hasVehicle ? `${data.vehicle || 'Dit køretøj'} · Vælg dele, og køb for at montere.` : 'Butikken er åben. Sæt dig i førersædet ved værkstedet for at tilpasse en bil.';
    document.getElementById('tune-categories').innerHTML = (data.catalog || []).map(category => `
        <article class="tune-card" data-tune-card="${escapeHtml(category.key)}">
            <div class="tune-card-heading"><h3>${escapeHtml(category.label)}</h3><span>${money(category.price)}</span></div>
            <select aria-label="Vælg ${escapeHtml(category.label)}" data-tune-value="${escapeHtml(category.key)}">
                ${(category.options || []).map(option => `<option value="${Number(option.value)}" ${Number(option.value) === Number(category.current) ? 'selected' : ''}>${escapeHtml(option.label)}</option>`).join('')}
            </select>
            <button class="primary-button tune-buy" data-buy-tune="${escapeHtml(category.key)}">Køb / montér</button>
        </article>`).join('') || `<div class="empty-state">${data.hasVehicle ? 'Ingen opgraderinger passer til denne bil.' : 'Sæt dig i bilen og åbn tuning igen for at se opgraderinger.'}</div>`;
    document.getElementById('product-list').innerHTML = (data.products || []).map(product => `
        <article class="product-card"><div class="product-icon">＋</div><div class="product-copy"><h3>${escapeHtml(product.label)}</h3><p>${escapeHtml(product.description || '')}</p><strong>${money(product.price)}</strong></div><button class="primary-button" data-buy-product="${escapeHtml(product.key)}">Køb</button></article>`).join('') || '<div class="empty-state">Butikken har ingen varer.</div>';
}
document.querySelectorAll('.customizer-tab').forEach(button => button.addEventListener('click', () => {
    const tab = button.dataset.shopTab;
    document.querySelectorAll('.customizer-tab').forEach(item => item.classList.toggle('active', item === button));
    document.querySelectorAll('.shop-panel').forEach(panel => panel.classList.toggle('active', panel.id === `shop-${tab}`));
}));
document.getElementById('shop-close').addEventListener('click', () => nui('closeShop'));
document.getElementById('tune-categories').addEventListener('click', async event => {
    const button = event.target.closest('[data-buy-tune]');
    if (!button) return;
    const category = button.dataset.buyTune;
    const value = Number(document.querySelector(`[data-tune-value="${CSS.escape(category)}"]`).value);
    button.disabled = true;
    const result = await nui('buyTune', { category, value });
    button.disabled = false;
    shopNotify(result.message, result.ok ? 'success' : 'error');
});
document.getElementById('product-list').addEventListener('click', async event => {
    const button = event.target.closest('[data-buy-product]');
    if (!button) return;
    button.disabled = true;
    const result = await nui('buyProduct', { key: button.dataset.buyProduct });
    button.disabled = false;
    shopNotify(result.message, result.ok ? 'success' : 'error');
});
window.addEventListener('message', event => {
    if (event.data.action === 'shopOpen') {
        renderShop(event.data.data || {});
        customizer.classList.remove('hidden');
        document.querySelectorAll('.customizer-tab').forEach(item => item.classList.toggle('active', item.dataset.shopTab === 'tuning'));
        document.querySelectorAll('.shop-panel').forEach(item => item.classList.toggle('active', item.id === 'shop-tuning'));
    }
    if (event.data.action === 'shopClose') customizer.classList.add('hidden');
    if (event.data.action === 'tunePurchased') {
        const select = document.querySelector(`[data-tune-value="${CSS.escape(event.data.category)}"]`);
        if (select) select.value = String(event.data.value);
    }
});
