# Capital

## Understanding Capital

The introduction is meant to "whet the appetite" for the reader, and build motivation to explore the rather complex topic of options in detail. Nevertheless, we should take things from the beginning, and gradually build the concepts we rely upon. Trading options involves...trading, and trading implies ownership. Trading means swapping titles of ownership between their respective owners.

Further, trading typically implies a market economy, i.e. the existence of a general medium of exchange, i.e. money. Money facilicates exchanges, and we find money on one side of nearly every exchange that takes place. We don't need to discuss how money has evolved and why people accept it in exchange for other assets/goods.

The market economy implies that assets can be traded in the market for a price, thus they can be compared to an "equivalent" amount of money. I.e., for your house, car, or shares of $ACME, you can estimate an amount of money that they could fetch, if you were to sell them. This is the basis of accounting, and also of entrepreneurial activity. For example, one can estimate the expected inputs/costs of an enterprise, reduce them all into money, then estimate the expected outputs/revenue of the enterprise, reduce them into money as well, and then assess the relation between the expected revenue and the expected cost. They are both expressed in money so they can be compared; apples to apples.

<!-- Note for Options chapter:
Prices are ratios between two goods. Every trader naturally prefers an improved price: either giving away less to obtain the same quantity of the other good, or giving away the same amount to obtain more. Economic calculation lets us compare any exchangeable good to a quantity of money (its liquidation value).
-->

This is what allows you to see the progress, or the profit or loss, of your trading account. Your "net worth" is the sum of all your assets, minus all your liabilities. Both your assets and your liabilities come with a size, the quantity you own/owe of each asset. A liability is basically an asset owned by someone else, it is as if you have a negative quantity of an asset. When we associate an asset with a size (positive or negative, but not zero), e.g. "20 shares of $ACME", we speak of a position. Your portfolio is a collection of positions. 

Capital has myriad definitions. For our needs, capital is merely a quantity of money. When we speak of "your capital", we refer to the particular amount of currency which is equivalent to your portfolio; your entire positions, all your assets and liabilities. It doesn't matter if your capital is literally a given amount of cash or it is a basket of other positions; all that is needed is that every asset in your portfolio can be exchanged for money. To calculate your capital, we "mark to market" the asset in each of your positions (i.e. take the best known price for the asset), multiply it the position's size (which could be negative), then add all positions together. You are (or should be) particularly sensitive to whether your capital goes "up" or "down". That is, whether your portfolio grows in value or diminishes.

For example, say you own $10,000 cash, 200 shares of $ACME (its current price is $100), and 0.1 Bitcoin (its current price is $58,000), and you owe 5,000€ (the EUR.USD rate is $1.10). 

Then, your capital, in terms of dollars, would be: 
$10,000 cash
200 ACME shares * 100($/ACME) = $20,000
0.1 BTC * 58000($/BTC) = $5,800
-5000€ * ($1.1/€) = ($5500)
For a grand total of 10000 + 20000 + 5800 - 5500 = $30300.

Or, your capital in euros would be:
$10,000 cash / ($1.1/€) = 9090.9€
200 ACME shares * $100 / ($1.1/€) = 18181.8€
0.1 BTC * 58000 (BTC/$) / ($1.1/€) = 5272.7€
-5000€
For a grand total of 9090.9 + 18181.8 + 5272.7 - 5000 = 27545.4€


## Ownership, Risk, Profit

Risk is the potential of capital loss. Any ownership inherently involves risk: you may see today's prices, but you can't know what price your assets would fetch in the future. It is worth it to take a moment and ponder on just how unavoidable the uncertainty is: these prices depend on the preferences of people in the future. You don't even know what will your own preferences be in the future. They may depend on what else is going on in your life in the future, or even at your unpredictable whims. You may attempt to forecast, but you really can't know the future.

Maybe you own a house, and something bad happens in the neighborhood and people are less willing to live there. Or maybe you own shares of your favorite company, and it turns out its latest product is a dud. Or you own gold, but the people of India decide they need less of it for jewelry. Or you own bitcoin, but the people of the future decide that something like monero is a better bitcoin.

Unless something is horribly wrong with your chosen base currency, these misfortunes would be reflected in your accounting. The market price of the impacted assets would fall, thus by marking your assets to "market", you would notice a corresponding loss of capital due to them.

