# Market Assumptions

# Purpose

This document defines the market return, volatility, correlation, efficiency, and tail-risk assumptions used by DividendLab. It is written as an engineering design document to connect stylized facts about asset returns to the behavior of the simulation engine and its limitations.

---

# Scope

This document covers:
- assumptions about the distribution of asset returns over different horizons
- assumptions about volatility dynamics and clustering
- assumptions about cross-asset correlations and their instability
- assumptions about the degree of market efficiency and exploitable structure
- assumptions about tail risk, crashes, and jump behavior

This document does NOT specify:
- the exact calibration windows or datasets for parameter estimation
- the detailed estimation algorithms for volatility or correlation models
- the full implementation of risk models or optimization logic

Those details belong in methodology and validation documents. Here we focus on what the model believes about market behavior and how those beliefs shape simulations.

---

# Core Assumptions

## Assumption: Returns Are Non-Gaussian With Fat Tails and Skewness

### Statement
Asset returns are modeled as non-Gaussian, with fat tails and potential skewness, especially at higher frequencies. The system does not assume that daily or monthly returns are normally distributed, even if aggregated long-horizon returns may approximate normality.

### Reasoning
Decades of empirical research show that financial return distributions have heavier tails and more extreme moves than a Gaussian model would predict. Ignoring fat tails leads to chronic underestimation of crash risk and large drawdowns.

### Supporting Theory
Stylized facts of financial time series (e.g., work summarizing heavy tails and gain/loss asymmetry) conclude that leptokurtosis and skewness are pervasive across markets. Models such as jump-diffusion and stochastic volatility with jumps were developed precisely to better capture these features.

### Empirical Evidence
Multiple empirical studies document that daily and weekly returns exhibit excess kurtosis and fatter tails than the normal distribution, across equities, indices, and other asset classes. Extreme value analyses of equity markets reject multivariate normality in the tails and show higher-than-Gaussian frequencies of large negative returns.[web:47][web:53][web:59]

### Mathematical Implications
The model allows for return distributions with heavier tails than the Gaussian, whether through:
- parametric distributions with higher kurtosis
- jump components added to continuous diffusions
- regime-dependent volatility that increases tail probabilities

Conceptually, this relaxes the assumption that standardized returns \( r_t \) follow \( \mathcal{N}(0,1) \) and instead assumes a distribution \( F \) with higher kurtosis and possible skewness.

### Simulation Impact
Simulated return paths generate more frequent and more severe drawdowns than a Gaussian model would imply. This affects:
- tail percentiles of wealth and income outcomes
- probability of large short-horizon losses
- stress on dividend sustainability under adverse market conditions

### Limitations
- The exact choice of fat-tailed distribution or jump structure is a modeling decision and may misrepresent specific markets.
- Tail behavior is hard to estimate reliably from finite samples, especially for rare events.

### Alternatives Considered
- Purely Gaussian returns (rejected for underestimating tail risk and extreme events).
- Deterministic returns without randomness (rejected as incompatible with observed market behavior).

### Related Files
- backend/simulation/return_model.py
- backend/simulation/tail_risk_model.py

---

## Assumption: Volatility Is Time-Varying and Exhibits Clustering

### Statement
The system assumes that return volatility is time-varying, persistent, and clustered: periods of high volatility tend to follow high volatility, and periods of low volatility tend to follow low volatility. Volatility is not constant over time.

### Reasoning
Volatility clustering is one of the strongest and most robust stylized facts in financial time series. Models that assume constant volatility fail to reproduce observed return dynamics and risk patterns.

### Supporting Theory
ARCH and GARCH-type models explicitly model conditional heteroskedasticity, where conditional variance depends on past squared shocks and past variance. These models formalize volatility clustering and have become standard in financial econometrics.

### Empirical Evidence
Empirical work on financial returns shows significant autocorrelation in absolute and squared returns, while raw returns themselves show little autocorrelation. This pattern is characteristic of volatility clustering and is well documented in the econometrics literature and in practical risk modeling.[web:48][web:54][web:60]

### Mathematical Implications
Volatility dynamics can be represented via conditional variance models, for example:

$$
\sigma_t^2 = \alpha_0 + \alpha_1 \epsilon_{t-1}^2 + \beta_1 \sigma_{t-1}^2,
$$

where \( \sigma_t^2 \) is conditional variance, \( \epsilon_{t-1} \) is the prior shock, and \( \alpha_0, \alpha_1, \beta_1 \) are parameters. The simulation does not need to implement this exact equation but assumes similar behavior: shocks to returns influence future volatility.

### Simulation Impact
Simulated return paths show:
- extended periods of elevated volatility, where drawdowns and large moves are more frequent
- calmer periods with smaller day-to-day price changes

This leads to more realistic clustering of risk and better alignment with historical experience.

