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
