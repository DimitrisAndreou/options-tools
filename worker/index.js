// In-memory cache for cookie and crumb
let cachedCookie = null;
let cachedCrumb = null;
let lastCacheTime = 0;
const CACHE_TTL = 4 * 60 * 60 * 1000; // 4 hours in milliseconds

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const targetUrl = url.searchParams.get('target');

    // 1. Handle CORS Preflight (Crucial for custom headers like x-proxy-cookie)
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, x-proxy-cookie, User-Agent, user-agent, Accept, accept',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    if (!targetUrl) return new Response('Target missing', { status: 400 });

    const isFcYahoo = targetUrl.startsWith('https://fc.yahoo.com');
    const isGetCrumb = targetUrl.includes('getcrumb');
    const now = Date.now();
    const isCacheValid = cachedCookie && cachedCrumb && (now - lastCacheTime < CACHE_TTL);

    // Serve from cache if valid
    if (isCacheValid) {
      if (isFcYahoo) {
        console.log(`[Proxy] Serving cached cookie from memory`);
        return new Response('Cached Cookie', {
          status: 404, // Yahoo returns 404 on fc.yahoo.com
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Expose-Headers': 'x-yahoo-cookie, X-Yahoo-Cookie, Content-Type',
            'Content-Type': 'text/plain',
            'x-yahoo-cookie': cachedCookie,
          }
        });
      }
      if (isGetCrumb) {
        console.log(`[Proxy] Serving cached crumb from memory: ${cachedCrumb}`);
        return new Response(cachedCrumb, {
          status: 200,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'text/plain',
          }
        });
      }
    }

    // 2. Setup Yahoo Headers
    const yahooHeaders = new Headers();
    yahooHeaders.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    yahooHeaders.set('Accept', '*/*');

    // 3. Log and Extract the camouflaged cookie
    const disguisedCookie = request.headers.get('x-proxy-cookie');
    if (disguisedCookie) {
      console.log(`[Proxy] Found x-proxy-cookie. Length: ${disguisedCookie.length}`);
      yahooHeaders.set('cookie', disguisedCookie); // Restore to standard 'cookie'
    } else {
      console.log(`[Proxy] No x-proxy-cookie found in request.`);
    }

    try {
      console.log(`[Proxy] Fetching: ${targetUrl}`);
      const response = await fetch(targetUrl, {
        method: 'GET',
        headers: yahooHeaders,
        redirect: 'follow',
      });

      console.log(`[Proxy] Yahoo Status: ${response.status}`);

      // Clear cache on crumb-related authentication/bad request errors
      if (response.status === 400 || response.status === 401 || response.status === 403) {
        if (targetUrl.includes('crumb=')) {
          console.log(`[Proxy] Yahoo returned ${response.status} on crumbed request. Clearing cache.`);
          cachedCookie = null;
          cachedCrumb = null;
          lastCacheTime = 0;
        }
      }

      // Use ArrayBuffer to prevent encoding hangs
      const body = await response.arrayBuffer();

      // If we are fetching getcrumb and successfully received a crumb, cache it
      if (isGetCrumb && response.status === 200) {
        const text = new TextDecoder().decode(body);
        if (text && !text.includes('<html') && !text.toLowerCase().includes('too many requests') && text.length < 30) {
          cachedCrumb = text;
          lastCacheTime = Date.now();
          console.log(`[Proxy] Successfully cached crumb: ${cachedCrumb}`);
        }
      }

      const proxyResponse = new Response(body, {
        status: response.status,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Expose-Headers': 'x-yahoo-cookie, X-Yahoo-Cookie, Content-Type',
          'Content-Type': response.headers.get('Content-Type') || 'text/plain',
        }
      });

      // 4. Log and Forward Set-Cookie
      const setCookie = response.headers.get('set-cookie');
      if (setCookie) {
        console.log(`[Proxy] Yahoo sent a Set-Cookie. Forwarding via x-yahoo-cookie.`);
        proxyResponse.headers.set('x-yahoo-cookie', setCookie);
        if (isFcYahoo) {
          cachedCookie = setCookie;
          cachedCrumb = null; // Invalidate crumb so they stay in sync
          console.log(`[Proxy] Successfully cached cookie (length: ${setCookie.length})`);
        }
      }

      return proxyResponse;
    } catch (err) {
      console.error(`[Proxy] Error: ${err.message}`);
      return new Response('Proxy Error: ' + err.message, { status: 500 });
    }
  }
};
