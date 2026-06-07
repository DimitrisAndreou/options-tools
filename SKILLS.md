# Options Tools - Philosophy & Guidelines

The `options-tools` project exists to serve as an advanced options strategies
calculator. The core options algebra of positions/strategies/market data should
all exist in Dart. Only UI logic should be handled in JS. The two communicate via
JSON messages flowing from Dart to JS.

## 🧠 Project Philosophy & Reasoning

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
