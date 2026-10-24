# Site Selection: Where TerraCyber Consulting Hosts Its Database

**Decision:** TerraCyber Consulting operates from, and hosts its distributed Engagement and Assurance Database (EAD) in, three Nigerian cities:

| Site | Office role | Database role (Portfolio 5) | Main reason |
| --- | --- | --- | --- |
| **Lagos** | Headquarters | Read/write **primary** | 21 of Nigeria's 28 data centres and almost every subsea cable; largest client market |
| **Abuja** | Regional office (North) | **Public-sector shard**: stores public-sector clients' findings | Federal government, regulators (NDPC, NITDA, CBN) and a Tier III government data centre; best-scoring second site |
| **Port Harcourt** | Regional office (South South and South East) | **Disaster-recovery standby** (streaming replica of Lagos) | Only city with an international subsea route independent of Lagos; oil and gas client base |

Research date: 24 October 2026. Sources are listed at the end; figures can change, so check them before quoting.

## 1. Method

1. **Fix the primary site first.** The primary carries all writes, so it needs the most data-centre choice, the best connectivity and the biggest client market. Lagos is the only candidate that leads on all three (section 2).
2. **Score the candidates for the two other sites** against seven weighted factors (section 3). Each factor scores 1 (poor) to 5 (strong); weighted total out of 100.
3. **Assign roles** to the two winners according to their strengths (section 4), and check what the choice does not solve (section 5).

Candidates: Abuja, Port Harcourt, Kano, Enugu and Ibadan, the cities that either have a data centre or are major regional centres.

## 2. Why Lagos is the primary

| Factor | Evidence |
| --- | --- |
| Data centres | 21 of the 28 data centres in Nigeria (operational or under construction) are in Lagos, about 75%, including several Tier III facilities (Rack Centre LGS1 and LGS2, Equinix LG1, Open Access Data Centres LOS1, MTN). |
| Power | Leading facilities generate their own power; for example, Rack Centre runs off-grid on a 13.5 MW gas-powered system, which matters because grid power remains a significant constraint. |
| Connectivity | Most of Nigeria's seven international subsea cables land in Lagos. |
| Client market | Commercial and financial centre, home to many banks, fintechs and insurers. The CBN requires banks, fintechs and payment companies to host transaction data in Nigeria by 1 January 2027, which creates compliance demand. |

**Lagos's own weakness:** concentration. In March 2024, an underwater landslide off Côte d'Ivoire cut the ACE, MainOne, SAT-3 and WACS cables and disrupted West African connectivity. A second site must not share this single route. Lagos State is also on the 2026 high-flood-risk list.

## 3. Scoring the other candidates

### 3.1 Factors and weights

| # | Factor | Weight | Why it matters to TerraCyber |
| --- | --- | ---: | --- |
| F1 | Data-centre availability and certification | 20 | A database node needs a certified facility with backup power |
| F2 | International connectivity independent of Lagos | 15 | A DR site on the same cable route fails with Lagos |
| F3 | Client demand across the three service lines | 20 | Offices must be near NGO, public-sector and private clients |
| F4 | Proximity to regulators and the federal government | 10 | NDPA, NITDA and CBN work; public-sector engagements |
| F5 | Staff security and travel (UK FCDO advice) | 15 | Consultants travel to client sites |
| F6 | Distance from Lagos (disaster-recovery separation) | 10 | A regional disaster must not hit both sites |
| F7 | Flood exposure (2026 Annual Flood Outlook) | 10 | Flooding is Nigeria's most frequent natural hazard |

### 3.2 Evidence per candidate

