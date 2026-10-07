# Chapter 1: Introduction & Market Realism

## The Philosophy of Realist Options Trading

Most options textbooks begin by introducing mathematical abstractions—such as the Black-Scholes model, implied volatility surfaces, and Greek partial derivatives. While these theoretical models are widely taught, they rely on heavy statistical assumptions (such as log-normal asset returns and continuous price paths) that do not always match real-world market dynamics.

In this book, we adopt a **strict price realist philosophy**:
1. **Direct Market Observation**: We rely only on what market prices explicitly tell us today.
2. **Expiration Intrinsic PnL**: Payoffs and risk profiles are evaluated strictly based on the intrinsic value of positions at expiration.
3. **No Unprovable Assumptions**: We do not extrapolate annual yields (e.g. turning a 6-month 10% yield into a hypothetical 20% APR) because market conditions cannot be assumed to repeat identically.

---

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

In subsequent chapters, we will explore how every complex multi-leg position can be decomposed into fundamental line segments to calculate exact risk boundaries.
