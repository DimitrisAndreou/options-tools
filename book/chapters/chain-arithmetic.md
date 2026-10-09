# Chain Arithmetic

So now you understand what the numbers on an option chain page say, but they still look pretty random to you. In the following sections, we will unlock the secrets. You will only need basic arithmetic to follow along, but you will also need attention.

Ideally, you will want to check what you learn with live option chains. Seeing is believing. Here are some places to get live option chains:
- **Yahoo Finance**, example: https://finance.yahoo.com/quote/AAPL/options?p=AAPL  
  Ugly, but free. It has all American stocks/ETFs. Not "live" data except during market hours.
- **Deribit**, https://www.deribit.com/options/BTC  
  Bitcoin options (the underlying doesn't matter for learning purposes), always live prices.

Instead of showing option chains in all their glory, in this section we will study option chains in a simplified manner, to help you focus on the numbers that matter. We will replace each bid / ask pair by a single price (e.g. the mid point), because now we are not looking to place trades, but to understand how these prices work.

The underlying we will study is **NIO**, which is a Chinese electric car maker. The reason is that the price of the NIO stock is low and the numbers are easy to work with, plus it is a very popular stock to trade via options, hence great liquidity in the order books of the option chains, hence the numbers we will look make much sense.

Another benefit of this particular stock is that it doesn't distribute dividends, which would otherwise complicate our calculations.

Caveat: we will ignore that each option contract typically refers to a "lot" (or packet) of 100 shares each. For simplicity, we will assume that each option refers to a single share of the underlying. This doesn't change anything, it only means that a real option contract would be equivalent to 100s of this section.

## Initial Example

Let's familiarize ourselves with the simplified option chain that we are going to dive into:

| Asset | Spot Price | Expiration |
| :--- | :--- | :--- |
| NIO | $5.27 | 106 days |

| Calls ($) | Strike ($) | Puts ($) |
| :---: | :---: | :---: |
| 4.29 | 1 | 0.01 |
| 3.33 | 2 | 0.03 |
| 2.44 | 3 | 0.12 |
| 1.65 | 4 | 0.31 |
| 1.03 | 5 | 0.69 |
| **0.63** | **6** | **1.28** |
| 0.38 | 7 | 2.03 |
| 0.25 | 8 | 2.89 |
| 0.17 | 9 | 3.81 |
| 0.12 | 10 | 4.77 |
| 0.08 | 11 | 5.74 |
| 0.07 | 12 | 6.73 |

This tells us that $NIO is currently worth $5.27 per share, and we are looking at the option chain of the expiration date that is 106 days from today. As for the prices, let's take a strike at random, say, $8. The chart tells us that the Call option at $8 trades at $0.25 per share (thus $25 to buy a Call for 100 shares), and the Put option at the same strike trades at $2.89 per share (thus $289 to buy a Put for 100 shares).

Notice a heavy line separating the strike $5 from $6. This is merely a visual aid to remind you that the spot price of the underlying is somewhere between the two (it's $5.27 as we said), it has no particular significance and can be ignored.

## Higher Strikes → Cheaper Calls

💡 **We notice that as the strike gets bigger, the calls get cheaper. Why?**

We need to remind ourselves. What is a call? It's the right to buy the underlying asset at the strike price, in the future. If you had a call at strike $5, you could buy a share for $5. If someone was to replace your $5 call with a $4 call, you would be better off; you could then buy at $4 instead of $5, saving $1. Hence the lower the strike, the more valuable the call for its owner - and the more money he would demand to give up that call, compared to a call of a higher strike.

**Exercise:** what do you think would be the price of a call of strike $0, and why? I.e. a call that gives you the right to buy the share for *free*. Answer

## Higher Strikes → Richer Puts

💡 **We notice that as the strikes grow, the prices of puts also grow. Why?**

Let's remind ourselves what a put is: it's the right to sell the underlying asset at the strike price, in the future. If you had a put at strike $7, you might sell a share for $7. If someone was to replace your $7 put with a $10 put, you would be better off; you could then sell at $10 instead of $7, receiving an extra $3. Hence the higher the strike, the more valuable the put for its owner - and the more money he would demand to give up that put compared to a put of a lower strike.

**Exercise:** what do you think would be the price of a put of strike $1000, and why? I.e. a put that gives you the right to sell the share for $1000[^28]. Assume it's literally impossible for this stock to come anywhere close at such a price. Answer

## "At The Money" (ATM): Where Calls And Puts Meet

As we saw, for strike near $0, puts are worthless, and calls are nearly as valuable as the underlying itself. Hence, calls > puts. For higher strikes, puts are increasingly more valuable, while calls are increasingly cheaper. At a strike of +∞, calls are completely worthless. It follows that at some strike, the "calls > puts" relation flips and becomes "calls < puts".

| Asset | Spot Price | Expiration |
| :--- | :--- | :--- |
| NIO | $5.27 | 106 days |

| Strike ($) | Calls ($) | Relation | Puts ($) |
| :---: | :---: | :---: | :---: |
| 1 | 4.29 | > | 0.01 |
| 2 | 3.33 | > | 0.03 |
| 3 | 2.44 | > | 0.12 |
| 4 | 1.65 | > | 0.31 |
| 5 | 1.03 | > | 0.69 |
| 6 | 0.63 | < | 1.28 |
| 7 | 0.38 | < | 2.03 |
| 8 | 0.25 | < | 2.89 |
| 9 | 0.17 | < | 3.81 |
| 10 | 0.12 | < | 4.77 |
| 11 | 0.08 | < | 5.74 |
| 12 | 0.07 | < | 6.73 |

In this example, the relation flips between strike $5 and $6. That this happens is insignificant (any two lines that move opposite to each other eventually cross, duh). It is remarkable though that this crossing happens right around the spot price ($5.27)! This is by no means a coincidence: the market is telling us that the spot price is wherever the right to buy becomes exactly equivalent to the right to sell. In other words, it is equally probable that the price will move up or down. Profiting from buying or from selling is a 50-50 chance.

Mind you, this is a simplification. The 50-50 chance is more correctly interpreted as follows: "the price has a 50% chance of overperforming the forward price of the underlying, and 50% underperforming it", which in turn means, "the price has a 50% chance of overperforming the interest rate, and 50% chance of underperforming it".

In the example option chain this is not directly visible, because strikes are 18% of the spot price apart from each other, i.e. they are too sparse. It is plainly visible in other option chains. In other underlyings (e.g. $SPY) there are very frequent strikes (e.g. at 1% intervals), hence one can go to an option chain of a date that is ~1 year apart, and observe that calls and puts cross over not at the spot price, but at the spot price augmented by the interest rate for that duration of time. (This is also a simplification, as we ignore dividends, cost of carry, etc).

That be as it may, we also need to visit some very frequently used terminology: the strike which is nearest to the spot price is called **"At The Money"** (ATM). For example, an "at the money call", or an "at the money put", would refer here at a call or put of the $5 strike. Option chain visualizations typically highlight the spot price (like we do, with a heavy horizontal line separating the $5 from the $6 strike). Sometimes they highlight the crossover point, i.e. the forward price.

TODO: "in the money, at the money, out of the money", defined here? Or earlier??

## Spot-Buying Vs Buying Through Calls

💡 **We notice that an alternative to buying NIO shares directly, is to buy calls (i.e. rights to buy), and then immediately exercise[^29] those rights, thus ending up buying NIO shares. Is it worth it?**

For example, the call at $3 is worth $2.44. So we can buy a share by (1) buying that call for $2.44, (2) then exercising that call, meaning we buy for a further $3. Hence in total, we paid $2.44 + $3 = $5.44 dollars, for buying a share.

| Asset | Spot Price | Expiration |
| :--- | :--- | :--- |
| NIO | $5.27 | 106 days |

| Calls ($) | Strike ($) | Total Cost ($) |
| :---: | :---: | :---: |
| 4.29 | 1 | 4.29 + 1 = 5.29 |
| 3.33 | 2 | 3.33 + 2 = 5.33 |
| 2.44 | 3 | 2.44 + 3 = 5.44 |
| 1.65 | 4 | 1.65 + 4 = 5.65 |
| 1.03 | 5 | 1.03 + 5 = 6.03 |
| 0.63 | 6 | 0.63 + 6 = 6.63 |
| 0.38 | 7 | 0.38 + 7 = 7.38 |
| 0.25 | 8 | 0.25 + 8 = 8.25 |
| 0.17 | 9 | 0.17 + 9 = 9.17 |
| 0.12 | 10 | 0.12 + 10 = 10.12 |
| 0.08 | 11 | 0.08 + 11 = 11.08 |
| 0.07 | 12 | 0.07 + 12 = 12.07 |

The cheapest price we can achieve by exercising a call is via the $1 strike (the lowest available strike) call, through which we can buy NIO at $5.29 a piece, more, but we can already buy NIO at $5.27 through the spot market. It's never worth it.

## Spot-Selling Vs Selling Through Puts

💡 **We notice that an alternative to selling NIO shares directly, is to buy puts (i.e. rights to sell), and then immediately exercise those rights, thus ending up selling NIO shares. Is it worth it?**

For example, the put at $6 is worth $1.28. So we can sell a share by (1) buying that put for $1.28, (2) then exercising that put, meaning we sell for $6. Hence we paid $1.28, then received $6, thus we received $-1.28 + $6 = $4.72 net, for selling a share.

| Asset | Spot Price | Expiration |
| :--- | :--- | :--- |
| NIO | $5.27 | 106 days |

| Total Revenue ($) | Strike ($) | Puts ($) |
| :---: | :---: | :---: |
| -0.01 + 1 = 0.99 | 1 | 0.01 |
| -0.03 + 2 = 1.97 | 2 | 0.03 |
| -0.12 + 3 = 2.88 | 3 | 0.12 |
| -0.31 + 4 = 3.69 | 4 | 0.31 |
| -0.69 + 5 = 4.31 | 5 | 0.69 |
| -1.28 + 6 = 4.72 | 6 | 1.28 |
| -2.03 + 7 = 4.97 | 7 | 2.03 |
| -2.89 + 8 = 5.11 | 8 | 2.89 |
| -3.81 + 9 = 5.19 | 9 | 3.81 |
| -4.77 + 10 = 5.23 | 10 | 4.77 |
| -5.74 + 11 = 5.26 | 11 | 5.74 |
| -6.73 + 12 = 5.27 | 12 | 6.73 |

Turns out, it's never worth it. The best sum of money we can achieve with this method is via the $12 strike put, through which we can sell NIO at $5.27 a piece, which is the same as the spot market (but we can assume the spot market has lower transaction fees).

## Spot-Selling Vs Promising To Sell

💡 **How does selling via spot compare to selling indirectly, via offering obligations to sell?**

Writing a call means granting the owner of that call the right to buy (from you) a share, at the agreed price (strike). You essentially make a promise to sell. Let's assume that the other party decides to exercise their right, and holds you up to your promise, thus you end up selling. How does that compare to you directly selling to the spot market instead?

| Asset | Spot Price | Expiration |
| :--- | :--- | :--- |
| NIO | $5.27 | 106 days |

| Calls ($) | Strike ($) | Total Revenue ($) |
| :---: | :---: | :---: |
| 4.29 | 1 | 4.29 + 1 = 5.29 |
| 3.33 | 2 | 3.33 + 2 = 5.33 |
| 2.44 | 3 | 2.44 + 3 = 5.44 |
| 1.65 | 4 | 1.65 + 4 = 5.65 |
| 1.03 | 5 | 1.03 + 5 = 6.03 |
| 0.63 | 6 | 0.63 + 6 = 6.63 |
| 0.38 | 7 | 0.38 + 7 = 7.38 |
| 0.25 | 8 | 0.25 + 8 = 8.25 |
| 0.17 | 9 | 0.17 + 9 = 9.17 |
| 0.12 | 10 | 0.12 + 10 = 10.12 |
| 0.08 | 11 | 0.08 + 11 = 11.08 |
| 0.07 | 12 | 0.07 + 12 = 12.07 |

First we sell a call, thus are paid its price, then we sell at the strike. For example, via the call of strike $4, we sell the call for 1.65, then we sell the stock for $4. The result is selling a stock for $1.65 + $4 = $5.65. That's more than what we would receive in the spot market!

Turns out, selling via selling calls always results in more proceeds than selling directly via the spot market. But unlike spot-selling, this method does not guarantee that you'll sell the shares; this depends on whether the other party exercises the call. He would only do that if the selected strike is higher than the spot market. Otherwise, why buy from you when he can buy from the market for less?

## Spot-Buying Vs Promising To Buy

💡 **How does buying via spot compare to buying indirectly, via offering obligations to buy?**

Writing a put means granting the owner of that put the right to sell (to you) a share, at the agreed price (strike). You essentially make a promise to buy. Let's assume that the other party decides to exercise their right, and holds you up to your promise, thus you end up buying. How does that compare to you directly buying from the spot market instead?

| Asset | Spot Price | Expiration |
| :--- | :--- | :--- |
| NIO | $5.27 | 106 days |

| Total Cost ($) | Strike ($) | Puts ($) |
| :---: | :---: | :---: |
| -0.01 - 1 = 0.99 | 1 | 0.01 |
| -0.03 + 2 = 1.97 | 2 | 0.03 |
| -0.12 + 3 = 2.88 | 3 | 0.12 |
| -0.31 + 4 = 3.69 | 4 | 0.31 |
| -0.69 + 5 = 4.31 | 5 | 0.69 |
| -1.28 + 6 = 4.72 | 6 | 1.28 |
| -2.03 + 7 = 4.97 | 7 | 2.03 |
| -2.89 + 8 = 5.11 | 8 | 2.89 |
| -3.81 + 9 = 5.19 | 9 | 3.81 |
| -4.77 + 10 = 5.23 | 10 | 4.77 |
| -5.74 + 11 = 5.26 | 11 | 5.74 |
| -6.73 + 12 = 5.27 | 12 | 6.73 |

First we sell a put, thus are paid its price, then we sell at the strike. For example, via the put of strike $5, we sell the put for 0.69, then we buy the stock for $5. The result is buying a stock for $5 - $0.69 = $4.31. That's less than what we would spend in the spot market!

Turns out, buying via selling puts is always cheaper than buying directly via the spot market. But unlike spot-buying, this method does not guarantee that you'll get the shares; this depends on whether the other party exercises the put. He would only do that if the selected strike is higher than the spot market. Otherwise, why sell to you when he can sell to the spot market for more?

## The Farther From ATM, The Smaller The Change Between Strikes

Η διαφορα των διαδοχικων μικραινει οσο μακρυτερα απο "ATM", γιατι?

## Longer Expirations Mean Higher Prices

Δείξε ότι με παραπάνω χρόνο, όλα αυξάνονται (γιατί?)

## What Happens When Spot Price Moves?

## Call And Put Prices Are Related! (Put-Call Parity)

## Project An Option Onto The Future!

| Asset | Spot Price | Expiration |
| :--- | :--- | :--- |
| NIO | $5.27 | 1 day ‒ 106 days ‒ 197 days |

| Calls ($) | Strike ($) | Puts ($) |
| :---: | :---: | :---: |
| 4.27 ‒ 4.29 ‒ 4.37 | 1 | 0.00 ‒ 0.01 ‒ 0.10 |
| 3.27 ‒ 3.33 ‒ 3.39 | 2 | 0.00 ‒ 0.03 ‒ 0.12 |
| 2.28 ‒ 2.44 ‒ 2.55 | 3 | 0.00 ‒ 0.12 ‒ 0.25 |
| 1.28 ‒ 1.65 ‒ 1.85 | 4 | 0.01 ‒ 0.31 ‒ 0.54 |
| 0.33 ‒ 1.03 ‒ 1.30 | 5 | 0.05 ‒ 0.69 ‒ 0.96 |
| 0.03 ‒ 0.63 ‒ 0.98 | 6 | 0.75 ‒ 1.28 ‒ 1.62 |
| 0.01 ‒ 0.38 ‒ 0.68 | 7 | 1.73 ‒ 2.03 ‒ 2.31 |
| 0.00 ‒ 0.25 ‒ 0.49 | 8 | 2.73 ‒ 2.89 ‒ 3.11 |
| 0.00 ‒ 0.17 ‒ 0.37 | 9 | 3.73 ‒ 3.81 ‒ 3.98 |
| 0.00 ‒ 0.12 ‒ 0.28 | 10 | 4.73 ‒ 4.77 ‒ 4.89 |
| 0.00 ‒ 0.08 ‒ 0.22 | 11 | 5.73 ‒ 5.74 ‒ 5.83 |
| 0.00 ‒ 0.07 ‒ 0.17 | 12 | 6.73 ‒ 6.73 ‒ 6.78 |

Δεν χρειάζεται paper trading: μπορεί κάποιος ΣΗΜΕΡΑ να δει τις σχετικές αξίες των options. Πχ αν αναρωτιεται πώς θα μεταβληθει η αξια ενος συμβολαιου.

Example: short put that goes way OTM. Long call that goes way ITM. Spread.  
Example: show how option loses value as expiration becomes shorter.  
Γιατί η αξία του future εξισωνεται με το underlying στην λήξη? (Maybe not here)  
formula: `startYield/remainingYield=pastYield`. This will be later used for touch bets.

Option chain: καλυτερα να κοιτας puts (οταν < spot price) και calls (οταν > spot price). Οι αλλες τιμες ειναι "ITM" αλλα μερος τους αποζημειωνει... (ειναι σαν να παιρνεις δανειο)

Δειξε ακριβως πως απ' το ενα πας στο αλλο. Θα μπορουσαν να μην υπαρχουν calls, ή θα μπορουσαν να μην υπαρχουν puts.

$$Forward = Call - Put$$

Synthetic future  
(Apply Call-Put Parity in following strategies)  
Literature treats it as a formula to compute prices, thus arbitrage opportunities. But symbolically is more useful.

Where to show algebra of:
- instead of closing a short put, you can reduce its price or shorten its expiration
- i.e. you can add or remove time, you can move legs, A put is the sum of its verticals.

Spread with calls = spread with puts:
$$S = C(100) - P(100)$$
$$S = C(110) - P(110)$$

Τώρα, ξεκιναω με $C(100) - C(110)$ που ειναι το debit spread:
$$C(100) - C(110) = (S + P(100)) - (S + P(110)) = S + P(100) - S - P(110) = P(100) - P(110)$$
αρα:
$$C(100) - C(110) = P(100) - P(110)$$

Spread arithmetic:
- single long put can be thought as a spread from 0.
- single long call can be thought as a spread to +∞.
Show

## Summary

- Lower strikes -> cheapens puts, enriches calls
- Higher strikes -> cheapens calls, enriches puts
- Buying via puts-writing: always cheaper
- Selling via calls-writing: always richer

[^28]: Or for a strike of... precisely $1,005.27, to make the answer round. 😉 The implied answer is somewhat off though, it ignores the effect of positive interest rates. Let's ignore this for now.
[^29]: Let's assume we can immediately exercise these NIO options, i.e. that we are talking about "American"-style options (vs European). This is actually the case for stock options, like NIO.
