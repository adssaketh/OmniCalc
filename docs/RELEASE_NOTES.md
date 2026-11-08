# Release notes

## 1.2.0+3 (phase 8e)

New
- INEQ: the answer now shows the header line of the manual (`A<X<B`, `X≤A,B≤X`, `X=A,B≤X`, `A<X<B,C<X`) above the solution in Math display.
- INEQ in Linear Display (SETUP Display = LineIO): the header, then one line per endpoint (`A=`, `B=`, `C=`) with its value to 10 digits. `All Real Numbers` and `No-Solution` are unchanged.

Still open
- The four full-height sheet rows I02, L05, M04, N06 stay Partial by design. Examples 1 and 3 in Linear Display and the double-root header `X<A,A<X` are unverified on a real device.

## 1.2.0 (phase 8c)

New
- SETUP: Decimal point (Disp) dot or comma for results, and Display contrast (CONT 1-5).
- Recurring-decimal input: SHIFT on the `×10ˣ` key (`0.ṅ`), COMP mode, periods up to 14 digits.
- Fraction results are drawn stacked in Math display (MathO); Linear display keeps `a⌟b`.
- Complex results (a and bi, r and θ) and Pol/Rec results use two lines in Linear display.
- Regression screenshot suite (118 images) with its own CI job.

Still open
- O04 was open here; it is closed in 1.2.0+3.

Build
- CI reports "signed" or "unsigned" in the job summary; signing needs the four OMNI_* secrets.
