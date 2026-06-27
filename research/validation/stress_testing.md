# Portfolio Stress Testing Methodology

***

## 1. Purpose

This document defines DividendLab’s framework for portfolio stress testing: how portfolios are evaluated under extreme but plausible market, income, and macro conditions. 
It covers historical crash analysis, dividend cuts, inflation shocks, interest‑rate moves, and recession environments, and specifies how these scenarios are constructed, applied, and interpreted across versions.  

Used In:  
- V1 (basic historical and deterministic shocks)  
- V2 (probabilistic simulation stress overlays)  
- V3–V4 (scenario and regime‑based stress testing)  

Dependent Systems:  
- Portfolio Engine  
- Simulation Engine / Monte Carlo (`monte_carlo.md`)  
- Model validation framework (`model_validation.md`)  

Goal:  
Develop portfolio stress testing methodologies that complement core forecasting models and expose tail risks and fragility that normal projections may hide. 

***

## 2. Executive Summary

Stress testing asks a simple question: *“What happens to this portfolio if things go very wrong?”*  
Instead of relying solely on average returns or Monte Carlo under “normal” assumptions, DividendLab applies structured stress scenarios that mimic historical crashes, dividend cuts, inflationary spikes, rate shocks, and recessions, and then measures portfolio behavior under those conditions. 

High level:

- V1: apply deterministic and historical scenario overlays (e.g., replay 2008‑style drawdowns, apply uniform dividend cuts, ramp inflation) to the portfolio engine.  
- V2–V3: integrate stress scenarios into the Monte Carlo engine, generating distributions **conditioned** on stress environments rather than just baseline assumptions.  
- V4: link stress testing to macro‑regime modeling, so scenarios are tied to economic states rather than arbitrary shocks.  

Strengths: exposes vulnerabilities, sequence risk, concentration risk, and income fragility in ways users can understand.  
Weaknesses: scenarios are ultimately assumptions; extreme events can always exceed what is modeled, and mapping history onto future portfolios is imperfect.

***

## 3. Definitions

Key terms:

- **Stress Test**  
  A deliberate application of extreme but plausible shocks to asset prices, dividends, inflation, or rates to evaluate portfolio resilience.

- **Historical Crash Scenario**  
  A stress test that replays a past crisis (e.g., global financial crisis) using historical return sequences and dividend behavior.

- **Dividend Cut Scenario**  
  A scenario where dividends are reduced or suspended according to specified rules (e.g., sector‑wide 50% cuts).

- **Inflation Shock**  
  A sudden and/or persistent increase in inflation assumptions that erodes real returns and income purchasing power.

- **Interest‑Rate Shock**  
  A rapid change in rate levels (up or down) affecting bond prices, discount rates, and income assets.

- **Recession Environment**  
  A composite scenario involving lower growth, higher unemployment, reduced earnings, dividend pressure, and possible equity drawdowns.

- **Stress Path**  
  A simulated or replayed portfolio trajectory under a specific stress scenario.

- **Resilience Metrics**  
  Quantitative measures under stress (e.g., peak‑to‑trough drawdown, income retention, time to recovery, shortfall probabilities).

Each term should be used consistently across stress testing, Monte Carlo, and macro‑regime docs.

***

## 4. Core Concepts

### 4.1 Scenario‑Based Risk Assessment

Description:  
Stress testing evaluates portfolios under predefined scenarios rather than relying solely on baseline stochastic models.  

Purpose:  
Reveal vulnerabilities that may not appear in average or median forecasts, especially under clustered negative events.  

Implementation Notes:  
Scenarios are defined as transformations to return paths, dividends, inflation, or rates applied to the portfolio engine.

### 4.2 Historical vs Hypothetical Scenarios

Description:  
- Historical: replay specific past episodes (e.g., 2000–2002, 2008–2009, 2020 crash).  
- Hypothetical: construct stylized shocks (e.g., “equities −40% in year 1, dividends −60% for 3 years, inflation +5%”).  

Purpose:  
Combine realism (history) with targeted exploration of risks not fully captured by history.  

