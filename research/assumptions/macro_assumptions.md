# Macro Assumptions

# Purpose

This document defines the macroeconomic assumptions used by DividendLab, focusing on how inflation, interest rates, economic regimes, and macro correlations influence long-horizon portfolio and dividend simulations. It is written as an engineering design document to connect macro beliefs directly to implementation behavior and model limitations.

---

# Scope

This document covers:
- assumptions about inflation dynamics and their impact on real returns and dividends
- assumptions about nominal and real interest rates and yield curve behavior
- assumptions about discrete economic regimes (e.g., expansion, recession, stagflation) and their persistence
- assumptions about correlations between macro variables and asset market outcomes

This document does NOT specify:
- the exact estimation algorithms for macro parameters
- the full statistical methodology for regime classification
- the precise calibration datasets or backtest windows

Those details belong in methodology and validation documents; here we focus on what the model believes about macro behavior and how that belief shapes simulations.

---

# Core Assumptions

## Assumption: Inflation Follows Regime-Based Mean-Reverting Dynamics

### Statement
Over long horizons, inflation is modeled as a stochastic process with distinct regimes (e.g., low, moderate, and high inflation), where each regime exhibits partial mean reversion toward a regime-specific long-run level rather than a single universal global mean.

### Reasoning
Historical data show extended periods of low and stable inflation, as well as multi-year episodes of elevated inflation, often tied to structural shocks and policy shifts. A single stationary process around one fixed mean is too naive. Regime-based mean reversion captures the idea that inflation tends to drift back toward a typical level within a given policy and structural environment, but that level itself can change when regimes shift.

### Supporting Theory
Macro models with nominal rigidities and monetary policy rules (e.g., Taylor-rule frameworks) imply that central banks target an inflation range, generating mean-reverting behavior around that target. At the same time, models with supply shocks and expectations dynamics allow for persistent deviations and regime changes.

### Empirical Evidence
Empirically, long-run inflation series for developed economies display clustered regimes: post-war high-inflation periods, disinflation episodes, and extended low-inflation or near-target periods. Statistical analyses using Markov switching or structural break tests find evidence for multiple inflation regimes rather than a single, stable process.

### Mathematical Implications
Inflation is represented as a regime-dependent stochastic process with conditional mean reversion. Conceptually:

$$
\pi_{t+1} = \mu_{s_t} + \phi_{s_t} (\pi_t - \mu_{s_t}) + \epsilon_{t+1},
$$

where \( \pi_t \) is inflation, \( s_t \) is the current regime, \( \mu_{s_t} \) is the regime-specific long-run level, \( \phi_{s_t} \) is a mean-reversion parameter with magnitude less than 1 in absolute value, and \( \epsilon_{t+1} \) is a shock term.

Real returns and values are adjusted using regime-specific inflation paths:

$$
r_{real,t} \approx r_{nominal,t} - \pi_t
$$

and

$$
V_{real,t} = \frac{V_{nominal,t}}{(1 + \pi_t)^t}.
$$

### Simulation Impact
Simulated inflation paths exhibit clusters of high or low inflation rather than constant noise around a single mean. This affects:
- real portfolio value paths
- real dividend purchasing power
- interaction between inflation and interest rate regimes

Because inflation feeds directly into real return adjustments, high-inflation regimes depress real wealth paths unless nominal returns or dividend growth compensate.

### Limitations
- Real-world inflation is affected by global supply chains, fiscal policy, and unexpected shocks that may not fit a simple regime model.
- Regime identification is inherently noisy and can be mis-specified, especially in real time.
- Structural breaks (e.g., major policy regime changes) may invalidate historical regime parameters.

### Alternatives Considered
- Single-mean stationary AR(1) process for inflation (rejected as too simplistic for extended high or low inflation episodes).
- Random walk model without mean reversion (rejected because it implies unbounded drift and no long-run anchor).
- Purely deterministic inflation paths (rejected because they ignore uncertainty and shocks).

### Related Files
- backend/macro/inflation_process.py
- backend/simulation/inflation_model.py
- backend/macro/regime_classifier.py

---

## Assumption: Nominal Interest Rates Reflect Policy-Driven Cycles With Imperfect Mean Reversion

### Statement
Nominal short-term interest rates are assumed to follow policy-driven cycles characterized by episodes of tightening and easing, with imperfect mean reversion toward a policy-consistent range. Long-term rates embed expectations of future short rates plus term premia, producing a yield curve that can invert or steepen across regimes.

### Reasoning
Central banks use policy rates as their main tool for stabilizing inflation and employment, resulting in recognizable cycles of rate hikes and cuts. However, the neutral rate and policy reaction function may shift over time, so rates do not revert to a single fixed level. Long-term rates reflect expectations about future policy and risk premia rather than a static relationship.

### Supporting Theory
Term structure models (e.g., expectations hypothesis plus term premia) and New Keynesian frameworks describe how short rates respond to inflation and output gaps, and how the entire yield curve reflects future policy and risk compensation. Duration-based asset pricing links rate changes to bond and equity valuation.

