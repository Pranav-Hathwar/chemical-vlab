# MFR Solver — Test-Case Verification

Verification of `mfr_lab/lib/utils/mfr_solver.dart` against the teacher's Excel
test cases. **Result: the solver is correct — every value matches and no fix was
required.**

## Equations used by the solver (confirmed correct)

Reaction `A + B → C`, second order, rate `(−rA) = k·CA·CB`, in a steady-state
Mixed-Flow Reactor (CSTR).

| Quantity | Formula |
|---|---|
| Total flow | `vT = vA + vB` |
| Mixed inlet A | `CA0 = CA0′ · vA / vT` |
| Mixed inlet B | `CB0 = CB0′ · vB / vT` |
| Space time | `τ = VR / vT` |
| Ratio | `m = CB0 / CA0` |
| Design eq. (solved for XA by Newton–Raphson) | `k·CA0·τ·(1−XA)(m−XA) = XA` |
| Exit A | `CA = CA0·(1−XA)` |
| Exit B | `CB = CB0 − CA0·XA` |
| Rate group | `CACB = CA·CB` |
| Rate | `rA = CA0·XA / τ` |
| Recovered k | `kPerTrial = rA / CACB` |
| Graph Y | `Y = XA / [CA0·(1−XA)(m−XA)] = k·τ` |

Derivation check of the design equation from the CSTR mass balance:
`τ = CA0·XA / (−rA)` with `−rA = k·CA·CB = k·CA0(1−XA)·CA0(m−XA)`
⇒ `τ = XA / [k·CA0·(1−XA)(m−XA)]` ⇒ `k·CA0·τ·(1−XA)(m−XA) = XA`. ✓

## Method

The **actual `MFRSolver`** was run (pure Dart, `dart run`) with `k = 0.2816`
(the slope of the teacher's `ra` vs `ca·cb` chart) for all three rows. Outputs
were compared to the Excel values. Tolerance 5×10⁻⁴ (the Excel values are
rounded to 4 decimals).

## Results — all PASS

`got` = solver output, `exp` = Excel value, `d` = absolute difference.

### Row 1 — va=1, vb=1.2, ca01=1, cb01=1.1, VR=5
| field | got | exp | d |
|---|---|---|---|
| tau   | 2.272727 | 2.272727 | 2.7e-7 |
| ca0   | 0.454545 | 0.454545 | 4.6e-7 |
| cb0   | 0.600000 | 0.600000 | 0 |
| m     | 1.320000 | 1.320000 | 0 |
| ca    | 0.345816 | 0.3458   | 1.6e-5 |
| xa    | 0.239204 | 0.23924  | 3.6e-5 |
| cb    | 0.491271 | 0.491255 | 1.6e-5 |
| cacab | 0.169889 | 0.169876 | 1.3e-5 |
| ra    | 0.047841 | 0.047848 | 7.1e-6 |

### Row 2 — va=0.8, vb=1, ca01=1, cb01=1.1, VR=5
| field | got | exp | d |
|---|---|---|---|
| tau   | 2.777778 | 2.777778 | 2.2e-7 |
| ca0   | 0.444444 | 0.444444 | 4.4e-7 |
| cb0   | 0.611111 | 0.611111 | 1.1e-7 |
| m     | 1.375000 | 1.375000 | 0 |
| ca    | 0.321609 | 0.3216   | 9.1e-6 |
| xa    | 0.276380 | 0.2764   | 2.0e-5 |
| cb    | 0.488276 | 0.488267 | 8.7e-6 |
| cacab | 0.157034 | 0.157027 | 6.9e-6 |
| ra    | 0.044221 | 0.044224 | 3.3e-6 |

### Row 3 — va=0.5, vb=0.8, ca01=1, cb01=1.1, VR=5
| field | got | exp | d |
|---|---|---|---|
| tau   | 3.846154 | 3.846154 | 1.5e-7 |
| ca0   | 0.384615 | 0.384615 | 3.8e-7 |
| cb0   | 0.676923 | 0.676923 | 7.7e-8 |
| m     | 1.760000 | 1.760000 | ~0 |
| ca    | 0.243395 | 0.2434   | 4.5e-6 |
| xa    | 0.367172 | 0.36716  | 1.2e-5 |
| cb    | 0.535703 | 0.535708 | 4.9e-6 |
| cacab | 0.130388 | 0.130391 | 3.3e-6 |
| ra    | 0.036717 | 0.036716 | 1.2e-6 |

All 27 comparisons PASS; max difference 3.6×10⁻⁵ (pure rounding in the 4-decimal
Excel values).

## Chart / slope (k) check

The teacher's chart plots `ra` (y) vs `ca·cb` (x); the trendline is `y = 0.2816x`.
Because `−rA = k·CA·CB` exactly, the slope of `ra` vs `ca·cb` **is** the rate
constant `k`. Recovering k from the solver outputs three independent ways gives
the same value for every row:

| Row | `ra/(ca·cb)` | `Y/τ` (app's chart slope) | `kPerTrial` |
|---|---|---|---|
| 1 | 0.281600 | 0.281600 | 0.281600 |
| 2 | 0.281600 | 0.281600 | 0.281600 |
| 3 | 0.281600 | 0.281600 | 0.281600 |

So **k = 0.2816 L/(mol·min)** is correct and consistent across all rows, and the
trendline slope is physically the rate constant, as expected. (Note: the app's
own graph plots `Y = XA/[CA0(1−XA)(m−XA)]` vs `τ`, whose slope is also k — an
equivalent linearization that yields the same 0.2816.)

## Conclusion

| Item | Status |
|---|---|
| Mixing/τ/m formulas | ✅ correct |
| CSTR design equation + Newton–Raphson | ✅ correct |
| ca, xa, cb, cacab, ra | ✅ match Excel |
| Chart slope = k = 0.2816 | ✅ correct |
| **Changes needed to `mfr_solver.dart`** | **None** |
