# Simulation Assumptions

# Purpose

This document defines the simulation-related assumptions used by DividendLab, focusing on how Monte Carlo structure, timestep design, random sampling, parameter estimation, and computational constraints influence the behavior and reliability of portfolio simulations. It is written as an engineering design document to make the tradeoffs between realism, stability, and performance explicit.

---

# Scope

This document covers:
- assumptions about why and how Monte Carlo path simulation is used
- assumptions about time resolution (daily vs monthly vs yearly) and timestep bias
- assumptions about random number generation, variance reduction, and reproducibility
- assumptions about parameter estimation, updating, and regime adaptation
- assumptions about computational constraints and performance vs accuracy tradeoffs

This document does NOT specify:
- the full implementation details of every simulation engine component
- the exact hardware, runtime, or scaling targets for all deployments
- portfolio construction or optimization logic (covered elsewhere)

Those details belong in methodology and architecture documents. Here we focus on what the simulation engine assumes about its own structure and numerical behavior.

---

# Core Assumptions

## Assumption: Monte Carlo Path Simulation Is Necessary for Capturing Path-Dependent and Nonlinear Effects

### Statement
The system assumes that closed-form or purely deterministic analytical models are insufficient for capturing the combination of stochastic returns, time-varying volatility, macro regimes, dividend growth, cuts, and reinvestment behavior. Monte Carlo path simulation is used as the primary tool to approximate the distribution of outcomes.

### Reasoning
Portfolio outcomes depend on sequences of returns, income, and cash flows, not just on mean and variance. Path-dependent features such as sequence-of-returns risk, cut clustering, and reinvestment timing cannot be fully characterized by closed-form formulas in realistic settings. Monte Carlo provides a flexible way to approximate outcome distributions under complex, interacting processes.[web:79][web:88]

### Supporting Theory
Monte Carlo methods rely on the law of large numbers and central limit theorem: as the number of simulated paths increases, sample estimates converge to their true expectations. In finance, Monte Carlo is widely used for pricing path-dependent derivatives and evaluating complex risk profiles where analytical solutions do not exist.[web:88]

### Empirical Evidence
Practical finance literature and industry practice show extensive use of Monte Carlo for risk analysis, derivative pricing, and portfolio stress testing. Case studies demonstrate that path-level simulation captures behaviors (e.g., drawdown timing, income variability) that are missed by simpler models.[web:79][web:85]

### Mathematical Implications
Monte Carlo estimators exhibit sampling error that decreases on the order of \( 1/\sqrt{N} \), where \( N \) is the number of simulated paths:

\[
\text{Standard Error} \propto \frac{1}{\sqrt{N}}.
\]

This means that halving the standard error requires roughly four times as many simulated paths.[web:79][web:88]

### Simulation Impact
The engine must:
- run enough paths to achieve tolerable sampling error for key outputs
- expose configuration of path counts and convergence checks

Users should interpret results as estimates with residual Monte Carlo noise, not exact values.

### Limitations
- Monte Carlo is computationally intensive, especially at high time resolution or with many risk factors.
- Rare-event probabilities can be hard to estimate accurately without variance reduction or specialized methods.

### Alternatives Considered
- Closed-form or deterministic models for all scenarios (rejected as incapable of capturing realistic path dependence).
- Pure historical bootstrapping without parametric structure (useful as a cross-check but not flexible enough for regime and policy scenario analysis).

### Related Files
- backend/simulation/monte_carlo.py
- backend/simulation/simulation_runner.py
- backend/simulation/simulation_statistics.py

---

## Assumption: Time Resolution Is Chosen to Balance Realism and Performance

### Statement
The simulation engine assumes a finite discrete timestep (e.g., monthly or daily), chosen to balance realism and computational cost. It treats returns, dividends, and macro variables as evolving on this grid, recognizing that finer timesteps reduce discretization bias but increase computational load.

