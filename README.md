# Options Tools

## Philosophy & Reasoning

We are strictly realists. We do not like to impose statistical assumptions or
models on top of markets; we only rely on what the market prices tell us.
Thus, we can compute PNL at expiration point, strictly based on intrinsic value
of positions (and we can infer the extrinsic value, aka time value, 
by deducing the intrincic one), never on assumptions about IVs. No greeks,
no Black-Scholes around here. Only things provable directly from today's market prices.

Further examples of strictly price-based, realistic reasoning: let's say a
strategy that has a duration of 6 months offers a money yield of 10%.
*We will never present it as a 20% APR*! Because we cannot assume that after
6 months, we can repeat the same strategy with the same conditions; that would
assume the state of the prices in 6 months, and that we cannot do. Similarly,
if we see that the 1-month straddle costs 10% of the stock, and the 2-month
straddle costs 20% of the stock, we cannot assume that a straddle of 1.5
months would cost 15% of the stock.

We cannot make up prices and pretend to know the unknowable just to make the
math convenient.

## Main tool: strategy visualizer

The main tool is at web/index.html. A user selects a ticker, we load live options
data, and then we compute every possible instance for a selected strategy family
(e.g. covered calls), and visualize them. We also show a comprehensive set of
data properties of each selected strategy.

The user is also able to "pin"/track selected strategies, and see how they change
over time (including their unrealized PnL).

### Code organization

The UI is handled in javascript (web/main.js, web/covered_calls.js, web/strategy_registry.
js, etc.). All the "interesting" logic is delegated to Dart. A powerful library for
constructing complex positions (with assets/futures/options) is implemented in dart
(lib/assets.dart (Asset, Position, Line), lib/markets.dart (Market), lib/oracle.dart
etc).  In lib/strategies.dart, we compute, using our dart framework, all instances of all
strategy families that we support. The files web/main.js and web/main.dart, and lib/strategies_gateway.dart, integrate JS and Dart. The only current flow is JS invoking Dart,
and receiving JSON data from it.

lib/position_analyzer is our PNL calculator, for a given expiration, and any possible
price of the underlying asset. We strive to not calculate interesting data (such as
breakeven points) via adhoc formulas, but rather rely on generic, battle-tested
calculators that can handle any position, even if it's slower. We prefer correctness
and reliability!

Option data is fetched via lib/data/deribit.dart (for BTC & ETH), which is very
reliable, and lib/data/yfinance.dart which uses Yahoo Finance (for American tickers).
This is more complicated as it needs a cloudflare worker to bypass CORS issues,
plus YFinance generally doesn't like scrapers.


## IBKR PnL aggregator

A minor helper tool that fulfills a very niche goal: it aggregates the PnL reports
from IBKR, per *symbol*. E.g. if you have shares of $ACME, plus options on $ACME,
IBKR currently has no way to tell you "this is your total PnL for $ACME, using
all instruments". This is what our tool does. The entry point is web/ibkr.html.

### Code organization

That's a simpler tool. It also relies on Dart for data processing. See web/main_ibkr.js,
web/ibkr.dart, and lib/data/ibkr.dart.

## Running and building

To run the app (which serves all tools), activate and use [`package:webdev`](https://dart.dev/tools/webdev):

```
webdev serve
```

If `webdev` is not found, then you need to run:
```
dart pub global activate webdev
```

For a first time setup, you would also likely need:
```
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.bashrc
source ~/.bashrc
```


To build a production version ready for deployment,
use `build_runner`:

```
dart run build_runner build --release -o web:docs
```

That compiles web/* and copies the static files in docs/. This directory is
then served by GitHub pages, at this location:
https://dimitrisandreou.github.io/options-tools

## Testing

Run `dart test` to run all tests. Agents should not be trying to debug or verify the UI
on their own; leave it to the human.

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
5. Rebuild the application for production using `dart run build_runner build --release -o web:docs`.

