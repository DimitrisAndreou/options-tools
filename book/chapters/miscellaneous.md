# Miscellaneous

Topics and real-world mechanics deferred from conceptual foundations.

## American vs. European Options
<!-- 
Promise from options.md:
- Early exercise boundaries and implications:
  - American style: can exercise any time up to expiration.
  - European style: can only exercise at expiration.
  - Why early exercise of American options is usually suboptimal (surrendering remaining time/extrinsic value), with exceptions (e.g., deep ITM puts or calls right before an ex-dividend date).
  - Pin risk and assignment dynamics for option sellers.
-->

## Settlement: Cash vs. Physical
<!-- 
Promise from options.md:
- Physical settlement: actual underlying shares/assets change hands for strike price × lot size. Requires sufficient account capital or margin to hold the underlying position.
- Cash settlement: difference between spot and strike is settled purely as a cash credit/debit (common in index options like SPX).
- Tax and friction implications: physical assignment can trigger capital gains events on the underlying stock or force margin loan interest, whereas cash-settled contracts avoid secondary transaction steps.
-->

## Margin Trading & Obligations
<!--
- Who enforces obligations? The clearing house (e.g. OCC) and the broker.
- How collateral/margin works for short options: cash-secured vs. margin requirements.
- Assignment mechanics: random allocation among short option holders.
-->

## Dividends & Corporate Actions
<!--
- Impact of dividends on option pricing: stock drops by dividend amount on ex-date.
- Early exercise risk for short call holders before ex-dividend date.
- Contract adjustments for stock splits, reverse splits, and special dividends.
-->

## What To Do With The Premium
<!--
- Reinvesting collected premium vs. holding cash buffer for margin.
- The psychological trap of treating collected premium as "instant free income".
-->

## Accounting
<!--
- Mark-to-market valuation of portfolio positions.
-->
Κάποιοι μπερδεύουν την έννοια unrealized loss με κάποιο short option που ακρίβυνε. Διευκρίνισε ότι το realized/unrealized είναι καθαρά φορολογική διάκριση, και εξήγησε πώς γίνεται η αποτίμηση της αξίας του χαρτοφυλακίου μια χρονική στιγμή (mark to market). Μπορεί κάποιος να προβάλλει στο μέλλον την αξία του χαρτοφυλακίου, αλλά η σημερινή χασούρα είναι χασούρα, απολύτως πραγματική και μη αναστρέψιμη (αν δεν υπήρχε, θα είχες περισσότερα λεφτά και τώρα και στο μέλλον).

## The Greeks
<!--
- Intuitive sensitivities of option price to underlying changes:
  - Delta: sensitivity to spot price moves (hedge ratio / synthetic stock equivalent). First derivative.
  - Gamma: acceleration of delta as spot moves. Second derivative.
  - Theta: sensitivity to the passage of time (time decay).
  - Vega: sensitivity to changes in market-implied volatility.
  - Rho: sensitivity to risk-free interest rates (linking back to Fetter's time preference & futures pricing).
-->