### Reasoning
Continuous-time models like geometric Brownian motion are mathematically convenient, but simulations require discrete steps. Very fine timesteps can explode computational cost without meaningfully improving strategic-horizon results, while overly coarse timesteps may misrepresent volatility, path dependence, and timing of cash flows.[web:80][web:83][web:86]

### Supporting Theory
Discretization of stochastic differential equations introduces time-step error, but strong convergence results show that sufficiently small timesteps approximate continuous-time behavior well. For many portfolio planning problems, monthly or even quarterly resolution can be adequate, provided that volatility and drift parameters are adjusted consistently.[web:82][web:83]

### Empirical Evidence
Practical implementations of Monte Carlo for portfolio analysis commonly use monthly or daily timesteps. Comparisons between daily and monthly simulations often show small differences in long-horizon statistics relative to model uncertainty, particularly when focusing on distributions of multi-year outcomes rather than day-level trajectories.[web:79][web:85][web:86]

### Mathematical Implications
If an underlying process is modeled in continuous time (e.g., GBM), the discrete approximation over timestep \( \Delta t \) uses increments such as:

\[
\Delta S = S_t \left( \mu \Delta t + \sigma \sqrt{\Delta t} Z \right),
\]

where \( Z \) is a standard normal draw. Smaller \( \Delta t \) reduces discretization error but increases the number of steps per path.[web:80][web:86]

### Simulation Impact
The engine:
- uses a configurable timestep (e.g., monthly by default for long-horizon planning)
- applies parameter scaling consistent with the chosen \( \Delta t \)
- acknowledges that some short-horizon effects (e.g., exact ex-dividend dates) are approximated on the grid

### Limitations
- Coarse timesteps may understate intra-period volatility and misrepresent timing-sensitive strategies.
- Fine timesteps increase runtime and memory requirements, potentially limiting path counts.

### Alternatives Considered
- Fixed daily granularity for all use cases (rejected as too expensive for many multi-decade planning scenarios).
- Single annual timestep (rejected as too coarse for capturing sequence-of-returns risk and dividend timing).

### Related Files
- backend/simulation/time_grid.py
- backend/simulation/monte_carlo.py
- backend/simulation/cash_flow_projection.py

---

## Assumption: Random Sampling Uses Pseudorandom Generators With Optional Variance Reduction

### Statement
The system assumes that standard high-quality pseudorandom number generators are sufficient for core simulations, with optional support for variance reduction techniques (e.g., antithetic variates, control variates, quasi-random sequences) when higher precision per path is required.

### Reasoning
Modern pseudorandom generators provide good statistical properties and performance for large-scale simulations. In many portfolio planning use cases, standard Monte Carlo with a reasonably large number of paths yields adequate accuracy. However, for more demanding analyses or rare-event estimation, variance reduction can materially improve efficiency.[web:79][web:81][web:84][web:87][web:90][web:93]

### Supporting Theory
Variance reduction methods such as antithetic variates, control variates, and stratified or quasi-Monte Carlo sampling are well-established techniques for reducing the variance of Monte Carlo estimators without biasing results. Low-discrepancy sequences can improve convergence rates for some integrals.[web:81][web:84][web:87][web:90][web:93]

### Empirical Evidence
Studies and practitioner reports show that antithetic and control variates can significantly reduce standard error in financial Monte Carlo applications, effectively multiplying the value of each simulated path. Quasi-random sequences have been successfully applied to high-dimensional option pricing and risk calculations.[web:79][web:84][web:87][web:90]

### Mathematical Implications
Monte Carlo estimators with variance reduction maintain unbiasedness but have lower variance:

\[
\operatorname{Var}(\hat{\theta}_{\text{VR}}) < \operatorname{Var}(\hat{\theta}_{\text{naive}}),
\]

where \( \hat{\theta}_{\text{VR}} \) is the variance-reduced estimator. Antithetic variates, for example, simulate paired draws \( Z \) and \( -Z \) to partially cancel noise.

