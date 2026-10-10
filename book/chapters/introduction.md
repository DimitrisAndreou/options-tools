<!-- Keywords:
visualizing position payoffs
profit and loss (PnL) at expiration
bull call spread example
intrinsic value functions at expiration
call intrinsic value formula max(S - K, 0)
put intrinsic value formula max(K - S, 0)
net payoff with premium Pi(S)
subjectively mutually beneficial
Cautious Charlie vs Risky Richey
praxeological exchange: voluntary trade implies subjective preference
diminishing marginal utility of money
objectively zero-sum game in money terms
where trading profit comes from
gambling vs investing distinction
about the author
-->

# Introduction


## Visualizing Position Payoffs

Understanding options requires clear visual models of PnL (Profit and Loss) at expiration point across any underlying asset price.

Below is an example payoff diagram of a **Bull Call Spread** generated directly from our position analyzer engine:

![Bull Call Spread Payoff](../assets/figures/sample_payoff.svg)

### Position Key Metrics
- **Long Leg**: Buy $100 Call @ \$5.00
- **Short Leg**: Sell $110 Call @ \$2.00
- **Net Cost / Max Risk**: \$3.00 (\$300 total)
- **Max Profit**: \$7.00 (\$700 total)
- **Breakeven Point**: \$103.00

### Intrinsic Value Functions at Expiration

For an underlying asset price $S$ at expiration:

- **Call Option Intrinsic Value**:
  $$V_{\text{call}}(S) = \max(S - K, 0)$$

- **Put Option Intrinsic Value**:
  $$V_{\text{put}}(S) = \max(K - S, 0)$$

When combined with position sizing and entry premiums $P$, the Net Payoff $\Pi(S)$ for a single long call position becomes:

$$\Pi_{\text{long call}}(S) = \max(S - K, 0) - P$$