| Candidate | F1 Data centres | F2 Connectivity | F3 Client demand | F4 Regulators | F5 FCDO advice (Oct 2026) | F6 Distance from Lagos* | F7 Flood outlook 2026 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Abuja** | 3: Galaxy Backbone NSSC (Uptime Tier III), Digital Realty ABV1, Layer3 | Inland backbone hub; no own subsea landing | Federal ministries and agencies, donors and NGOs; the 2025 humanitarian response plan for the North East was launched here | NDPC, NITDA and CBN headquarters | All but essential travel (FCT) | 526 km | FCT listed high risk |
| **Port Harcourt** | Equinix PR1 (1 MW, live); a further Equinix facility in Rivers State under construction | **2Africa cable** landed at Qua Iboe (Akwa Ibom) in Feb 2024, the first international landing outside Lagos, linked by about 250 km of fibre to PR1 | Oil and gas hub; the sector earns about 90% of Nigeria's foreign exchange and is a frequent cyber-attack target | None | All but essential (non-riverine Rivers); riverine areas: against all travel | 448 km | Rivers listed high risk |
| **Kano** | Galaxy Backbone Kano (Uptime Tier IV, 2024) | Backbone only | Largest northern commercial city; NGOs in the North West | None | All but essential travel | 835 km | Kano listed high risk |
| **Enugu** | Galaxy Backbone Enugu (ISO certified; tier not stated) | Backbone only | South East commerce | None | Not listed | 460 km (191 km from Port Harcourt) | Enugu listed high risk |
| **Ibadan** | None (nearest: a Tier III facility under construction in Ogun State) | On the Lagos routes | Public and private sector in the South West | None | Not listed | **114 km** | Oyo listed high risk |

\* Straight-line (great-circle) distance between city centres, calculated from coordinates.

### 3.3 Weighted scores (1 to 5 per factor)

| Candidate | F1 (20) | F2 (15) | F3 (20) | F4 (10) | F5 (15) | F6 (10) | F7 (10) | **Total /100** |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **Abuja** | 4 | 3 | 5 | 5 | 3 | 5 | 3 | **80** |
| **Port Harcourt** | 3 | 5 | 4 | 1 | 3 | 4 | 3 | **68** |
| Kano | 3 | 2 | 3 | 1 | 3 | 5 | 3 | 57 |
| Enugu | 2 | 2 | 3 | 1 | 5 | 4 | 3 | 57 |
| Ibadan | 1 | 2 | 3 | 1 | 5 | 1 | 3 | 47 |

Total = sum of (score × weight) ÷ 5.

**How the scores were set:**

- **F1:** 4 = several facilities including a certified Tier III; 3 = one live certified facility; 2 = one facility without a stated tier; 1 = none.
- **F2:** 5 = own international route independent of Lagos; 3 = national backbone hub; 2 = backbone or Lagos routes only.
- **F5:** 5 = no FCDO restriction; 3 = "all but essential travel". FCDO advice is a cautious, outsider view; local staff and clients travel more freely, but the same standard is applied to every candidate.
- **F6:** 5 = more than 500 km; 4 = 400 to 500 km; 1 = under 150 km (same regional disaster zone).
- **F7:** every candidate state, and Lagos, is on the 2026 high-flood-risk list, so flood risk **does not separate the candidates** at state level. All score 3. Flood risk is handled inside each city by choosing a certified facility (section 5).

### 3.4 Result and sensitivity

- **Abuja (80) and Port Harcourt (68)** are selected.
- **Kano (57)** is the strongest alternative: it has the only Tier IV facility in the country and is the furthest from Lagos. It loses on connectivity and client demand. If TerraCyber wins large northern clients, Kano is the next site to add.
- **Enugu (57)** ties with Kano but is only 191 km from Port Harcourt, so it adds little separation once Port Harcourt is chosen.
- **Ibadan (47)** is too close to Lagos (114 km) to be a disaster-recovery site.
- **Robustness check:** removing the security factor (F5) entirely does not change the outcome. Abuja and Port Harcourt still rank first and second, followed by Kano, Enugu and Ibadan.

## 4. Roles assigned to each site

### Port Harcourt = disaster-recovery standby

The DR copy must survive what is most likely to take Lagos down: a cut to the Lagos cable cluster, a Lagos power or flood event, or a facility failure. Port Harcourt is the only city with an international route that does not pass through Lagos (2Africa via Qua Iboe), and reporting on Equinix's Port Harcourt investment highlights mirroring operations between Lagos and Port Harcourt for disaster recovery. At 448 km it is outside a Lagos-wide disaster.

**In Portfolio 5:** `pg-portharcourt` is a streaming hot-standby replica of `pg-lagos`, promoted if Lagos fails.

### Abuja = public-sector shard