### Limitations
- Specific volatility models can be misspecified, particularly in extreme events or structural breaks.
- Volatility clustering parameters estimated from one market or period may not generalize perfectly.

### Alternatives Considered
- Constant-volatility models (rejected for misrepresenting risk dynamics).
- Purely regime-switching volatility without conditional dynamics (partially useful but less granular for short-horizon dynamics).

### Related Files
- backend/simulation/volatility_model.py
- backend/simulation/return_model.py

---

## Assumption: Correlations Are Unstable and Spike in Stress Periods

### Statement
Cross-asset and cross-market correlations are assumed to be time-varying and sensitive to market conditions. In particular, correlations tend to increase in stressed or bear-market environments, reducing diversification exactly when it is most needed.

### Reasoning
Empirical evidence shows that correlations across equity markets, and between many risky assets, are higher in downturns than in normal periods. Assuming static correlations or a single historical covariance matrix would overstate diversification benefits in crises.

### Supporting Theory
Extreme value theory and conditional-correlation studies show that correlations in the negative tails can be much higher than unconditional or normal-period estimates. Portfolio theory with state-dependent covariances explicitly recognizes that diversification value depends on the state of the world.

### Empirical Evidence
Studies of international equity markets document that correlation conditional on large negative returns is significantly higher than under normal conditions, while large positive returns are more consistent with constant correlation. This implies that correlations spike in bear markets rather than simply in volatile periods.[web:49][web:55][web:61]

### Mathematical Implications
The covariance matrix \( \Sigma_t \) of returns is modeled as state- or regime-dependent rather than constant:

$$
\Sigma_t = \Sigma(s_t),
$$

where \( s_t \) can reflect market regimes such as crisis, normal, or boom. Crisis states have higher off-diagonal correlations between risky assets.

### Simulation Impact
Simulated portfolios experience:
- stronger co-movements and larger portfolio drawdowns during stress regimes
- more meaningful diversification in normal regimes

This leads to more realistic behavior of portfolio risk across the cycle.

### Limitations
- Estimating tail correlations is statistically difficult because extreme events are rare.
- The simplified regime-dependent covariance structure may still understate extreme co-movements in unprecedented crises.

### Alternatives Considered
- Static historical correlation matrix (rejected for ignoring state dependence and crisis behavior).
- Simple rolling-window correlations without regime structure (useful but unstable and less interpretable).

### Related Files
- backend/simulation/correlation_model.py
- backend/simulation/return_model.py
- backend/simulation/tail_risk_model.py

---

## Assumption: Markets Are Largely Efficient but Exhibit Persistent Anomalies

### Statement
The system assumes a baseline of broad informational efficiency: prices reflect available information reasonably quickly, and persistent arbitrage opportunities are rare. However, it allows for persistent statistical anomalies (e.g., momentum, value spreads) and behavioral effects that can influence return distributions over time.

### Reasoning
The efficient market hypothesis (EMH) has substantial empirical support at a high level, but there is also robust evidence of anomalies and factors that challenge a strict interpretation. A purely efficient market assumption would ignore structure that affects long-run return distributions, while a fully inefficient view would be inconsistent with most data.

### Supporting Theory
EMH in its weak, semi-strong, and strong forms provides a benchmark that prices incorporate information quickly. Factor models and behavioral finance introduce mechanisms for persistent deviations from the pure EMH, such as slow diffusion of information, limits to arbitrage, and investor biases.

### Empirical Evidence
Classic EMH work concludes that many simple trading rules do not systematically beat the market after costs, but follow-on research documents persistent factor premiums (e.g., size, value, momentum) and anomalies that are difficult to explain solely with risk-based stories. Market efficiency is high but not absolute.[web:50][web:56]

### Mathematical Implications
The simulation engine does not assume deterministic alpha from simple rules, but it may:
- encode drift parameters that reflect historical factor premiums
- allow for return distributions that include momentum or mean-reversion tendencies at certain horizons

However, it does not hard-code guaranteed arbitrage opportunities.

### Simulation Impact
The model:
- uses efficient markets as a constraint on how extreme or persistent any assumed edge can be
- allows distributional assumptions (e.g., mean returns, cross-sectional spreads) to reflect known anomalies without guaranteeing that they are exploitable in a frictionless way

### Limitations
- The boundary between “risk premium” and “inefficiency” is blurry; attributing structure to one or the other is partly interpretive.
- Historical anomalies can weaken or disappear as they are discovered and arbitraged.

### Alternatives Considered
- Pure EMH with no anomalies allowed (rejected as inconsistent with empirical factor evidence).
- Strongly inefficient markets with large persistent arbitrages (rejected as implausible for large, liquid markets).

### Related Files
- backend/simulation/return_model.py
- backend/portfolio/factor_model.py

---

