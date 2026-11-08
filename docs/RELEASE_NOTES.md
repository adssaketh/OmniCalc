# Release notes

## 1.2.0 (Flutter rewrite, phase 8c)

New
- SETUP: Decimal point (Disp) dot or comma for results, and Display contrast (CONT 1-5).
- Recurring-decimal input: SHIFT on the `×10ˣ` key (`0.ṅ`), COMP mode, periods up to 14 digits.
- Fraction results are drawn stacked in Math display (MathO); Linear display keeps `a⌟b`.
- Complex results (a and bi, r and θ) and Pol/Rec results use two lines in Linear display.
- Regression screenshot suite (118 images) with its own CI job.

Still open
- O04: the manual's Linear Display layout for the inequality Coefficient Editor note is not drawn (needs the manual page as text or a real-calculator photo).

Build
- CI reports "signed" or "unsigned" in the job summary; signing needs the four OMNI_* secrets.