Implementation Notes:  
Historical scenarios require clean data alignment; hypothetical scenarios require transparent parameter choices.

### 4.3 Sequence Risk and Recovery

Description:  
Stress tests emphasize the *order* of returns and income shocks and the time required for the portfolio to recover, not just the eventual outcome.  

Purpose:  
Show how early‑life crashes, dividend cuts, or inflation spikes can permanently damage retirement plans or income streams.  

Implementation Notes:  
Key metrics: maximum drawdown, recovery time, minimum income level, probability of breaching thresholds.

***

## 5. Mathematical Foundation

Stress testing itself is more about scenario design than new math, but several quantitative definitions are core.

### 5.1 Drawdown Under Stress

Equation Name: Maximum Stress Drawdown  

Formula:  
\[
\text{MaxDD}_{\text{stress}} = \max_{t} \left( \frac{V_{\text{peak, stress}} - V_{t,\text{stress}}}{V_{\text{peak, stress}}} \right)
\]    

Purpose:  
Measure worst peak‑to‑trough loss in the stress path.  

Interpretation:  
Higher values indicate more severe capital loss under the scenario.  

Assumptions:  
Uses portfolio value series from stress scenario; assumes accurate valuation.

### 5.2 Income Retention Ratio

Equation Name: Income Retention Under Stress  

Formula:  
\[
\text{IRR}_{\text{stress}} = \frac{\sum_{t=1}^T I_{t,\text{stress}}}{\sum_{t=1}^T I_{t,\text{baseline}}}
\]  

Where \(I_{t,\text{stress}}\) is income under stress and \(I_{t,\text{baseline}}\) is income under baseline assumptions.  

Purpose:  
Quantify how much income survives relative to baseline.  

Interpretation:  
Values significantly below 1 indicate substantial income damage.

### 5.3 Shortfall Under Stress

Equation Name: Stress Shortfall Probability  

Formula (conceptual):  
\[
\mathbb{P}_{\text{stress}}(V_{t} < V_{\text{target}}) \quad \text{or} \quad \mathbb{P}_{\text{stress}}(I_{t} < I_{\text{target}})
\]  

Purpose:  
Measure likelihood of breaching wealth/income thresholds under scenarios when stress is integrated with Monte Carlo.  

Implementation Considerations:  
Requires scenario‑conditioned simulations (V2+).

Assumptions, limitations, and implementation notes should be documented per metric (e.g., dependence on scenario design, Monte Carlo sampling error).

***

## 6. Industry Standard Approaches

We summarize how stress testing is typically done in institutional and portfolio management contexts. 

For each methodology include description, advantages, disadvantages, complexity, use cases, adoption, and suitability:

- **Historical Scenario Analysis**  
  - Description: replay past crises on current portfolios.  
  - Advantages: intuitive, grounded in reality.  
  - Disadvantages: depends on history; may miss novel risks.  
  - Adoption: widely used in banks, asset managers.  
  - Suitability: core for V1 and V2.

- **Hypothetical Shocks (Single‑Factor and Multi‑Factor)**  
  - Description: apply user‑defined shocks to equity prices, credit spreads, rates, inflation, currencies.  
  - Advantages: flexible; can explore “what if” beyond history.  
  - Disadvantages: subjective; requires careful parameter selection.  
  - Suitability: important for V2–V3.

- **Regime‑Based Stress Testing**  
  - Description: define economic regimes (recession, high inflation, crisis) and simulate portfolios under those states.  
  - Advantages: connects macro conditions to portfolio outcomes.  
  - Disadvantages: requires regime classification and macro modeling.  
  - Suitability: V3–V4 and beyond.

- **Reverse Stress Testing**  
  - Description: start from failure conditions (e.g., portfolio value < X) and infer scenarios that cause them.  
  - Advantages: highlights combinations of shocks that can break plans.  
  - Disadvantages: more complex to implement and explain.  
  - Suitability: long‑term research.

***

## 7. Candidate DividendLab Approaches

We list concrete stress testing designs for DividendLab and assign recommended versions. 

