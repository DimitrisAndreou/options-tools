A bare-bones Dart web app.

Uses [`package:web`](https://pub.dev/packages/web)
to interop with JS and the DOM.

## Running and building

To run the app,
activate and use [`package:webdev`](https://dart.dev/tools/webdev):

```
dart pub global activate webdev
webdev serve
```

For a first time setup, you would also likely need:
```
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.bashrc
source ~/.bashrc
```


To build a production version ready for deployment,
use the `webdev build` command:

```
webdev build --output web:docs
```

To learn how to interop with web APIs and other JS libraries,
check out https://dart.dev/interop/js-interop.

## Cloudflare Worker Proxy Deployment

We use a Cloudflare Worker to proxy Yahoo Finance requests and handle CORS/cookie passing for the browser client. The configuration is defined in `wrangler.toml`, and the worker source code resides in `worker/index.js`.

### 1. Authenticating with Cloudflare
If you haven't already logged into the Wrangler CLI on this machine, run:
```bash
npx wrangler login
```
This will open a browser window asking you to authorize Wrangler with your Cloudflare account.

You'd need to install nodejs and npm first: 
```bash
sudo apt update && sudo apt install -y nodejs npm
```

### 2. Deploying/Updating Workers

- **Yahoo Proxy Worker** (`yahoo-proxy-v2`):
  ```bash
  npx wrangler deploy
  ```
- **IBKR Proxy Worker** (`ibkr-proxy`):
  ```bash
  npx wrangler deploy -c wrangler.ibkr.toml
  ```

Wrangler will compile, upload, and deploy the worker to your Cloudflare account (e.g., `https://ibkr-proxy.jim-andreou.workers.dev`).

### 3. Configuring the Web App to Use Your New Worker
Once deployed:
1. Open [lib/data/url_fetcher.dart](file:///home/jimandreou/options-tools/lib/data/url_fetcher.dart).
2. Locate the `_proxyBase` constant:
   ```dart
   static const String _proxyBase =
       'https://yahoo-proxy.jim-andreou.workers.dev';
   ```
3. Replace the URL with your new worker's endpoint.
4. For IBKR Flex queries (`web/ibkr.html`), the default worker URL (`https://ibkr-proxy.jim-andreou.workers.dev/`) can also be customized directly in the input field on the page.
5. Rebuild the application for production using `webdev build --output web:docs`.