### Empirical Evidence
Historical policy rates show cyclical behavior, with tightening cycles often followed by easing into downturns, and long periods where policy rates are constrained near zero. Yield curves have inverted before many recessions but not all, indicating that the relationship between the curve and macro outcomes is strong but imperfect.

### Mathematical Implications
Short rates can be modeled as a mean-reverting process around a regime-dependent neutral rate plus shocks. Conceptually, for short rate \( r_t \):

$$
r_{t+1} = \theta_{s_t} + \psi_{s_t}(r_t - \theta_{s_t}) + \eta_{t+1},
$$

where \( 	heta_{s_t} \) is a regime-dependent neutral rate, \( \psi_{s_t} \) captures mean reversion, and \( \eta_{t+1} \) is a shock term. Long rates are modeled as functions of expected future short rates and term premia.

### Simulation Impact
Interest rate paths influence:
- discounting of future dividends and cash flows
- bond and fixed-income-like asset returns
- equity valuation sensitivity via discount rate changes

Rate regimes interact with inflation regimes to determine real rate behavior, which in turn affects real return distributions for dividend-paying assets.

### Limitations
- The model abstracts from detailed term-structure modeling and may not capture all yield curve shapes.
- Policy reaction functions may change abruptly (e.g., new central bank frameworks), breaking historical relationships.
- Zero or negative lower bounds introduce nonlinear behavior that simple mean-reverting processes do not fully capture.

### Alternatives Considered
- Constant risk-free rate assumption (rejected as unrealistic over multi-decade horizons).
- Pure random walk for short rates (rejected because it ignores policy anchors and mean-reversion tendencies).
- Deterministic rate scenarios without stochastic variation (rejected for underestimating rate uncertainty).

### Related Files
- backend/macro/rate_process.py
- backend/simulation/rate_term_structure_model.py
- backend/macro/regime_classifier.py

---

## Assumption: Economic Regimes Are Discrete and Persistent but Not Permanent

### Statement
The macro environment is modeled as a set of discrete economic regimes (e.g., expansion, recession, stagflation, disinflationary slowdown) with non-zero persistence. The system assumes regimes tend to persist over multiple periods but can transition probabilistically.

### Reasoning
Historical macro data and business cycle analysis support the idea of qualitatively different states of the economy with distinct behavior for growth, inflation, unemployment, and asset returns. Treating the environment as one continuous state with small shocks misses important nonlinearities and clustering of outcomes.

### Supporting Theory
Business cycle theory and regime-switching models (e.g., Markov-switching models for GDP growth and volatility) describe economies as moving through distinct phases. Many asset pricing and risk management frameworks use regime concepts to capture differences in volatility, growth, and correlations across states.

### Empirical Evidence
Empirical recession dating (e.g., NBER in the United States) identifies expansions and contractions with typical durations and transition patterns. Studies of bull and bear markets show that return distributions and volatility differ meaningfully across these periods, consistent with regime-like behavior.

### Mathematical Implications
The macro regime is represented as a discrete latent state \( s_t \) that follows a Markov process with transition matrix \( P \):

$$
P_{ij} = \Pr(s_{t+1} = j \mid s_t = i),
$$

where diagonal elements \( P_{ii} \) are greater than 0.5 for persistent regimes, but no regime is absorbing. Conditional distributions of growth, inflation, and returns depend on the current regime.

### Simulation Impact
Simulations draw regime paths and condition macro variables and asset returns on those regimes. This produces:
- clustered volatility and drawdowns in recessionary or crisis-like regimes
- higher average returns and lower volatility in expansionary regimes
- distinct behavior in high-inflation or stagflation regimes

Regime persistence means bad environments can last long enough to materially affect long-horizon outcomes, but the system avoids assuming permanent stagnation or expansion.

### Limitations
- Real-world regimes may not be perfectly discrete; the economy can transition gradually or in mixed states.
- Regime classification is model-dependent and may be misaligned with future realities.
- The number and labels of regimes are simplifications of a complex macro environment.

### Alternatives Considered
- Single-regime models with constant parameters (rejected for underestimating tail risk and clustering of bad outcomes).
- Fully continuous state-space models without regime labels (not adopted for this version due to complexity and reduced interpretability).

### Related Files
- backend/macro/regime_classifier.py
- backend/simulation/macro_regime_model.py
- backend/simulation/return_model.py

---

## Assumption: Macro Variables and Asset Returns Exhibit Time-Varying Correlations

### Statement
The system assumes that correlations between macro indicators (inflation, unemployment, interest rates) and asset returns are time-varying and regime-dependent, with correlation structures that can strengthen or weaken across different macro states.

### Reasoning
Historical data show that relationships such as inflation vs. equity returns, rates vs. volatility, and unemployment vs. market performance are not stable. For example, equity-bond correlations have shifted sign across decades. Treating these links as fixed parameters leads to misleading diversification assumptions.

