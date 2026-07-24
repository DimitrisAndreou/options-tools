export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // 1. Handle CORS Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, User-Agent, Accept',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Expose-Headers': '*',
    };

    const token = url.searchParams.get('token') || url.searchParams.get('t');
    const queryId = url.searchParams.get('queryId') || url.searchParams.get('q');
    const targetUrl = url.searchParams.get('target');

    // 2. Direct Token & Query ID automated two-step query flow
    if (token && queryId) {
      try {
        console.log(`[IBKR Proxy] Step 1: Requesting Flex Statement for Query ID: ${queryId}`);
        const sendReqUrl = `https://ndcdyn.interactivebrokers.com/AccountManagement/FlexWebService/SendRequest?t=${encodeURIComponent(token)}&q=${encodeURIComponent(queryId)}&v=3`;
        
        let sendResponse = await fetch(sendReqUrl, {
          method: 'GET',
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
          },
        });

        let sendXml = await sendResponse.text();
        console.log(`[IBKR Proxy] Step 1 Response: ${sendXml}`);

        // Retry Step 1 if report generation is in progress (Code 1019)
        let step1Retries = 0;
        while ((sendXml.includes('1019') || sendXml.includes('generation in progress')) && step1Retries < 5) {
          step1Retries++;
          console.log(`[IBKR Proxy] Step 1 statement generation in progress (Code 1019). Waiting 3s (Retry ${step1Retries}/5)...`);
          await new Promise(res => setTimeout(res, 3000));
          
          sendResponse = await fetch(sendReqUrl, {
            method: 'GET',
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': '*/*',
            },
          });
          sendXml = await sendResponse.text();
          console.log(`[IBKR Proxy] Step 1 Retry ${step1Retries} Response: ${sendXml}`);
        }

        const statusMatch = sendXml.match(/<Status>(.*?)<\/Status>/i);
        const refCodeMatch = sendXml.match(/<ReferenceCode>(.*?)<\/ReferenceCode>/i);
        const status = statusMatch ? statusMatch[1] : null;
        const refCode = refCodeMatch ? refCodeMatch[1] : null;

        if ((status === 'Success' || refCode) && refCode) {
          console.log(`[IBKR Proxy] Step 2: Fetching statement with Reference Code: ${refCode}`);
          const getStmtUrl = `https://ndcdyn.interactivebrokers.com/AccountManagement/FlexWebService/GetStatement?q=${encodeURIComponent(refCode)}&t=${encodeURIComponent(token)}&v=3`;

          let stmtResponse = await fetch(getStmtUrl, {
            method: 'GET',
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': '*/*',
            },
          });

          let stmtXml = await stmtResponse.text();

          // Retries Step 2 if report is still generating (IBKR code 1019)
          let step2Retries = 0;
          while ((stmtXml.includes('1019') || stmtXml.includes('generation in progress')) && step2Retries < 5) {
            step2Retries++;
            console.log(`[IBKR Proxy] Step 2 statement generation in progress (Code 1019). Waiting 3s (Retry ${step2Retries}/5)...`);
            await new Promise(res => setTimeout(res, 3000));
            stmtResponse = await fetch(getStmtUrl, {
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              },
            });
            stmtXml = await stmtResponse.text();
          }

          return new Response(stmtXml, {
            status: 200,
            headers: {
              ...corsHeaders,
              'Content-Type': stmtResponse.headers.get('Content-Type') || 'application/xml',
            },
          });
        } else {
          console.error(`[IBKR Proxy] Step 1 Failed. Response: ${sendXml}`);
          return new Response(sendXml, {
            status: 200, // Return 200 with XML so frontend can handle IBKR error tags cleanly
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/xml',
            },
          });
        }
      } catch (err) {
        console.error(`[IBKR Proxy] Error processing token/queryId: ${err.message}`);
        return new Response(`IBKR Proxy Error: ${err.message}`, {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
        });
      }
    }

    // 3. Fallback: Generic Proxy with Target URL
    if (targetUrl) {
      if (!targetUrl.includes('interactivebrokers.com')) {
        return new Response('Only interactivebrokers.com targets are allowed', {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
        });
      }

      try {
        console.log(`[IBKR Proxy] Fetching target: ${targetUrl}`);
        const response = await fetch(targetUrl, {
          method: 'GET',
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
          },
        });

        const body = await response.arrayBuffer();
        return new Response(body, {
          status: response.status,
          headers: {
            ...corsHeaders,
            'Content-Type': response.headers.get('Content-Type') || 'application/xml',
          },
        });
      } catch (err) {
        console.error(`[IBKR Proxy] Error fetching target: ${err.message}`);
        return new Response(`IBKR Proxy Error: ${err.message}`, {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
        });
      }
    }

    return new Response('IBKR Proxy Service: Please supply token and queryId parameters (or target URL).', {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
    });
  },
};
