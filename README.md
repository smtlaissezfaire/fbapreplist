# FBA Prep List

Directory of US Amazon FBA prep centers, published at [fbapreplist.com](https://fbapreplist.com).

The site is a static [Jekyll 4](https://jekyllrb.com/) build. A local generator reads `_data/centers.csv` and writes one page per center, state, and service. GitHub Actions deploys the build to GitHub Pages. This repo does not use the `github-pages` gem.

## Build

Ruby 3.2 or newer. CI uses Ruby 3.3.

```sh
bundle config set --local path vendor/bundle
bundle install
JEKYLL_ENV=production bundle exec jekyll build
ruby script/verify
bundle exec jekyll serve
```

`script/verify` checks the built `_site`: page counts, the sitemap, internal links, titles, JSON-LD, `CNAME`, and `robots.txt`.

## Data

`_data/centers.csv` is the publishable subset: rows whose `url_status` is `ok`. This edition has 352 centers in 37 states. Cell values are unchanged from the research export. Column notes are in `_data/centers-README.md`.

To refresh the directory:

1. Re-check center websites and produce a new CSV with the same columns.
2. Keep only `url_status=ok` rows. Do not commit other statuses.
3. Do not rewrite cell values. Keep each fact's source URL.
4. Replace `_data/centers.csv`.
5. If the center or state count changes, update `EXPECTED_CENTERS` and `EXPECTED_STATES` in `script/verify`.
6. Rebuild and run `ruby script/verify`.

The generator publishes only fields that are present. A service badge means the center's site mentions that service. A blank flag is unknown, not a no. Price, minimum, setup, and turnaround text is shown as a verbatim fragment. Email tokens that are not real addresses (crawl junk, or a placeholder such as `user@domain`) are left out of the page. The CSV itself is not edited.

State-by-service combination pages are not generated. The home page filters by state and service instead, which keeps thin pages out of the index.

## Listing form

`formspree_endpoint` in `_config.yml` is the placeholder `https://formspree.io/f/REPLACE_ME`.

The list-your-prep-center page shows a warning, and the build prints a warning, until that value is a real Formspree endpoint. Change it in `_config.yml` only. The form posts there and includes a `_gotcha` honeypot.

## Deploy and DNS

Pushes to `main` run `.github/workflows/pages.yml`: Jekyll build, `script/verify`, then `actions/deploy-pages`. Pull requests build and verify, and do not deploy.

In the GitHub repo settings, set Pages to deploy with GitHub Actions.

`CNAME` contains `fbapreplist.com`, so the built site is served at the apex. At the DNS host, point the apex at GitHub Pages with the A records GitHub documents:

- `185.199.108.153`
- `185.199.109.153`
- `185.199.110.153`
- `185.199.111.153`

Confirm those addresses in GitHub's Pages docs before you change DNS. They have been stable, and GitHub can change them. For `www`, add a CNAME to `smtlaissezfaire.github.io` if you want that hostname as well. The `CNAME` file in this repo lists the apex only.

The canonical site URL is `https://fbapreplist.com` with no base path.
