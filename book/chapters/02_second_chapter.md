# Chapter 2: Option Mechanics & Intrinsic Payoffs

## Fundamental Building Blocks

An option contract gives the holder the right (but not the obligation) to buy or sell an underlying asset at a specified strike price ($K$) on or before expiration.

### Intrinsic Value Functions at Expiration

For an underlying asset price $S$ at expiration:

- **Call Option Intrinsic Value**:
  $$V_{\text{call}}(S) = \max(S - K, 0)$$

- **Put Option Intrinsic Value**:
  $$V_{\text{put}}(S) = \max(K - S, 0)$$

When combined with position sizing and entry premiums $P$, the Net Payoff $\Pi(S)$ for a single long call position becomes:

$$\Pi_{\text{long call}}(S) = \max(S - K, 0) - P$$

---

## Piecewise Linear Payoff Curves

Because every standard option payoff is composed of linear segments joined at strike points ($K$), any portfolio of options and underlying assets forms a **piecewise linear function** over $S$.

Our analysis engine leverages this property to guarantee mathematically exact breakeven points without numerical approximation errors.

```
       PnL
        ^
Max     |               / (Slope = +1)
Profit  +--------------/ 
        |             /
        |            /
--------+-----------+-------------> Underlying Price (S)
        |          K (Strike)
Max     |        /
Risk    +-------/ 
```

In the next chapter, we will examine single-leg position behaviors and capital requirements in detail.
