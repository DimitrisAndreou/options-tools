---
layout: default
title: Options Lab Documentation
favicon: /options-tools/favicon.jpg
---

# Options Lab: Visualizing Strategy _Families_!

> [!NOTE]
> This project is fully open-source. You can explore the codebase, file issues, or contribute on GitHub:
> [DimitrisAndreou/options-tools](https://github.com/DimitrisAndreou/options-tools)
>
> Contact me on X: [@optionakias](https://x.com/optionakias).

Welcome to **Options Lab**, a free visualization tool designed to help you understand
the options market in a way that cannot be found anywhere else!

The primary focus of the tool is helping you understand _covered calls_, which is
the most quintessential options strategy relevant to virtually _everyone_ (see below).

Other strategies are also included and offered in the same spirit of the "entire market at a glance" concept.

## A note on terminology

Options lingo is bad. Due to the Put-Call parity, there are always multiple
equivalent ways of implementing a strategy, e.g. "covered call" versus "short put".
The lingo makes it hard to generalize and talk about the entire family of these
equivalent strategies. We need to pick a name, hence "covered calls" it is, but
please be aware that it's the same elephant, no matter where you are looking at it from.

## How to use

Pick a ticker symbol (stocks, ETFs, indexes, etc.) by entering its ticker symbol.
Optionally restrict the range of expirations. One can also tailor the slippage: a slippage of `0.5` means that
we calculate prices as if we can fill orders at exactly the middle of the bid-ask
spread. A slippage of `1.0` means we buy or sell at the worst side of the bid-ask spread (where you can expect an instant market fill). A slippage of `0.0` (i.e. no slippage) means we buy or sell at the best side of that spread (which is not realistic in live execution, of course).

Hit "Load Data", and wait for options data to be fetched.

## Data Sources

BTC/ETH/SOL options come from Deribit (available 24/7).
Anything else is fetched from Yahoo Finance, which supports options for American stocks/ETFs. Yahoo Finance data works best **~30 minutes after market open** (approx. 10:00 AM Eastern Time).

> [!NOTE]
> The Yahoo Finance integration is currently only compatible with Google Chrome.


## Loading Data

If all goes well, you should see a chart of all possible Covered Calls for the underlying
you picked. There is a dropdown selection menu to choose different strategies. In each case, instances
of each strategy family appear as points. Each such point marks a particular position
that you could open.

You can hover over each point to get a summary tooltip. You can also click a point,
which locks it and reveals a detailed view of the strategy in the Strategy Details pane.

The details pane also offers links so you can explore further. For stocks, if you click on the
name of the strategy (in Strategy Details), you are taken to the same strategy
directly on [optionstrat.com](https://optionstrat.com) to visualize it!

## Strategies

### Covered Calls

There are many ways of describing a covered call. The simplest seems to be this:
A covered call defines two possible outcomes (depending on whether, at expiration,
the price of the underlying is above or below the strike):

- Either you will get a +X% of extra money, e.g. dollars (compared to the dollar amount
of your original capital), or
- You will get a +Y% of _extra underlying_, e.g. extra shares (compared to your
original capital expressed in units of the underlying at the time you opened the position).

Those +X% and +Y% define the X and Y axes respectively!

Thus the chart instantly visualizes the trade-off between the two. So, if you find a
covered call for which, for the amount of time involved (until expiration),
_you are happy with both outcomes_, then you can just go ahead and open that position.
It is guaranteed that you will end up with one of the two outcomes, and you like both!

Remember: you don't get to choose which of the two outcomes you get. You will actually
get the _worst_ of the two (in terms of money value). That's why it is important that you
are comfortable with _either_ of them before opening such a position.

Covered calls come in all varieties:
- from very short term (found near the origin point, bottom-left)
- to very long term (found far away from the origin point)
- from very "safe" (towards the top-left), nearly identical to synthetic bonds
- to very "risky" (towards the bottom-right), nearly identical to just holding the underlying asset

There is surely something for everyone. Theta Gang delight!

### Long Options (Calls / Puts)

Opposite to Theta Gang stands the WallStreetBets side of the market. Here you can browse
all long options (calls and puts), and see what leverage each one provides, but also what
price move the option needs, to achieve that leverage and not expire worthless.

How do long options provide leverage? Consider a long call, for a stock that costs $100.
Let's say the call is priced $10 (per share). If the option comes ITM, i.e. if the
underlying's price exceeds (at expiration) the strike price, then that $10 call will be
equivalent to a full share. (For a typical lot of "100 shares per option", the call price would be $1000, which is equivalent to 10 shares, and at expiration it would be equivalent to 100 shares, thus 10x the shares you were originally able to buy with your starting capital.)

## Options for everyone

I would much prefer to refer to the "covered calls" strategy as "the basic options strategy", because it really is the most basic strategy, relevant to virtually **all** investors.

You might have heard that most investors should stay away from options. I disagree!

Let's examine covered calls via this tool and see why they matter.
Virtually all investors have "long" positions, and also have some cash balances.

The essence of covered calls, or of the "basic options strategy", is defined by two
extremes: pure cash (via a very deep ITM call), or rather, a synthetic _bond_ (i.e. 
cash plus the risk-free interest rate), or pure long (via a very far OTM call).

So, this strategy takes the two extremes that everyone is familiar with (because they
are the easiest / most accessible cases), and offers a smooth gradient of choices
between the two. It's no longer a binary "this or that", but how far you want to be on each of the extremes.

These intermediate choices are also not the same as, "oh let's do 60% allocation
in the stock, and let's keep the remaining 40% as cash-equivalent". That combination
would be equivalent to _two_ covered calls, one simulating the stock allocation,
one simulating the cash allocation. The intermediate choices offered by covered calls
are allocating _the entire capital_ in a single strategy. 
