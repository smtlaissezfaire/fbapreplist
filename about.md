---
layout: page
title: About
description: How FBA Prep List is built from public prep-center websites, what a service badge means, and how listings are corrected.
permalink: /about/
section: about
crumbs:
  - label: Home
    url: /
  - label: About
    url: /about/
---

FBA Prep List is a directory of US companies whose public websites describe Amazon FBA prep. This edition lists {{ site.data.directory.center_count }} centers across {{ site.data.directory.state_count }} states. The pages behind those listings were checked on {{ site.data.directory.checked_label }}.

A center is included when its site loaded and its own text mentioned Amazon, FBA, FNSKU, or prep-center work. Facts on each listing come from that center's public website. We keep the page address a fact came from.

The state used for browsing is the state on the center's site when we found a US address there. When we did not, the state comes from a third-party directory listing, and the listing says so. A service badge means the center's site mentions that service. No badge means we did not find a mention. It does not mean the center lacks the service.

Unit pricing, minimums, setup fees, and turnaround lines are copied as fragments. They are not confirmed quotes. Software names are mentions, not a claim that the center uses the product.

We did not call the centers, place test orders, or review quality. A listing is not an endorsement. [Read the disclaimer](/disclaimer/).

To correct a listing, or to ask for a center to be added, use [List your prep center](/list-your-prep-center/). The form on that page is a placeholder until a Formspree endpoint is connected.

To refresh the directory, replace `_data/centers.csv` with rows whose `url_status` is `ok`, keep the column values and source URLs intact, then rebuild. Column notes are in `_data/centers-README.md`.