### Approach A: Historical Crash Replay (V1–V2)

- Description: apply sequences of historical returns and dividend behavior from known crises (e.g., dot‑com bust, GFC, COVID crash) to user portfolios.  
- Advantages: highly intuitive; uses real data.  
- Disadvantages: dependent on asset mapping and history quality; history may under‑ or over‑represent future risk.  
- Data Requirements: long historical price/dividend series for relevant indexes and sectors.  
- Computational Requirements: low.  
- Implementation Difficulty: low‑medium.  
- Recommended Version: V1 basic implementation; V2 with tighter integration to Monte Carlo.

### Approach B: Stylized Dividend Cut and Income Shock Scenarios (V1–V2)

- Description: apply uniform or sector‑specific cuts to dividends for defined periods (e.g., “50% cut for 2 years,” “suspension for 1 year”).  
- Advantages: directly tests income fragility; simple to explain.  
- Disadvantages: stylized; may not match actual corporate behavior.  
- Recommended Version: V1–V2.

### Approach C: Multi‑Factor Hypothetical Shock Library (V2–V3)

- Description: define scenarios combining price crashes, dividend cuts, inflation spikes, and rate shocks.  
- Advantages: more realistic composite stress; flexible scenario design.  
- Disadvantages: more complex; requires careful communication.  
- Recommended Version: V2–V3.

### Approach D: Regime‑Linked Stress Testing (V3–V4)

- Description: attach stress tests to macro regimes (from V4 macro‑regime modeling), e.g., “deep recession regime,” “high inflation regime.”  
- Recommended Version: V3–V4.

***

## 8. Proposed DividendLab Methodology

This section defines the stress testing methodology currently planned for implementation in near versions.

### Description

DividendLab will implement a scenario library combining:

- Historical crash scenarios (replay of major drawdowns).  
- Dividend cut/suspension scenarios.  
- Inflation and rate shock scenarios.  

These scenarios will be applied to user portfolios through the portfolio engine, and increasingly integrated with Monte Carlo simulations to generate distributions conditional on stress environments. 

### Inputs

- User portfolio composition, contributions, withdrawals, and baseline assumptions.  
- Historical return and dividend data for chosen stress periods.  
- Parameter sets describing hypothetical shocks (percentage cuts, inflation rates, etc.).

### Outputs

- Stress paths of wealth and income.  
- Stress metrics: maximum drawdown, time to recovery, income retention, shortfall probabilities (in V2+).  
- Comparative views: baseline vs each stress scenario.

### Workflow

1. Define scenario set (historical episodes and hypothetical shock templates).  
2. For a chosen scenario, transform asset returns, dividends, inflation, or rates according to scenario rules.  
3. Run the portfolio engine (and, if applicable, Monte Carlo) using stressed inputs.  
4. Compute stress metrics and compare to baseline outcomes.  
5. Present results in a way users can understand (e.g., “In this crash, your portfolio’s income drops 40% and takes 5 years to recover”).

### Dependencies

- Portfolio engine (`portfolio_theory.md` assumptions and mechanics).  
- Monte Carlo engine for scenario‑conditioned distributions (V2+).  
- Model validation framework for evaluating scenario realism and consistency (`model_validation.md`). 

### Assumptions

- Historical episodes are reasonably representative of potential stress environments.  
- Hypothetical shocks are defined in a way that is internally consistent and transparent.  

### Risks

- Users misinterpret stress scenarios as forecasts rather than “what if” cases.  
- Poorly chosen scenarios that either understate or overstate risk.  

### Reason for Selection

This methodology balances realism (history) and flexibility (hypothetical shocks), is implementable in V1–V2, and scales naturally into macro‑regime modeling in later versions. 

***

## 9. Data Requirements

For each dataset we document provider, coverage, frequency, availability, reliability, cost, fields used, purpose, and potential issues. 

Key datasets:

- **Historical Market Data for Crashes**  
  - Coverage: major indexes, sectors, and asset classes across known crisis periods.  
  - Frequency: daily/monthly.  
  - Fields: prices, total returns, dividends.  
  - Purpose: replay crash scenarios.

