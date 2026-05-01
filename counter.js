// ── Visitor Counter ──────────────────────────────────────────────────────────
// Calls the Azure Function API to get and increment the visitor count.
// The function handles the CosmosDB read/write — we never touch the DB directly.
//
// ⚠️  Update COUNTER_API_URL after deploying the Azure Function (Step 9).
//     Run: terraform output function_url
// ─────────────────────────────────────────────────────────────────────────────
const COUNTER_API_URL = 'https://func-stvincentcv.azurewebsites.net/api/visitor-counter';

async function loadVisitorCount() {
  try {
    const res = await fetch(COUNTER_API_URL);
    if (!res.ok) throw new Error(`API returned ${res.status}`);

    const data = await res.json();

    // Update every element with class "visitor-count" on the page
    document.querySelectorAll('.visitor-count').forEach(el => {
      el.textContent = data.count.toLocaleString();
    });
  } catch (err) {
    // Fail silently — a broken counter should never break the CV page
    console.warn('Visitor counter unavailable:', err.message);
  }
}

loadVisitorCount();