- NITDA's National Cloud Computing Policy (2019) and the proposed National Cloud Technical Document emphasise sovereign hosting of higher-sensitivity government data.
- The National Shared Services Centre in Abuja, run by Galaxy Backbone (the federal government's ICT infrastructure provider), is an Uptime Tier III facility.
- Public-sector clients and the regulators TerraCyber works with (NDPC, NITDA, CBN) are in Abuja.

**In Portfolio 5:** findings of public-sector clients are stored on `pg-abuja`, as a foreign partition that the Lagos primary queries through `postgres_fdw`.

### MongoDB evidence store: one member per site

A three-member replica set with one member in each city keeps a majority (2 of 3) if any single site is lost, so evidence uploads continue.

### Why the shard key is sector, not region

All three sites are in Nigeria, and the **Nigeria Data Protection Act 2023** does not require data to stay in a particular region. It regulates transfers *outside* Nigeria (sections 41 to 43). The rules that care where data is hosted are **sector** rules: government data (NITDA policy) and financial transaction data (CBN, from 1 January 2027). Sector is therefore the shard key with a real business reason.

## 5. Residual risks and mitigations

| Risk | Mitigation |
| --- | --- |
| All selected states are on the 2026 high-flood-risk list | Host only in certified facilities with on-site power; Lagos and Port Harcourt are 448 km apart, so a single local flood event is unlikely to take out both the primary and the standby |
| Grid power instability | Use facilities with independent generation (for example gas-powered off-grid systems) |
| Staff safety (FCDO "all but essential travel" for FCT and Rivers) | Travel risk assessments; remote assessment where possible; no travel to riverine areas |
| Port Harcourt has fewer facilities (one live) | Contract a second provider in Lagos as fallback; review when the second Rivers facility opens |
| Asynchronous replication can lose the last seconds of writes | Synchronous replication for billing data (Portfolio 5, section 5.5) |

## Sources

- Technext, [A comprehensive list of the 28 data centres in Nigeria](https://technext24.com/2026/06/26/28-data-centres-nigeria-2026/), 26 June 2026
- TechCabal, [Nigeria's data centres face major test under CBN's local hosting mandate](https://techcabal.com/2026/07/07/cbns-local-data-order-puts-nigerias-data-centres-to-test/), 7 July 2026
- TechCabal, [Why Equinix wants Nigeria's Internet to have a second anchor in South-South](https://techcabal.com/?p=180720)
- DatacenterDynamics, [2Africa subsea cable lands in Kwa Ibo, Nigeria](https://www.datacenterdynamics.com/en/news/2africa-subsea-cable-lands-in-kwa-ibo-nigeria/)
- Techeconomy, [Galaxy Backbone Tier IV data centre achieves Uptime Institute TCCF certification](https://techeconomy.ng/galaxy-backbone-tier-iv-data-centre-achieves-uptime-institute-tccf-certification/), 4 July 2024
- ICIR, [33 states at risk of flooding in 2026, FG warns](https://www.icirnigeria.org/33-states-at-risk-of-flooding-in-2026-fg-warns/), 15 April 2026
- UK FCDO, [Foreign travel advice: Nigeria](https://www.gov.uk/foreign-travel-advice/nigeria), accessed 24 October 2026
- Chambers, [Data localisation in Nigeria: separating myth from reality](https://chambers.com/articles/data-localisation-in-nigeria-separating-myth-from-reality)
- Nigeria Data Protection Act 2023, [full text](https://www.dataguidance.com/sites/default/files/data_protection_act_2023.pdf)
- Mondaq, [Synoptic analysis of the NDPA General Application and Implementation Directive (GAID) 2025](https://www.mondaq.com/nigeria/privacy-protection/1620778/synoptic-analysis-of-the-nigeria-data-protection-act-general-application-and-implementation-directive-gaid-2025)
- Intelligent CIO Africa, [Check Point urges Nigeria's oil and gas industry to enhance its cyber security](https://www.intelligentcio.com/africa/2025/06/02/check-point-urges-nigerias-oil-and-gas-industry-to-enhance-its-cyber-security/), 2 June 2025
- Gazette Nigeria, [UN seeks over $900 million to tackle humanitarian crisis in North-East Nigeria](https://gazettengr.com/un-seeks-over-900-million-to-tackle-humanitarian-crisis-in-north-east-nigeria/)
