# test/

Flutter unit and widget tests for PropertyOS Alpha.

This folder will hold flutter test suites once the client codebase lands:

- Unit tests for compliance status calculation, Today rule thresholds (14/45/30/60-day boundaries), and other pure business logic.
- Widget tests for core screens (Sign in, Today, Properties, Property detail, Compliance, Documents, Tasks, Maintenance, Settings).

- See docs/testing/PropertyOS_Alpha_Test_Strategy.docx for the overall test approach and docs/testing/PropertyOS_Alpha_Test_Cases.xlsx for the source test case tracker these automated tests are derived from (IDs referenced where practical, e.g. COMP-03, TODAY-02).

- Run with: flutter test