### Simulation Impact
The engine:
- uses seeded pseudorandom generators for reproducibility when needed
- offers configuration flags for enabling variance reduction techniques in advanced runs
- defaults to straightforward pseudorandom Monte Carlo for simplicity unless precision demands are high

### Limitations
- Implementing and tuning advanced variance reduction methods adds complexity.
- Some methods may be less effective or harder to apply in highly nonlinear or path-dependent settings.

### Alternatives Considered
- Quasi-random sequences as the default (not adopted as the base assumption to avoid surprising users and to keep core behavior simple).
- No support for variance reduction (rejected because some use cases benefit materially from these techniques).

### Related Files
- backend/simulation/random_engine.py
- backend/simulation/monte_carlo.py
- backend/simulation/variance_reduction.py

---

## Assumption: Parameters Are Calibrated From History but Updated Cautiously

### Statement
The system assumes that key parameters (e.g., drift, volatility, correlations, cut probabilities) are estimated from historical data and/or macro relationships, but are updated cautiously over time to avoid overfitting to recent noise. Regime information may inform parameter shifts, but parameters do not fully re-learn from every short window.

### Reasoning
Using historical data provides an empirical anchor for simulation parameters, but blindly fitting to recent history can lead to unstable and overfitted models. A balance is needed between responsiveness to structural changes and robustness to short-term noise. Regime classification from macro and market assumptions informs when larger parameter shifts may be warranted.

### Supporting Theory
Statistical estimation theory and Bayesian approaches highlight the tradeoff between prior beliefs and sample evidence. Rolling-window estimators can be noisy, especially for higher-moment parameters. Regime-switching models often combine long-run parameters with regime-dependent adjustments.

### Empirical Evidence
Empirical studies show that short-window volatility or correlation estimates can be extremely unstable. Portfolio models that chase recent patterns may perform poorly out of sample. More stable, smoothed parameter processes often yield more robust risk estimates.[web:79][web:85][web:91]

### Mathematical Implications
Parameter vectors \( \theta_t \) are treated as slowly evolving functions of time and regime, not as static constants or pure rolling-window estimates. In some configurations, Bayesian or shrinkage techniques may be used to pull estimates toward long-run averages unless strong evidence suggests a structural break.

### Simulation Impact
Simulations:
- use parameters that reflect a blend of long-run history and regime information
- avoid radical parameter swings from one simulation run to the next based solely on recent data

This supports more stable planning outputs and reduces the risk of overreacting to short-lived patterns.

### Limitations
- Slow parameter updating can lag real structural breaks.
- There is no single universally correct calibration window; choices embed judgment.

### Alternatives Considered
- Fully static parameters estimated from a long historical window (rejected as too rigid in the face of regime changes).
- Highly reactive short-window calibration for all parameters (rejected as too noisy and prone to overfitting).

### Related Files
- backend/simulation/parameter_generator.py
- backend/simulation/simulation_config.py
- backend/macro/regime_classifier.py

---

## Assumption: Computational Constraints Require Tradeoffs Between Path Count, Horizon, and Model Complexity

### Statement
The system assumes that computational resources are finite, so there are inherent tradeoffs between the number of paths, time resolution, horizon length, and model complexity. Not every desired level of realism can be achieved simultaneously; configurations must prioritize what matters for the use case.

### Reasoning
Monte Carlo cost grows roughly linearly with the number of paths and timesteps per path, and more complex models (e.g., many risk factors, regime-dependent parameters, jump processes) add further overhead. At some point, adding more detail or paths yields diminishing returns relative to model uncertainty and user needs.[web:79][web:91]

### Supporting Theory
Complexity and convergence results show that standard error decreases at \( 1/\sqrt{N} \), so beyond a point, increasing \( N \) yields small accuracy gains per unit of additional computation. Multilevel Monte Carlo and related techniques explicitly analyze these tradeoffs and propose ways to reduce cost for a given error tolerance.[web:91]

### Empirical Evidence
Practical implementations often cap path counts or switch to coarser timesteps for very long horizons. Benchmarks in quantitative finance show that naive attempts to simulate at extremely high resolution and path counts can become prohibitive, while more balanced configurations deliver practically useful accuracy.[web:79][web:85][web:91]