### Supporting Theory
Asset pricing models with time-varying risk premia and stochastic volatility, as well as macro-finance models, support the idea that correlations depend on underlying regimes and risk appetite. Behavioral finance also suggests that investor behavior and risk perceptions change across booms and busts, altering correlations.

### Empirical Evidence
Empirical studies document that:
- equity-bond correlations are negative in some periods (flight-to-quality behavior) and positive in others
- inflation surprises can have different effects on equities under different monetary and growth environments
- correlations across risky assets tend to spike during crises, reducing diversification benefits

### Mathematical Implications
Correlation structures are modeled as functions of the macro regime or recent macro conditions. Conceptually, the covariance matrix \( \Sigma_t \) of returns depends on \( s_t \):

$$
\Sigma_t = \Sigma(s_t),
$$

where crisis or recession regimes imply higher correlations across risky assets and stronger links between macro shocks and returns. The system may use different covariance matrices or scaling factors per regime.

### Simulation Impact
Simulated portfolios experience:
- stronger co-movements and larger drawdowns during stressed regimes
- more effective diversification in benign regimes
- changing relationships between macro shocks (e.g., inflation surprises) and asset returns over time

This prevents the model from assuming that a single historical correlation matrix will hold indefinitely.

### Limitations
- Estimating regime-dependent correlations requires substantial data and is noisy, especially for rare crisis regimes.
- Simplified correlation structures may still understate extreme co-movements during unprecedented events.
- The model does not guarantee that future correlation shifts will resemble historical ones.

### Alternatives Considered
- Static correlation matrix estimated from long-run history (rejected for ignoring regime shifts and crisis behavior).
- Rolling-window correlations without explicit regime structure (partially useful but can be unstable and hard to interpret).

### Related Files
- backend/simulation/correlation_model.py
- backend/simulation/return_model.py
- backend/simulation/tail_risk_model.py

---

# Interaction With Other Assumptions

The macro assumptions interact with market, dividend, and simulation assumptions in several ways:
- Inflation regimes feed into real return and real dividend growth assumptions, affecting purchasing power projections.
- Interest rate cycles influence discount rates, bond returns, and equity valuation sensitivity, tying into market return and volatility assumptions.
- Economic regimes condition both macro variables and return distributions, aligning with regime-based market volatility and tail-risk assumptions.
- Time-varying correlations between macro variables and returns complement assumptions about dynamic asset correlations and crisis behavior in the market assumptions document.

These interactions mean that changing macro assumptions can materially alter simulated return distributions, drawdown profiles, and income paths, even if market and dividend assumptions are held fixed.

---

# Validation Considerations

To validate macro assumptions and monitor assumption risk, the system should:
- backtest regime classification against historical recessions, expansions, and high-inflation episodes
- compare simulated inflation and rate paths to historical distributions and regime durations
- check whether simulated real returns and drawdowns under specific macro regimes align with historical ranges
- monitor the stability of estimated regime transition probabilities and correlation structures

Assumption failure signals include:
- persistent divergence between simulated macro paths and observed macro data
- correlations or regime behaviors in live or recent data that fall far outside the calibration range
- repeated misclassification of known macro episodes (e.g., recessions not recognized as such by the regime model)

---

# Future Improvements

Potential future enhancements to macro assumptions include:
- expanding the number of macro regimes or allowing for continuous state variables alongside discrete regimes
- incorporating explicit fiscal policy and global spillover effects into the macro process
- modeling nonlinear interactions between inflation, rates, and growth (e.g., at the zero lower bound)
- refining regime-dependent correlation modeling using more advanced multivariate techniques
- allowing macro parameters to adapt or re-calibrate as new data arrive, with explicit rules for when to update assumptions

---

# Glossary (Macro Terms)

- **Inflation Regime** – A period characterized by relatively stable statistical properties of inflation (e.g., low, moderate, or high), governed by similar policy and structural conditions.
- **Mean Reversion (Macro)** – The tendency for a variable such as inflation or interest rates to drift back toward a long-run level over time, rather than wandering indefinitely.
- **Neutral Rate** – The notional policy interest rate consistent with stable inflation and output at potential, used as a reference point for mean-reverting rate processes.
- **Economic Regime** – A discrete state of the macroeconomy (such as expansion, recession, or stagflation) with distinct behavior for growth, inflation, and asset returns.
- **Regime Persistence** – The tendency for a given macro regime to last multiple periods, reflected in high probabilities of remaining in the same state in the transition matrix.
- **Real Return** – The return on an asset after adjusting for inflation, approximated by nominal return minus inflation.
- **Real Value** – The inflation-adjusted value of a nominal quantity, obtained by deflating by cumulative inflation.
- **Term Structure (Yield Curve)** – The relationship between interest rates and maturities, reflecting expectations of future short rates and term premia.
- **Term Premium** – The extra yield investors demand for holding longer-maturity bonds instead of rolling over short-term instruments.
- **Correlation Structure** – The pattern of co-movements between macro variables and asset returns, which may vary across regimes.