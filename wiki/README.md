# IFR ACS Correlation Wiki

A cross-reference between the **Instrument Rating – Airplane Airman Certification Standards (FAA-S-ACS-8C)** and the source material an instrument student actually studies from: the **FARs (14 CFR)**, the **Aeronautical Information Manual (AIM)**, and the **Instrument Flying Handbook (FAA-H-8083-15B)** — plus the other FAA references the ACS lists for each task.

Every Knowledge (K), Risk Management (R), and Skill (S) element in the ACS is mapped to where that material lives in the source documents, so you can go from any checkride task straight to the primary reference — or from a regulation or AIM paragraph back to the ACS elements it supports.

> The ACS element codes used throughout (e.g., `IR.I.A.K1`) match the codes used by the flash card bank in this repository (`FlashCards/IFRCore/Sources/IFRCore/Resources/bank-v1.json`), so wiki pages and cards can be cross-referenced directly.

## Areas of Operation

| Area | Page | Tasks |
|---|---|---|
| I | [Preflight Preparation](Area-I-Preflight-Preparation.md) | A. Pilot Qualifications · B. Weather Information · C. Cross-Country Flight Planning |
| II | [Preflight Procedures](Area-II-Preflight-Procedures.md) | A. Aircraft Systems Related to IFR Operations · B. Flight Instruments & Navigation Equipment · C. Instrument Flight Deck Check |
| III | [ATC Clearances and Procedures](Area-III-ATC-Clearances-and-Procedures.md) | A. Compliance with ATC Clearances · B. Holding Procedures |
| IV | [Flight by Reference to Instruments](Area-IV-Flight-by-Reference-to-Instruments.md) | A. Instrument Flight · B. Recovery from Unusual Flight Attitudes |
| V | [Navigation Systems](Area-V-Navigation-Systems.md) | A. Intercepting & Tracking Nav Systems and DME Arcs · B. Departure, En Route, and Arrival Operations |
| VI | [Instrument Approach Procedures](Area-VI-Instrument-Approach-Procedures.md) | A. Non-precision Approach · B. Precision Approach · C. Missed Approach · D. Circling Approach · E. Landing from an Instrument Approach |
| VII | [Emergency Operations](Area-VII-Emergency-Operations.md) | A. Loss of Communications · B. One Engine Inoperative (Simulated), Straight-and-Level & Turns · C. Instrument Approach & Landing with an Inoperative Engine (Simulated) · D. Approach with Loss of Primary Flight Instrument Indicators |
| VIII | [Postflight Procedures](Area-VIII-Postflight-Procedures.md) | A. Checking Instruments and Equipment |

**Reverse lookup:** [Reference Index](Reference-Index.md) — find every ACS task that a given FAR, AIM paragraph, or IFH chapter supports.

## How the correlation tables work

Each task page reproduces the ACS's own **References** line, then maps each element:

| Column | Meaning |
|---|---|
| **ACS Element** | The official element code from FAA-S-ACS-8C (e.g., `IR.I.C.K2`) |
| **Element summary** | Shortened element text (see the ACS for the authoritative wording) |
| **14 CFR (FARs)** | The regulation(s) that govern or define the element |
| **AIM** | Chapter‑section‑paragraph in the current AIM (e.g., 5‑3‑8 Holding) |
| **IFH 8083-15B** | Chapter of the Instrument Flying Handbook covering the element |
| **Other refs** | Instrument Procedures Handbook (IPH), PHAK, Airplane Flying Handbook (AFH), Aviation Weather Handbook (AWH), Advisory Circulars, POH/AFM, etc. |

A dash (—) means the source document does not meaningfully cover that element (e.g., the FARs say nothing about instrument scan technique; the IFH says little about certification rules). Skill elements whose standard is purely a flight tolerance (±100 ft, ±10 kts, ¾-scale CDI) cite the ACS itself as the standard, with technique references where useful.

## Source documents and editions

| Document | Edition used | Where to get it |
|---|---|---|
| Instrument Rating – Airplane ACS | **FAA-S-ACS-8C** (with Change 1) | [faa.gov ACS page](https://www.faa.gov/training_testing/testing/acs) · [direct PDF](https://www.faa.gov/training_testing/testing/acs/instrument_rating_airplane_acs_8.pdf) |
| Federal Aviation Regulations | 14 CFR parts 61, 68, 91, 95, 97 (current) | [eCFR Title 14](https://www.ecfr.gov/current/title-14) |
| Aeronautical Information Manual | Current basic AIM with changes | [AIM online (HTML)](https://www.faa.gov/air_traffic/publications/atpubs/aim_html/) |
| Instrument Flying Handbook (IFH) | **FAA-H-8083-15B** | [faa.gov handbook page](https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/instrument_flying_handbook) |
| Instrument Procedures Handbook (IPH) | FAA-H-8083-16B | [faa.gov handbook page](https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/instrument_procedures_handbook) |
| Pilot's Handbook of Aeronautical Knowledge (PHAK) | FAA-H-8083-25C | [faa.gov handbook page](https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/phak) |
| Airplane Flying Handbook (AFH) | FAA-H-8083-3C | [faa.gov handbook page](https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/airplane_handbook) |
| Risk Management Handbook | FAA-H-8083-2A | [faa.gov handbooks](https://www.faa.gov/regulations_policies/handbooks_manuals/aviation) |
| Aviation Weather Handbook (AWH) | FAA-H-8083-28A (replaced AC 00-6 & AC 00-45) | [faa.gov handbooks](https://www.faa.gov/regulations_policies/handbooks_manuals/aviation) |
| Terminal Procedures Publication (TPP), Chart Supplement, IFR en route charts | Current cycle | [FAA digital products](https://www.faa.gov/air_traffic/flight_info/aeronav/digital_products/) |

### Instrument Flying Handbook (8083-15B) chapter map

Because the correlation tables cite the IFH by chapter, here is the chapter layout for quick reference:

| Ch | Title |
|---|---|
| 1 | The Human Element / Human Factors (spatial disorientation, illusions, IM SAFE, ADM) |
| 2 | Aerodynamic Factors |
| 3 | Flight Instruments (pitot-static, gyroscopic, electronic displays, magnetic compass, preflight instrument checks) |
| 4 | Airplane Attitude Instrument Flying (Section I: analog · Section II: electronic flight displays) |
| 5 | Airplane Basic Flight Maneuvers (Section I: analog · Section II: EFD) — includes unusual attitude recoveries |
| 6 | Helicopter Attitude Instrument Flying *(not applicable to the airplane ACS)* |
| 7 | Navigation Systems (VOR, DME, ILS, GPS/WAAS, RNAV, intercepting & tracking, DME arcs) |
| 8 | The National Airspace System (airspace, charts, routes) |
| 9 | The Air Traffic Control System (radar, services, communications) |
| 10 | IFR Flight (planning, clearances, departure/en route/arrival, holding, approaches) |
| 11 | Emergency Operations (partial panel, lost comm, system failures) |
| App. A | Clearance Shorthand |

## Caveats

- The ACS, AIM, and handbooks are living documents. Chapter/paragraph numbers cited here were verified against the editions listed above; always fly and test with the **current** publications.
- This wiki is a study aid, not a source. Where wording matters (especially regulations and lost-comm procedures), read the primary text.