When we speak of the risk, instead of a risk, we typically mean the worst case scenario for the involved capital. E.g. if you invest $1000 to $ACME, the risk is $1000, since the worst case scenario for your capital is that $ACME goes to zero, and in that case, you indeed lose $1000 of your capital. On the other hand, one may speak like this: "there is a risk that $ACME falls by 10% if such and such conditions occur". In that sense, "a risk" is merely the potential of some bad (not necessarily the worst) outcome materializing.

If you stand to lose capital due to a particular change of some market price, it implies you stand to profit if the price moves the other way.


## Base Currency

As we saw earlier, your capital, at any point in time, depends on the choice of a money - the base currency. Some people reduce their holdings to a quantity of dollars, others euros, yet others choose swiss francs. On the fringe there are even people who do their accounting in ounces of gold or in bitcoin. Unfortunately, there's no universal right answer, and the choice of base currency may affect your outlook and decisions. E.g. Americans may think they are growing richer in terms of dollars, when simultaneously they grow poorer in terms of francs or gold.

It is paramount to understand the implications of choosing a base currency. Intuitively, you want your accounting to reveal whether market changes affect you positively or negatively; when you profit and when you lose. But Economics is not Physics, one can have a constant "measure of distance", called a "meter", a "yard" or whatever, but there is no constant "measure of value". The best we have is "unit of money", but the value of that "unit" itself is constantly shifting. We may assume that for short amounts of time, widely used money are somewhat stable in value. Beware though: for a short amount of time, Germans in 1923 thought that they became very wealthy[^10]; millionaires even. Yet, soon they discovered that it was a mirage. The german mark, the base currency of their accounting, was collapsing due to the post-war printing press and the policy of inflationism.

One might think that having multiple base currencies might provide a better estimate of the "real" value of your capital (i.e. whether you can buy more or fewer goods with it). This is true to some extent. Those Germans who were quick to start accounting in terms of gold, or dollars, or any other currency in 1923, could quickly realize that they are not getting richer. But multiple base currencies may fool people in an even more insidious way. For example, let's say someone is calculating his capital in both american dollars and euros. He might even see that dollars and euros exchange at around the same ratio for months. He might draw the conclusion that both currencies are "stable" in value. The correct conclusion is that the currencies are stable compared to each other. They might be losing purchasing power at the same pace[^11], while having the appearance of stable value to the casual viewer of exchange rates!

You may have heard that governments and central banks, employing an army of PhD holders, supposedly have "solved" this problem, via index numbers (e.g. CPI, PPI, etc), which are basically the money value of a particular "basket of goods". Supposedly, all you need to do is create a basket of goods, calculate how much money it is worth at time \\(T_0\\), then repeat the exercise at time \\(T_1\\), thus measure the change of purchasing power of the currency. If the basket was worth $90 and now it is worth $100, then the dollar depreciated by 10% from \\(T_0\\) to \\(T_1\\).

This is only a mirage of a solution though; the problem is truly unsolvable. The choice of said goods is arbitrary; their relative importance in the basket is also arbitrary, and even the goods themselves are changing[^12]. Given that prices are not rigid, it should be obvious that different choices of what constitutes the "basket of goods" would paint a different picture of the "purchasing power" of money. Let alone comparing "basket of goods" of one century ago, with goods available today! How many cubicles of ice equal one refrigerator?

Even when people try to compare things that sound common between different eras, such as homes (after all, homes existed both today and a hundred years ago), remember that not only the quality of housing was vastly different, but also the location, and the amenities available in that location, are also vastly, intractably different. A car of today is not a car of a hundred years ago - not solely because of technological changes in the car itself, but because today there are a lot more roads and places to visit, a lot more gas stations, a lot more repair shops. On the negatives, today there's a lot more traffic, sure, but I doubt you would swap your car for this:

![Old buggy car](../assets/images/buggy.png)

To recap: It is critical that you keep track of your entire capital (also known as "net worth"). This capital depends to the semi-arbitrary choice of base currency. Unless that currency is highly volatile, it should offer a good enough understanding, at least in short periods of time, of whether your capital increases or diminishes, whether your income or your expenses rise faster, and so on. No matter what the choice of base currency is, capital calculations will always be deformed by changes coming from the side of the base currency itself. To stress this point: even assets of perfectly known and never changing quantity (like bitcoin) experience value flunctuations. That is true for anything else, including gold.

This doesn't mean we should do away with money based accounting, because we have no better tool to substitute for it. We should though be aware of the limitations of this tool.

