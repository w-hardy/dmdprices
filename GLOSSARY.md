# dmdprices

The language of costing a clinical dose from NHS dm+d medicine prices: which
products can make up a dose, how a dose is delivered, and which cost a caller
receives.

## Products

**AMPP**:
Actual Medicinal Product Pack: one supplier's pack of a product, with its pack size and price.
_Source_: NHS Dictionary of Medicines and Devices (dm+d), NHSBSA; the expansion is the dm+d's, the one-line definition is paraphrased and not yet checked against the dm+d data model (2026-10-31)
_Avoid_: Pack (unqualified), SKU

**Candidate**:
A priced AMPP that a query matched and that is eligible for dose costing.
_Source_: project definition
_Avoid_: Match, product (unqualified)

**Preparation group**:
The candidates that share one dose form, release modifier and route; a dose is made up from one group's products only, never across groups.
_Source_: project definition
_Avoid_: Preparation (unqualified), formulation, group (unqualified)

**Preparation label**:
The readable name of a preparation group; meant to name one group, though that is not guaranteed (open: #43).
_Source_: project definition
_Avoid_: Preparation name, form label

## Dose

**Requested dose**:
The dose the caller asks for; it is never rounded, and no result delivers less than it.
_Source_: project definition
_Avoid_: Target dose, grid dose

**Exact dose**:
A combination that delivers the requested dose to within a negligible tolerance.
_Source_: project definition
_Avoid_: On-grid dose

**Over-delivery**:
The surplus a combination delivers above the requested dose.
_Source_: project definition
_Avoid_: Overshoot, excess, wastage

**Over-delivery policy**:
The caller's rule for combinations that deliver more than the requested dose: forbid them, minimise the surplus, or allow them.
_Source_: project definition
_Avoid_: Over-delivery (when the rule is meant)

## Cost

**Returned cost**:
The number a costing function hands back for one dose; for a cost range, each of its two bounds.
_Source_: project definition
_Avoid_: Result, best cost

**Supplying group**:
A preparation group whose combination reaches the returned cost.
_Source_: project definition
_Avoid_: Winning group, cheapest group (when a tie or a maximum is possible)
