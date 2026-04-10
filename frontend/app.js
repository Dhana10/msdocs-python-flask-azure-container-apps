const apiBase = () => {
  const base = (window.APP && window.APP.apiBase) || '';
  return base.replace(/\/$/, '');
};

async function api(path, options = {}) {
  const url = `${apiBase()}${path}`;
  const headers = { ...(options.headers || {}) };
  if (options.body && !(options.body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
  }
  const res = await fetch(url, { ...options, headers });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (!res.ok) {
    const err = new Error((data && data.error) || res.statusText || 'Request failed');
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

function el(id) {
  return document.getElementById(id);
}

function showError(msg) {
  const n = el('list-error');
  n.textContent = msg || '';
  n.classList.toggle('hidden', !msg);
}

async function loadRestaurants() {
  showError('');
  try {
    const rows = await api('/api/restaurants');
    const root = el('restaurant-list');
    root.innerHTML = '';
    if (!rows.length) {
      root.innerHTML = '<p class="muted">No restaurants yet.</p>';
      return;
    }
    rows.forEach((r) => {
      const div = document.createElement('div');
      div.className = 'list-item';
      div.innerHTML = `
        <div>
          <strong>${escapeHtml(r.name)}</strong>
          <div class="muted small">${escapeHtml(r.description || '')}</div>
        </div>
        <button type="button" class="btn secondary" data-id="${r.id}">Open</button>
      `;
      div.querySelector('button').addEventListener('click', () => openDetail(r.id));
      root.appendChild(div);
    });
  } catch (e) {
    showError(e.message || 'Failed to load restaurants. Check API URL (config.js) and CORS.');
  }
}

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

async function openDetail(id) {
  el('detail-section').classList.remove('hidden');
  el('review-restaurant-id').value = id;
  el('form-review-msg').textContent = '';
  try {
    const data = await api(`/api/restaurants/${id}`);
    el('detail-title').textContent = data.name;
    el('detail-meta').textContent = [data.street_address, data.description].filter(Boolean).join(' · ');
    const revRoot = el('review-list');
    revRoot.innerHTML = '';
    (data.reviews || []).forEach((rv) => {
      const p = document.createElement('div');
      p.className = 'list-item';
      p.innerHTML = `<span>${escapeHtml(rv.user_name)}</span><span class="muted">${rv.rating}/5</span><span>${escapeHtml(rv.review_text || '')}</span>`;
      revRoot.appendChild(p);
    });
    if (!(data.reviews || []).length) {
      revRoot.innerHTML = '<p class="muted">No reviews yet.</p>';
    }
  } catch (e) {
    el('detail-title').textContent = 'Error';
    el('detail-meta').textContent = e.message || 'Failed to load';
  }
}

el('btn-refresh').addEventListener('click', loadRestaurants);
el('btn-close-detail').addEventListener('click', () => {
  el('detail-section').classList.add('hidden');
});

el('form-restaurant').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const form = ev.target;
  const msg = el('form-restaurant-msg');
  msg.textContent = '';
  const body = {
    name: form.name.value.trim(),
    street_address: form.street_address.value.trim(),
    description: form.description.value.trim(),
  };
  try {
    await api('/api/restaurants', { method: 'POST', body: JSON.stringify(body) });
    form.reset();
    msg.textContent = 'Created.';
    await loadRestaurants();
  } catch (e) {
    msg.textContent = e.message || 'Failed';
  }
});

el('form-review').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const form = ev.target;
  const msg = el('form-review-msg');
  msg.textContent = '';
  const rid = form.restaurant_id.value;
  const body = {
    user_name: form.user_name.value.trim(),
    rating: parseInt(form.rating.value, 10),
    review_text: form.review_text.value.trim(),
  };
  try {
    await api(`/api/restaurants/${rid}/reviews`, { method: 'POST', body: JSON.stringify(body) });
    form.reset();
    form.restaurant_id.value = rid;
    msg.textContent = 'Review added.';
    await openDetail(rid);
    await loadRestaurants();
  } catch (e) {
    msg.textContent = e.message || 'Failed';
  }
});

loadRestaurants();