You may consider this section as a long disclaimer: for the rest of the book, we will be assuming away the limitations of money accounting. We will use the base currency as constant in value (which it isn't), and will be speaking with terms like "risk-free" to indicate that your capital (in terms of the base currency) cannot diminish in certain conditions, or that you "break even" if you get back the money you gave at an earlier date (even if one could point out that the actual purchasing power of the same money diminished in that period), for the sake of simple presentation. Do keep all the aforementioned caveats in your head.

If I were to offer an advice in the otherwise arbitrary choice of base currency, it would be this: choose the currency which you mostly spend for your living expenses. This helps you compare in your mind the purchasing power of your capital, with the purchasing power of the currency which you spend; your liabilities. For example, if you notice the prices of what you need going up, while your capital lagging behind, you know there is a problem to solve - a problem worth knowing earlier than later.


## Currency Exposure vs. Transaction Currency

A very common point of confusion arises when an investor holds assets or funds denominated in a currency different from their chosen base currency. The typical reaction is to assume that buying an asset listed in a foreign currency automatically incurs "currency risk," prompting many to pay fees for "currency-hedged" products. 

To see why this is a mirage, we must look through the transaction to the underlying asset itself.

### The Law of One Price (Arbitrage)

Suppose you are in Europe and want to buy gold. You could buy an ounce of physical gold with euros. Alternatively, you could convert euros to US dollars and buy the $GLD ETF in New York. Or you could buy it through a European ETF that transacts in dollars behind the scenes, or even pay in bitcoin.

Modulo minor transaction friction, every single path yields the exact same quantity of gold. If any path yielded more gold for the same outlay, arbitrageurs would immediately exploit the discrepancy until prices aligned. There is only one objective price of gold in euros at any given moment.

The same holds for equities. Consider a company like ASML, dual-listed in Amsterdam (trading in EUR) and New York (trading in USD). A European buying ASML in New York in dollars does not suddenly take on dollar risk; an American buying ASML in Amsterdam in euros does not suddenly take on euro risk. Both investors hold the exact same fractional ownership of the identical operating enterprise. The share has no memory of the currency used to purchase it.

### Look-Through Balance Sheet Exposure

What, then, determines the true currency exposure of an asset? Not the ticker's quote currency, but the asset's underlying cash flows, balance sheet, and economic reality:

1. **Pure Cash Equivalence:** If a fund holds only physical US dollar bills and dollar-denominated short-term treasury bills, its sole underlying asset is US dollars. Even if that fund is listed on a European exchange and quoted exclusively in euros, an investor buying it holds pure USD exposure.
2. **Net Corporate Balances:** An operating business is a collection of productive capital, revenues, and debt. Its currency exposure is the net sum of those balances:
   - If a company's cash flows and assets are primarily in US dollars, holding its shares provides dollar exposure.
   - However, if a US-domiciled company holds substantial debt denominated in US dollars, but generates revenues in euros or other currencies, the company is structurally **short the dollar**. If the dollar devalues, the real burden of its debt decreases, directly benefiting the company's equity value.

In other words, going long that company's equity is economically equivalent to being short the dollar. Your true currency exposure is the look-through net currency balance of the business, not whether the stock was bought with dollars, euros, or peanuts.

### The Fiction of Commercial "Currency Hedging"

Understanding this reveals the bizarre nature of many commercial "currency-hedged" ETFs. When an institution offers a European investor a "currency-hedged" S&P 500 ETF, they promise that if the index gains $+10\%$ nominally in USD, the investor will see $+10\%$ in EUR. 

To see the flaw, imagine applying this to a country experiencing hyperinflation, such as Argentina. The Argentine MERVAL index may appreciate by $5,000\%$ in Argentine pesos over five years simply because the peso collapsed. A "currency-hedged" ETF promising the local index return would have to deliver $+5,000\%$ *in euros*. 

That return is not an investment in Argentine business productivity; it is an aggressive, leveraged short position against the foreign currency. True currency exposure comes from holding foreign currency or owning claims on entities that hold foreign currency—never from the arbitrary medium used at the point of sale.


Speculation And Hedging

Now we are able to define a couple of commonly used terms: speculation, and hedging.

By speculation, we mean any trade that increases your risk. Say, you buy 1000 barrels of oil. You stand to lose if oil price goes down. On the flip side, you stand to gain if the price goes up. Risk and profit are the two sides of the same coin.

Speculation can also be understood in a broader sense, not merely associated with trading. Any production that requires time is inherently speculation, so long the future conditions are not certain. Maybe the product to be sold will fetch profit, or it will incur losses. Even more generally, all human action that increases uncertainty is speculation. Consider a student that decides to spend years studying Computer Science. So long the study is not the end in itself (one might study merely for the direct enjoyment of doing that), then the student is effectively speculating that the market will have good demand for people with such skills, 4-5 years down the road. But what if programmers are so abundant in that time frame thus our student can't find the salary and lifestyle he was hoping in the beginning? That would be a loss.

Hedging is merely the "opposite" of speculation, similar to how subtraction is the "opposite" of addition. As speculation increases the potential of profit & loss, hedging is the act of reducing it. The trader who bought 1000 barrels of oil, might then decide to sell half of that, and that would be an act of hedging. The entrepreneur might decide to sell unfinished goods right now and get today's price for such goods, instead of finishing them in a year and selling them to the unknown future price, and that would also be hedging. The student might decide to get a job today, instead of spending years hoping for a better job tomorrow; that would also be hedging.

Sometimes we speak of speculation & hedging in a more conditional way. Let's say we own 10 shares of $ACME, each worth $100. Under the worst possible scenario (for this position, the worst case would be, $ACME going to zero), this position may result in a capital loss of $1000. Yet we may swap (trade) this position for another one, where we hold 20 shares of $ACME (still worth $100 each), but we promised to sell them at $50 each in the future, if asked to. Nominally, under the worst possible scenario (which again happens to be "$ACME goes to zero"), we have the exact same risk, $1000[^13], yet this trade would be also considered "hedging".

Turns out, the "worst case" does not capture the full range of possibilities. Having 10 shares of $ACME, bought at $100, means that if the price goes to $80, we are down $200 already. But if we had exchanged this position for the position of "20 shares, but can only sell them up to $50 each", then it would take a much larger price drop to lose as much capital, namely the price would have to drop all the way to $40. It is as if we "hedged" / removed the risk which was attached to a price range, i.e. from $100 to $50, while doubling the risk in the range of $50 to $0. Since the range of $50...$0 is less probable[^14] than the range $100...$50 given that the spot price is $100, we made loss "less probable", thus we "hedged".

The astute reader might have noticed that 20 shares with a maximum sale price of $50, is worth up to $1000, so that position has no upside at all. Indeed, the example was contrived, merely to demonstrate the equivalent max loss of the two positions. More realistically, the second position (which one could have obtained by swapping his current position of 10 shares of $ACME) would include more than 20 shares of ACME and a maximum sale price of $50. Don't worry about the details, the rest of the book tackles this.

Summarizing, we can speak of "speculation" and "hedging" (which is negative speculation) trying to communicate how we increase the potential of profit & loss depending on some (uncertain) future price. Language can go far, and suffices for simple positions, like holding a spot position. For more complex positions (involving derivatives and especially options), we need charts.

Here is a trivial PNL chart, showing the profit-or-loss outcomes if someone buys some shares of $ACME:

insert chart

And here would be another PNL chart.

insert chart of same max risk

The charts do away with "speculation" or "hedging", and simply plot the change of our capital depending on one of the prices it depends on.

Again: While we consider a cash balance (of the base currency) "risk-free" or "fully hedged" (in the sense that it can never lose value in terms of the base currency itself), never forget that owning money also involves speculation and uncertainty, as we saw in the previous section. Practically though, we will assume that the base currency has lower volatility than any other asset, thus if you swap your other assets to money, you do reduce your risk in both an accounting and in a "real goods" sense.

More on PNL Charts

Explain that any trade that has any potential for profit, means the counter party has a potential for loss. This comes from the zero-sum nature of the game, link the earlier discussion. It follows that to get a PNL chart with profit, that potential profit means there will be potential loss too, in the same PNL chart.

This also explains why ANY trade has a PNL, including trades that take place in the future!!!
Great pivot to understanding futures
.

[^10]: Adding insult to injury, even the taxman thought the same.
[^11]: For completeness sake, a stable ratio between two currencies could also imply they both gain in value at the same pace. This is almost inconceivable to happen, not under the watch of the Central Bank.
[^12]: From time to time, the central bank's economists substitute older goods for newer ones, but the exercise is a long sequence of arbitrary choices. It is important that lay men don't dispute the scientificness of this process.
[^13]: Why $1000? Because we have 20 shares which, while they are priced $100 each in the market, we promised to sell them at $50, hence that's the highest possible price for which we can sell them, and 20 * $50 = $1000.
[^14]: We have a lot more to say about probabilities later on.

