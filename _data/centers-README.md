# Note for this repository

`centers.csv` in this folder is the publishable subset of the research export: only rows whose `url_status` is `ok` (352 centers). Cell values are unchanged. Rows with any other status were left out of the site repository on purpose.

The rest of this document describes the research file and every column.

# prep-centers.csv: US Amazon FBA prep center seed dataset

Built Nov 24, 2026 (PT), following the Directory Guide's "Data: collect, enrich, keep fresh" and "Curate the data" pages.
We used other directories only to discover centers. Every fact in the file comes from the center's own website, except the `directory_listed_location` column. No descriptions were copied.

## Counts
- 475 unique US candidate domains after merging the 4 discovery sources and removing duplicates by domain.
- **352 `ok`**: the site loads and its own text mentions Amazon, FBA, FNSKU or prep center.
- 38 `live_no_amazon_mention`: the site loads but its HTML never mentions Amazon or FBA. It may be built with JavaScript, may have changed business, or may not be a prep center.
- 30 `unreachable_connection_error`: the domain has DNS records, but the site didn't respond or returned a TLS/connection error on Nov 24.
- 55 `dead_no_dns`: no A record (NXDOMAIN, checked with Google DNS-over-HTTPS). These businesses have most likely closed.
- 3P Mercury was removed: it's seller software (sourcing, shipments, and a "3P Certified" prep-center network), not a prep center. EnZone PrepWorks (Conroe, TX) and Elkhorn Prep & Ship (Billings, MT) say on their own sites that they're 3P Mercury certified.

## Discovery sources (`discovered_via`)
| key | URL | what we took |
|---|---|---|
| fbaprepfinder | https://fbaprepfinder.com/prep-centers/ (499 profiles) | name, listed city/state, domain |
| ecomcircles | https://ecomcircles.com/prep-centers/ (287 profiles) | name, listed city/state, website |
| cleartheshelf | https://cleartheshelf.com/amazon-fba-prep-center-services/ (289 rows) | name, state, website |
| scott | Scott's own list | PrepWorx |
Not mined: fbaprepcenters.org (554 listings; it blocked our crawler), prepcentersearch.com (334; contains spam), Google Maps, Reddit and Facebook groups, and the Amazon Service Provider Network (requires a seller login).

## Columns
- `id`, `name` (shortest name given by the directories), `website` (the URL after redirects), `domain`
- `url_status`: ok / live_no_amazon_mention / unreachable_connection_error / dead_no_dns. `http_code` is the home page status. `redirects_to` is filled when the site redirects to a different domain.
- `hq_city`, `hq_state`: the first US address ("City, ST 12345") found on the center's own site. `address_source_url` is the page it came from.
- `warehouse_states_on_site`: every state that appears in an address on the site.
- `directory_listed_location`: the location the discovery directories give, shown separately because it's third-party.
- `state_for_filtering`: the state from the center's own site, or from the directory listing when the site has none. `state_basis` says which.
- `sales_tax_free_state`: Y when `state_for_filtering` is DE, OR, NH, MT or AK; N for any other state; blank when the state is unknown.
- Service flags (`fba_prep`, `fbm_dtc_fulfillment`, `walmart_wfs`, `tiktok_shop`, `returns_removals`, `bundling_kitting`, `photography`, `storage`, `international_import`, `hazmat`): **Y means the center's own pages mention the service.** Blank means we found no mention, which is not proof they don't offer it. `services_source_urls` lists the pages we read (the home page plus up to 5 pricing, services, contact, about or FAQ pages).
- `unit_pricing_excerpt` and `pricing_source_url`: up to 3 verbatim "$X per unit/item" excerpts.
- `minimum_excerpt`, `setup_fee_excerpt`, `turnaround_excerpt`: the verbatim sentence fragments that mention each, with the source URL. **Read these, don't treat them as values.** A fragment can be a "no minimums" statement, an FAQ question, or a testimonial.
- `software_mentioned`: named software (ShipStation, Extensiv, 3P Mercury, InventoryLab...), or "client portal mentioned". This is a mention only. ShipBob and ShipStation are sometimes named as competitors rather than tools the center uses.
- `email`, `phone`: from mailto/tel links and visible text on the center's own site. These are business contacts only. `contact_source_url` is the page.
- `discovered_via`, `discovery_urls`, `checked_on` (2026-11-24)

## Coverage notes and gaps
- Field fill rate among the 352 ok rows: own-site address 226, unit pricing 135, minimums 131, setup-fee fragment 74, turnaround 107, software 112, email 268, phone 200.
- About 36% of state values come from the directory listing, not the center's own site.
- The crawler reads raw HTML only, so sites built with JavaScript (Wix, some React sites) undercount services and pricing.
- The list mixes prep specialists with general 3PLs that offer FBA prep. A prep-specialist vs 3PL type column still needs a human pass.
- The guide's Step 4: check a random 10% by hand before publishing. If that check finds errors, check everything.
- To keep it fresh: re-run `prep/crawl.py` and then `prep/extract.py` every month and flag changes. Working files are in `prep/`.