### Mathematical Implications
Let \( N \) be the number of paths and \( T \) the number of timesteps per path. Computational cost is approximately proportional to \( N \times T \) times a factor for model complexity. The system must choose \( N \), \( T \), and model structure so that cost remains within acceptable bounds.

### Simulation Impact
Configuration defaults and guidance:
- favor enough paths to stabilize key metrics rather than chasing vanishingly small Monte Carlo error
- choose timesteps appropriate for horizon and use case
- allow users to trade off between model richness (e.g., detailed regime structures, jumps) and simulation speed

### Limitations
- Performance constraints may limit the practicality of extremely detailed models or very large scenario sets.
- Users may misinterpret simulation noise as model insight if path counts are too low.

### Alternatives Considered
- Always maximizing path count and complexity without regard to runtime (rejected as impractical).
- Oversimplifying the model to ensure fast runs at the cost of unrealistic behavior (rejected for core use cases).

### Related Files
- backend/simulation/simulation_runner.py
- backend/simulation/simulation_statistics.py
- backend/simulation/performance_monitor.py

---

# Interaction With Other Assumptions

Simulation assumptions are the connective tissue between macro, market, and dividend assumptions and realized scenario paths:
- Macro and market processes define distributions and dynamics; simulation assumptions determine how those processes are discretized and sampled.
- Dividend assumptions rely on the time grid and random engine to realize growth, cuts, and reinvestment along each path.
- Parameter calibration and updating are informed by macro and market regimes but operationalized through simulation configuration and parameter generators.

Adjusting simulation assumptions (e.g., timestep, path count, variance reduction, parameter updating rules) can materially change the stability, accuracy, and interpretability of outputs without changing the underlying macro or market beliefs.

---

# Validation Considerations

To validate simulation assumptions and monitor assumption risk, the system should:
- test convergence of key metrics as path count increases (e.g., median wealth, percentile drawdowns)
- benchmark discretized simulations against known analytical or high-precision reference solutions where available
- compare results under different timesteps to assess timestep bias for key outputs
- validate variance reduction methods by confirming that they reduce standard error without introducing bias

Assumption failure signals include:
- unstable outputs that change materially when path count or timestep is modestly adjusted
- systematic bias relative to analytical benchmarks in simple test cases
- excessive runtime or resource use for marginal accuracy gains

---

# Future Improvements

Potential enhancements to simulation assumptions include:
- multilevel Monte Carlo or similar advanced techniques to reduce cost for a given error tolerance
- adaptive timestep schemes that refine resolution in high-volatility or event-heavy periods
- more sophisticated parameter-updating frameworks (e.g., fully Bayesian models with explicit uncertainty bands)
- better tooling for convergence diagnostics, scenario management, and reproducibility

---

# Glossary (Simulation Terms)

- **Monte Carlo Simulation** – A method that uses repeated random sampling to approximate expectations and distributions of complex systems.
- **Path Simulation** – Generating full time series (paths) of variables such as returns, macro factors, and dividends rather than just end-point values.
- **Timestep (\( \Delta t \))** – The discrete interval between simulation points in time (e.g., daily, monthly, yearly).
- **Discretization Error** – The error introduced by approximating continuous-time processes with discrete-time steps.
- **Pseudorandom Number Generator (PRNG)** – Algorithm that generates sequences of numbers that approximate properties of random draws.
- **Variance Reduction** – Techniques used to decrease the variance of Monte Carlo estimators without introducing bias.
- **Convergence Rate** – The speed at which a Monte Carlo estimator approaches the true value as the number of samples increases; typically proportional to \( 1/\sqrt{N} \).
- **Parameter Calibration** – The process of estimating model parameters from historical data and other information sources.
- **Multilevel Monte Carlo** – An advanced Monte Carlo technique that combines simulations at different resolutions to reduce computational cost for a target accuracy.
