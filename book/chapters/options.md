# Options

An **option** is a choice between two outcomes at a specified moment in the future (the **expiration date**).

One outcome is to do nothing and walk away. The other outcome is to execute a predetermined exchange of two baskets of goods.

## Economic Calculation at Expiration

As established earlier, economic calculation allows us to mark to market any basket of goods into a single quantity of our base currency: its immediate liquidation value.

At expiration, the decision maker simply evaluates the market cash value of both outcomes. They will pick whichever leaves them with more money.

In financial markets, one of the two baskets is always money itself: an agreed cash amount called the **strike price**. The other basket is a specific quantity of an underlying asset.

## Symmetries: Calls and Puts

Because money sits on one side of the exchange, human language uses two distinct terms depending on the direction of money:

- **Call (Right to Buy):** The holder has the right to exchange cash (the strike) to receive the asset. If the asset's spot price exceeds the strike price, they "call" the asset in at a discount.
- **Put (Right to Sell):** The holder has the right to exchange the asset to receive cash (the strike). If the asset's spot price is below the strike price, they "put" (deliver) the asset onto the counterparty at a premium.

A call and a put are the exact same fundamental contract—an asymmetric future exchange of an asset for money—viewed from opposite sides of the transaction.

## The Anatomy of an Option Contract

Every standardized option contract specifies four core parameters:

1. **Underlying Asset:** The specific asset to be exchanged (e.g. shares of $ACME).
2. **Strike Price ($K$):** The fixed exchange price in money.
3. **Expiration Date ($T$):** The exact date and time at which the choice must be made.
4. **Lot Size (Multiplier):** The quantity of the underlying governed by a single contract (conventionally 100 shares for US equity options).

The buyer acquires the **right** to choose and pays an upfront cash **premium** to the seller (the **writer**), who takes on the binding **obligation** to fulfill the terms if requested.

## Real-World Complexities

To understand options conceptually, settlement details and exercise windows can be abstracted away, though in practice they introduce structural differences:

- **Exercise Style:**
  - *American-style:* Can be exercised at any point up to and including the expiration date.
  - *European-style:* Can only be exercised precisely on the expiration date.  
  *(See [Miscellaneous](miscellaneous.md) for early exercise boundaries and implications).*

- **Settlement Method:**
  - *Physical Settlement:* The underlying asset changes hands directly in exchange for cash.
  - *Cash Settlement:* No assets are delivered; the net difference between the spot price and the strike price is settled directly in cash.  
  *(See [Miscellaneous](miscellaneous.md) and [Taxation](taxation.md) for settlement mechanics and tax differences).*