## Assumption: Tail Risk Includes Rare Jumps and Crashes Beyond Diffusive Behavior

### Statement
The system assumes that markets are subject to rare but significant jumps and crashes that cannot be adequately captured by continuous diffusive models alone. These jump events contribute materially to long-horizon risk and drawdown behavior.

### Reasoning
Historical market data include abrupt crashes and large overnight moves driven by news, policy changes, and crises. Pure geometric Brownian motion with constant volatility underestimates the frequency and severity of these jumps.

### Supporting Theory
Jump-diffusion models extend standard diffusion-based pricing models by adding Poisson-driven jump components with random sizes. Concepts like Black Swan and extreme tail risk emphasize that rare events can dominate long-run outcomes.

### Empirical Evidence
Return series exhibit discontinuities, gaps, and large moves that deviate from continuous diffusion predictions. Empirical work on option pricing and implied volatility smiles suggests that markets price in jump and crash risk beyond what a lognormal model would imply.[web:51][web:52][web:58]

### Mathematical Implications
Conceptually, prices \( S_t \) can be thought of as following a process with both diffusion and jumps:

$$
\mathrm{d}S_t = \mu S_t \, \mathrm{d}t + \sigma S_t \, \mathrm{d}W_t + S_t \, \mathrm{d}J_t,
$$

where \( J_t \) is a jump process. The implementation does not need to follow a specific jump model but assumes that the probability of large moves is higher than under pure diffusion.

### Simulation Impact
Simulated paths occasionally include large, sudden moves that create:
- deep, sharp drawdowns
- non-smooth portfolio value trajectories

This affects the distribution of worst-case outcomes and the resilience requirements for dividend and withdrawal policies.

### Limitations
- Calibrating jump frequency and size is difficult because true jumps are rare and sample sizes are small.
- Overfitting jump parameters to historical crashes may not generalize to future crises.

### Alternatives Considered
- Pure diffusion models with no jumps (rejected as inconsistent with observed crashes).
- Deterministic stress scenarios only (useful for testing but insufficient as a base stochastic assumption).

### Related Files
- backend/simulation/tail_risk_model.py
- backend/simulation/return_model.py

---

# Interaction With Other Assumptions

Market assumptions interact with macro, dividend, and simulation assumptions as follows:
- Macro regimes influence expected returns, volatility levels, and correlations, providing a macro-conditioned backdrop for market behavior.
- Dividend assumptions rely on return and volatility behavior to model payout sustainability, yield dynamics, and cut risk under stress.
- Simulation assumptions (e.g., Monte Carlo design, time step choice, random sampling) determine how non-Gaussian returns, clustering, and jumps are realized along individual paths.

Because of these interactions, changes in market assumptions can materially alter the distribution of wealth, drawdowns, and income outcomes, even if macro and dividend assumptions remain fixed.

---

# Validation Considerations

To validate market assumptions and monitor assumption risk, the system should:
- backtest simulated return distributions against empirical distributions for key indices and asset classes
- compare simulated volatility clustering and autocorrelation of squared returns to historical patterns
- evaluate simulated correlation behavior in stress regimes versus observed crisis-period correlations
- check whether simulated crash frequency and magnitude align with historical ranges

Assumption failure signals include:
- systematic underestimation of realized drawdowns relative to simulated confidence intervals
- volatility dynamics that are too smooth or too rough compared to actual markets
- correlation behavior in live data that consistently lies outside the modeled state-dependent ranges

---

# Future Improvements

Potential enhancements to market assumptions include:
- richer factor and cross-sectional return models that better capture style and sector effects
- more granular regime-dependent volatility and correlation structures
- explicit modeling of liquidity, transaction costs, and market impact
- improved jump modeling using option-implied distributions or more advanced statistical techniques

---

# Glossary (Market Terms)

- **Fat Tails** – Return distribution property where extreme outcomes occur more frequently than predicted by a normal distribution, implying higher kurtosis.
- **Leptokurtosis** – Statistical term describing distributions with higher peak and fatter tails than the normal distribution.
- **Volatility Clustering** – Tendency for high-volatility periods to follow high-volatility periods and low-volatility periods to follow low-volatility periods.
- **Conditional Heteroskedasticity** – Situation where the variance of returns depends on past information, often modeled with ARCH/GARCH.
- **Correlation Regime** – A state of the market characterized by a specific pattern of cross-asset correlations, such as elevated correlations during crises.
- **Efficient Market Hypothesis (EMH)** – The idea that prices reflect available information so that persistent arbitrage opportunities are hard to find.
- **Factor Premium** – Average excess return associated with a systematic factor such as value, size, or momentum.
- **Jump Risk** – Risk of sudden, discrete price changes that are not captured by continuous diffusion models.
- **Tail Risk** – Risk associated with extreme outcomes in the distribution of returns, typically in the far left tail for losses.
