# Assumptions

This folder documents the financial, economic, statistical, and computational assumptions used throughout DividendLab. These assumption files are written in an engineering design–doc style so that another developer or researcher can see what the model believes about reality, how those beliefs connect to implementation, and where the main limitations and tradeoffs lie. [file:1]

These assumptions influence:
- simulation realism
- return and drawdown distributions
- volatility behavior and correlation structure
- dividend projections and income stability
- macroeconomic regime behavior
- portfolio evolution and sequence-of-returns risk

Each assumptions file follows a shared structure (Purpose, Scope, Core Assumptions, Interaction With Other Assumptions, Validation Considerations, Future Improvements, References, and a local Glossary). This consistency makes it easier to trace any piece of simulation behavior back to the underlying modeling choices. [file:1]

---

# Sections

## macro_assumptions.md

Economic and macro-regime assumptions. Describes how inflation, interest rates, recessions, and macro regimes are modeled, including regime-dependent mean reversion, real vs nominal relationships, and how macro states set the backdrop for returns and dividends. [file:1]

## market_assumptions.md

Asset return and market-structure assumptions. Covers non-Gaussian return distributions, volatility clustering, time-varying correlations (especially in stress), the baseline view on market efficiency vs anomalies, and explicit tail-risk/jump behavior. [file:1]

## dividend_assumptions.md

Dividend growth and payout assumptions. Defines how dividend growth, reinvestment (DRIP), cuts and suspensions, yield traps, and simplified tax/timing rules are modeled and how they feed into income and total-return projections. [file:1]

## simulation_assumptions.md

Computational and stochastic simulation assumptions. Explains why Monte Carlo path simulation is used, how timesteps are chosen, how random sampling and variance reduction work, how parameters are calibrated and updated, and what tradeoffs are made between realism, stability, and performance. [file:1]

---

# Reading Order

Recommended reading order: [file:1]

1. **market_assumptions.md** – understand how returns, volatility, correlations, and tail risk are treated.
2. **dividend_assumptions.md** – see how dividend growth, reinvestment, and cuts sit on top of market behavior.
3. **macro_assumptions.md** – add the macro regime layer that conditions both markets and dividends.
4. **simulation_assumptions.md** – see how all of the above are discretized, sampled, and calibrated in the Monte Carlo engine.

This order moves from asset-level behavior, to income and payouts, to macro context, and finally to the simulation machinery that ties everything together. [file:1]

---

# How Assumptions Affect Simulation Outputs

Across the four files, assumptions determine:
- the shape of return and income distributions (fat tails, clustering, jumps, cut clustering)
- how sensitive results are to macro regimes (e.g., inflation and rate environments)
- how robust dividend income is under stress (cuts, yield traps, reinvestment behavior)
- how much Monte Carlo sampling error and timestep bias remain in reported metrics

Changing an assumption in one file can materially affect outputs even if everything else is held constant (for example, tightening tail-risk assumptions in `market_assumptions.md` changes the frequency of deep drawdowns, which then affects dividend sustainability and withdrawal risk). Each file includes its own Validation Considerations section describing how that assumption set should be tested and monitored in practice. [file:1]

---

# Related Sections

The assumptions folder is meant to be read alongside: [file:1]

- `../methodology/` – documents how the model is implemented (algorithms, estimators, numerical schemes) using these assumptions as inputs.
- `../validation/` – documents how the assumptions and implementation are tested against data and stress scenarios, and how assumption failures are detected.

When changing assumptions, updates should be coordinated with the relevant methodology and validation documents so that reasoning, implementation, and tests remain aligned. [file:1]