- **Macro and Inflation Data**  
  - Fields: CPI, interest rates, economic indicators (for later macro‑linked scenarios).  
  - Purpose: define inflation and rate shock scenarios; eventually regime modeling.

Potential issues:

- Survivorship bias.  
- Incomplete dividend history during crises.  
- Differences between indexes used for stress and user portfolios.

***

## 10. Edge Cases

We document situations where stress testing may fail or mislead. 

Examples:

- **Portfolios with Assets Lacking Historical Analogs**  
  - Impact: mapping stress scenarios becomes hand‑wavy.  
  - Mitigation: use proxies; flag limitations to users.

- **Extreme Concentration**  
  - Impact: stress scenarios may understate or overstate risk depending on mapping of single names to index/sector shocks.  
  - Mitigation: explicit concentration metrics and warnings.

- **Structural Economic Shifts**  
  - Impact: past crises may not reflect future risk (e.g., new monetary regimes).  
  - Mitigation: broader scenario design; conservative assumptions.

- **Liquidity Crises**  
  - Impact: real‑world execution constraints not fully captured by price‑only scenarios.  
  - Mitigation: note limitations clearly; consider future modeling of liquidity and trading constraints.

***

## 11. Validation Strategy

Stress testing is itself a methodology and must be validated. 

### Validation Goals

- Ensure scenarios are internally consistent (no impossible combinations of shocks).  
- Confirm that historical scenarios correctly reproduce known index behavior.  
- Check that stress metrics are computed consistently and robustly.

### Metrics

- Scenario realism checks (e.g., does replay of 2008 reproduce known index drawdowns?).  
- Sensitivity analysis of stress results to scenario parameters.  
- Stability of stress metrics across similar scenarios.

### Backtesting Approach

- Historical replay: verify that applying historical scenarios to benchmark portfolios reproduces known behaviors.  
- Cross‑scenario comparison: check that “stronger” scenarios produce systematically worse metrics than “milder” ones.

### Benchmark Models

- Baseline portfolios with known stress behavior (e.g., 60/40).  
- Simple rule‑based scenarios for comparison.

### Success Criteria

- Historical scenarios closely match known index paths.  
- Stress metrics respond monotonically as scenarios intensify.  

### Failure Criteria

- Inconsistent or implausible scenario combinations.  
- Stress results that do not scale with scenario severity.

***

## 12. Limitations

We explicitly document weaknesses of the stress testing framework. 

- Reliance on limited historical crises; future events may be different.  
- Subjectivity in hypothetical shock design.  
- Lack of full liquidity, behavioral, or second‑order effects (e.g., forced selling).  
- Risk of users over‑ or under‑reacting to stress outputs.

***

## 13. Future Improvements

Organized by version and long‑term research. 

- **V2**  
  - Integrate stress scenarios directly into Monte Carlo simulations (scenario‑conditioned distributions).  
  - Add more refined income‑focused stress metrics.

- **V3**  
  - Link stress testing to scenario library (bull/bear, high inflation, recession).  
  - Introduce sequence‑focused stress metrics (e.g., early‑life crash impact on retirement plans).

- **V4**  
  - Fully integrate macro‑regime modeling into stress testing; build regime‑triggered scenarios.

- **Long‑Term Research**  
  - Reverse stress testing (derive shocks from failure conditions).  
  - Machine‑learning‑assisted scenario classification and analog selection.  

***

## 14. References

To be populated as you implement:

- **Books**  
  - Title, author, year, relevance to portfolio stress testing and risk management.

- **Papers**  
  - Academic and practitioner work on scenario analysis, stress testing, and crisis behavior.

- **Datasets**  
  - Market and macro data sources used for historical and hypothetical scenarios.

- **Documentation**  
  - References for libraries and tools used to implement stress tests.

***

This gives you a complete skeleton and substantive content for `stress_testing.md` that matches your research standard and version roadmap. Which section here feels weakest or least aligned with how you actually want to stress portfolios—scenario design, metrics, or validation? 