// Same-origin proxy for the Base44 backend.
//
// Why this exists: the app was calling https://superagent-f43a5097.base44.app
// directly from the browser. On some mobile networks / carriers that
// cross-origin domain gets blocked or silently dropped by content filters
// even though the main site (kgcarwash.vercel.app) loads fine -- so the
// splash screen would render but every data request would hang or fail.
//
// Fix: the browser now only ever talks to this same origin (kgcarwash.vercel.app
// -> /api/proxy). This function runs on Vercel's servers and forwards the
// request to Base44 server-side, where the phone's local network is no
// longer part of the path at all. No data is moved, removed, or changed --
// Base44 remains the one and only backend; this just relays the same calls
// through a route the phone can actually reach.

const BASE44_API_URL = 'https://superagent-f43a5097.base44.app/functions/apiHandler';
const APP_ID = '6a1c42f697e43e4ff43a5097';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-base44-app-id');
  res.setHeader('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 25000);
    const upstream = await fetch(BASE44_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-base44-app-id': APP_ID,
      },
      body: JSON.stringify(req.body || {}),
      signal: controller.signal,
    }).finally(() => clearTimeout(timeoutId));

    const text = await upstream.text();
    res.status(upstream.status).setHeader('Content-Type', 'application/json').send(text);
  } catch (e) {
    res.status(502).json({ error: 'Proxy error reaching backend: ' + (e && e.message ? e.message : String(e)) });
  }
}
