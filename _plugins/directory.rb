# frozen_string_literal: true

require "csv"
require "cgi"
require "date"
require "json"

# Builds directory pages from _data/centers.csv.
# Display rules:
# - Publish url_status == ok only. The CSV in this repo is already filtered.
# - Blank fields are omitted. Service badges render only for Y flags.
# - Excerpts stay verbatim and are labeled as fragments from the center's site.
# - Address city/state renders only when both hq_city and hq_state exist.
# - A filtering state that comes from a directory listing is labeled third-party.
module FBAPrepList
  STATES = {
    "AL" => "Alabama",
    "AK" => "Alaska",
    "AZ" => "Arizona",
    "AR" => "Arkansas",
    "CA" => "California",
    "CO" => "Colorado",
    "CT" => "Connecticut",
    "DE" => "Delaware",
    "DC" => "District of Columbia",
    "FL" => "Florida",
    "GA" => "Georgia",
    "HI" => "Hawaii",
    "ID" => "Idaho",
    "IL" => "Illinois",
    "IN" => "Indiana",
    "IA" => "Iowa",
    "KS" => "Kansas",
    "KY" => "Kentucky",
    "LA" => "Louisiana",
    "ME" => "Maine",
    "MD" => "Maryland",
    "MA" => "Massachusetts",
    "MI" => "Michigan",
    "MN" => "Minnesota",
    "MS" => "Mississippi",
    "MO" => "Missouri",
    "MT" => "Montana",
    "NE" => "Nebraska",
    "NV" => "Nevada",
    "NH" => "New Hampshire",
    "NJ" => "New Jersey",
    "NM" => "New Mexico",
    "NY" => "New York",
    "NC" => "North Carolina",
    "ND" => "North Dakota",
    "OH" => "Ohio",
    "OK" => "Oklahoma",
    "OR" => "Oregon",
    "PA" => "Pennsylvania",
    "RI" => "Rhode Island",
    "SC" => "South Carolina",
    "SD" => "South Dakota",
    "TN" => "Tennessee",
    "TX" => "Texas",
    "UT" => "Utah",
    "VT" => "Vermont",
    "VA" => "Virginia",
    "WA" => "Washington",
    "WV" => "West Virginia",
    "WI" => "Wisconsin",
    "WY" => "Wyoming"
  }.freeze

  # Column definition: Y when state_for_filtering is one of these.
  TAX_FREE_CODES = %w[DE MT NH OR AK].freeze

  SERVICES = [
    { "key" => "fba_prep", "slug" => "fba-prep", "name" => "FBA prep", "title" => "Amazon FBA prep centers" },
    { "key" => "fbm_dtc_fulfillment", "slug" => "fbm-dtc-fulfillment", "name" => "FBM / DTC fulfillment", "title" => "FBM and DTC fulfillment centers" },
    { "key" => "walmart_wfs", "slug" => "walmart-wfs", "name" => "Walmart WFS prep", "title" => "Walmart WFS prep centers" },
    { "key" => "tiktok_shop", "slug" => "tiktok-shop", "name" => "TikTok Shop", "title" => "TikTok Shop prep centers" },
    { "key" => "returns_removals", "slug" => "returns-and-removals", "name" => "Returns and removals", "title" => "Returns and removals centers" },
    { "key" => "bundling_kitting", "slug" => "bundling-and-kitting", "name" => "Bundling and kitting", "title" => "Bundling and kitting centers" },
    { "key" => "photography", "slug" => "photography", "name" => "Photography", "title" => "Prep centers with product photography" },
    { "key" => "storage", "slug" => "storage", "name" => "Storage", "title" => "Prep centers with storage" },
    { "key" => "international_import", "slug" => "international-import", "name" => "International / import", "title" => "International and import prep centers" },
    { "key" => "hazmat", "slug" => "hazmat", "name" => "Hazmat", "title" => "Hazmat prep centers" }
  ].freeze

  EXCERPT_FIELDS = [
    ["unit_pricing_excerpt", "pricing_source_url", "Unit pricing"],
    ["minimum_excerpt", "minimum_source_url", "Minimums"],
    ["setup_fee_excerpt", "setup_source_url", "Setup fee"],
    ["turnaround_excerpt", "turnaround_source_url", "Turnaround"]
  ].freeze

  MIN_SERVICE_COUNT = 5
  EMAIL_RE = /\A[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\z/i

  class GeneratedPage < Jekyll::Page
    def initialize(site, permalink, layout, data, content = "")
      @site = site
      @base = site.source
      if permalink.end_with?("/")
        @dir = permalink.sub(%r{\A/}, "").sub(%r{/\z}, "")
        @name = "index.html"
      else
        dir = File.dirname(permalink)
        @dir = dir == "/" || dir == "." ? "" : dir.sub(%r{\A/}, "")
        @name = File.basename(permalink)
      end
      self.process(@name)
      self.data = data.dup
      self.data["permalink"] = permalink
      self.data["layout"] = layout
      self.content = content
    end
  end

  class << self
    def build(site)
      rows = load_rows(site)
      centers = rows.map { |row| decorate(row) }
      assign_slugs(centers)
      states = build_states(centers)
      services = build_services(centers)
      assign_service_urls(centers, services)
      assign_search(centers)
      assign_related(centers)
      tax_groups = build_tax_groups(centers)
      checked_iso = centers.map { |c| c["checked_iso"] }.compact.max
      checked_label = date_label(checked_iso)

      state_by_code = states.to_h { |s| [s["code"], s] }
      centers.each do |center|
        state = state_by_code[center["state_code"]]
        center["state_url"] = state["url"] if state
      end

      directory = {
        "centers" => centers.sort_by { |c| c["name"].downcase },
        "states" => states.sort_by { |s| s["name"] },
        "featured_states" => states.sort_by { |s| [-s["count"], s["name"]] }.first(8),
        "services" => services,
        "tax_free_count" => tax_groups.sum { |g| g["count"] },
        "tax_free_states" => tax_groups,
        "alaska_listed" => tax_groups.any? { |g| g["code"] == "AK" },
        "checked_label" => checked_label,
        "checked_iso" => checked_iso,
        "center_count" => centers.size,
        "state_count" => states.size,
        "all_states" => STATES.map { |code, name| { "code" => code, "name" => name } }.sort_by { |s| s["name"] }
      }
      site.data["directory"] = directory

      centers.each { |center| site.pages << center_page(site, center) }
      states.each { |state| site.pages << state_page(site, state, checked_label, checked_iso) }
      site.pages << states_index_page(site, directory, checked_label, checked_iso)
      services.each { |service| site.pages << service_page(site, service, checked_label, checked_iso) }
      site.pages << services_index_page(site, services, checked_label, checked_iso)
      site.pages << tax_page(site, tax_groups, checked_label, checked_iso)

      update_home(site, directory)
      warn_formspree(site)

      entries = sitemap_entries(site, checked_iso)
      site.pages << raw_page(site, "/search-index.json", search_json(directory["centers"]))
      site.pages << raw_page(site, "/sitemap.xml", sitemap_xml(entries))

      Jekyll.logger.info "Directory:", "#{centers.size} centers, #{states.size} states, #{services.size} service pages, #{tax_groups.sum { |g| g['count'] }} in sales-tax-free states"
    end

    def load_rows(site)
      path = File.join(site.source, "_data", "centers.csv")
      CSV.read(path, headers: true, encoding: "bom|utf-8").map do |row|
        data = row.to_h
        status = data["url_status"].to_s.strip
        unless status == "ok"
          raise "Refusing to publish #{data['name'].inspect} with url_status=#{status.inspect}"
        end
        data
      end
    end

    def decorate(row)
      city = present(row["hq_city"])
      region = present(row["hq_state"])
      code = present(row["state_for_filtering"])
      state_name = code ? (STATES[code] || code) : nil
      basis = present(row["state_basis"])
      listed = present(row["directory_listed_location"])
      show_address = !city.nil? && !region.nil?
      website = present(row["website"])
      checked_iso = present(row["checked_on"]) || "2026-11-24"
      service_keys = SERVICES.map { |svc| svc["key"] }.select { |key| row[key].to_s.strip == "Y" }
      services = SERVICES.select { |svc| service_keys.include?(svc["key"]) }.map do |svc|
        { "key" => svc["key"], "slug" => svc["slug"], "name" => svc["name"], "url" => nil }
      end

      center = {
        "name" => row["name"].to_s.strip,
        "website" => website,
        "website_label" => website ? display_url(website) : nil,
        "phones" => phones_for(row["phone"]),
        "emails" => emails_for(row["email"]),
        "show_address" => show_address,
        "hq_city" => city,
        "hq_state" => region,
        "state_code" => code,
        "state_name" => state_name,
        "state_basis" => basis,
        "listed_location" => listed,
        "tax_free" => row["sales_tax_free_state"].to_s.strip == "Y",
        "services" => services,
        "service_keys" => service_keys,
        "excerpts" => excerpts_for(row),
        "software" => software_for(row["software_mentioned"]),
        "warehouse_states" => warehouse_names(row["warehouse_states_on_site"]),
        "sources" => sources_for(row),
        "address_source_url" => http_url(row["address_source_url"]),
        "contact_source_url" => http_url(row["contact_source_url"]),
        "checked_iso" => checked_iso,
        "checked_label" => date_label(checked_iso),
        "related" => []
      }
      center["location_line"], center["basis_note"], center["basis_short"] = location_copy(center)
      center
    end

    def location_copy(center)
      if center["show_address"]
        ["#{center['hq_city']}, #{center['hq_state']}", nil, nil]
      elsif center["state_name"] && center["state_basis"] == "directory listing"
        note = if center["listed_location"]
                 "State from a third-party directory listing (#{center['listed_location']}), not from an address on the center's website."
               else
                 "State from a third-party directory listing, not from an address on the center's website."
               end
        [center["state_name"], note, "Third-party listing"]
      elsif center["state_name"] && center["state_basis"] == "own site"
        [
          center["state_name"],
          "State from the center's website. No city was found in an address there.",
          "State from their website"
        ]
      elsif center["state_name"]
        [center["state_name"], "State used for filtering: #{center['state_name']}.", nil]
      else
        ["United States", nil, nil]
      end
    end

    def assign_slugs(centers)
      used = {}
      centers.each do |center|
        base = slugify(center["name"])
        base = "center" if base.empty?
        slug = base
        if used[slug] && center["state_code"]
          slug = "#{base}-#{center['state_code'].downcase}"
        end
        if used[slug]
          n = 2
          n += 1 while used["#{base}-#{n}"]
          slug = "#{base}-#{n}"
        end
        used[slug] = true
        center["slug"] = slug
        center["url"] = "/prep-centers/#{slug}/"
        center["correction_url"] = "/list-your-prep-center/?type=correction&center=#{CGI.escape(center['name'])}"
      end
    end

    def assign_service_urls(centers, services)
      live = services.to_h { |svc| [svc["slug"], svc["url"]] }
      centers.each do |center|
        center["services"].each do |svc|
          svc["url"] = live[svc["slug"]]
        end
        center["service_slugs"] = center["services"].filter_map { |svc| svc["slug"] if svc["url"] }.join(" ")
      end
    end

    def assign_search(centers)
      centers.each do |center|
        bits = [
          center["name"],
          center["hq_city"],
          center["hq_state"],
          center["state_code"],
          center["state_name"],
          center["listed_location"],
          *center["services"].map { |svc| svc["name"] }
        ]
        center["search"] = bits.compact.join(" ").downcase.gsub(/[^a-z0-9]+/, " ").squeeze(" ").strip
      end
    end

    def assign_related(centers)
      centers.group_by { |c| c["state_code"] }.each_value do |group|
        ordered = group.sort_by { |c| c["name"].downcase }
        ordered.each_with_index do |center, idx|
          picked = []
          (1...ordered.size).each do |offset|
            break if picked.size >= 6
            other = ordered[(idx + offset) % ordered.size]
            picked << {
              "name" => other["name"],
              "url" => other["url"],
              "location_line" => other["location_line"]
            }
          end
          center["related"] = picked
        end
      end
    end

    def build_states(centers)
      centers.group_by { |c| c["state_code"] }.filter_map do |code, list|
        next if code.nil? || code.empty?
        name = STATES[code] || code
        slug = slugify(name)
        own = list.count { |c| c["state_basis"] == "own site" }
        directory = list.count { |c| c["state_basis"] == "directory listing" }
        {
          "code" => code,
          "name" => name,
          "slug" => slug,
          "url" => "/fba-prep-centers/#{slug}/",
          "count" => list.size,
          "own_count" => own,
          "directory_count" => directory,
          "centers" => list.sort_by { |c| [c["hq_city"] ? c["hq_city"].downcase : "~", c["name"].downcase] }
        }
      end
    end

    def build_services(centers)
      SERVICES.filter_map do |svc|
        list = centers.select { |c| c["service_keys"].include?(svc["key"]) }
        next if list.size < MIN_SERVICE_COUNT
        {
          "key" => svc["key"],
          "slug" => svc["slug"],
          "name" => svc["name"],
          "title" => svc["title"],
          "count" => list.size,
          "url" => "/services/#{svc['slug']}/",
          "centers" => list.sort_by { |c| [c["state_name"].to_s, c["name"].downcase] }
        }
      end
    end

    def build_tax_groups(centers)
      chosen = centers.select { |c| c["tax_free"] }
      codes = TAX_FREE_CODES + (chosen.map { |c| c["state_code"] }.uniq - TAX_FREE_CODES)
      codes.filter_map do |code|
        list = chosen.select { |c| c["state_code"] == code }
        next if list.empty?
        name = STATES[code] || code
        {
          "code" => code,
          "name" => name,
          "count" => list.size,
          "url" => "/fba-prep-centers/#{slugify(name)}/",
          "centers" => list.sort_by { |c| c["name"].downcase }
        }
      end
    end

    def center_page(site, center)
      title = if center["show_address"]
                "#{center['name']} | FBA prep center in #{center['hq_city']}, #{center['hq_state']}"
              elsif center["state_name"]
                "#{center['name']} | FBA prep center in #{center['state_name']}"
              else
                "#{center['name']} | FBA prep center"
              end
      place = if center["show_address"]
                " in #{center['hq_city']}, #{center['hq_state']}"
              elsif center["state_name"]
                " listed in #{center['state_name']}"
              else
                ""
              end
      names = center["services"].map { |svc| svc["name"] }
      extra = names.empty? ? "" : " Site mentions: #{names.first(4).join(', ')}."
      description = "Directory listing for #{center['name']}, a prep center#{place}. Facts come from the center's public website, checked #{center['checked_label']}.#{extra}"
      crumbs = [{ "label" => "Home", "url" => "/" }]
      if center["state_name"] && center["state_url"]
        crumbs << { "label" => "States", "url" => "/fba-prep-centers/" }
        crumbs << { "label" => center["state_name"], "url" => center["state_url"] }
      end
      crumbs << { "label" => center["name"], "url" => center["url"] }
      graph = [breadcrumb_ld(site, crumbs), local_business(site, center)]
      GeneratedPage.new(site, center["url"], "center", {
        "title" => title,
        "description" => description,
        "section" => "centers",
        "center" => center,
        "crumbs" => crumbs,
        "json_ld" => ld_graph(graph),
        "lastmod" => center["checked_iso"]
      })
    end

    def state_page(site, state, checked_label, checked_iso)
      count = state["count"]
      noun = count == 1 ? "center" : "centers"
      verb = count == 1 ? "is" : "are"
      lede = "#{count} #{noun} in this directory #{verb} listed in #{state['name']}."
      if state["own_count"].positive? && state["directory_count"].positive?
        lede += " For #{state['own_count']}, that state comes from an address on the center's website. For #{state['directory_count']}, it comes from a third-party directory listing because no US address was found on the site."
      elsif state["directory_count"].positive?
        lede += " That state comes from a third-party directory listing for every center in this list, because no US address was found on the site."
      elsif state["own_count"].positive?
        lede += " That state comes from an address on the center's website for every center in this list."
      end
      title = "FBA prep centers in #{state['name']}"
      description = "#{count} Amazon FBA prep #{noun} in #{state['name']}. Listings are compiled from public websites, checked #{checked_label}."
      url = state["url"]
      crumbs = [
        { "label" => "Home", "url" => "/" },
        { "label" => "States", "url" => "/fba-prep-centers/" },
        { "label" => state["name"], "url" => url }
      ]
      graph = [breadcrumb_ld(site, crumbs), item_list(site, title, state["centers"])]
      GeneratedPage.new(site, url, "listing", {
        "title" => title,
        "h1" => title,
        "description" => description,
        "lede" => lede,
        "kind" => "state",
        "section" => "states",
        "centers" => state["centers"],
        "crumbs" => crumbs,
        "json_ld" => ld_graph(graph),
        "lastmod" => checked_iso
      })
    end

    def states_index_page(site, directory, checked_label, checked_iso)
      title = "FBA prep centers by state"
      url = "/fba-prep-centers/"
      description = "Browse #{directory['state_count']} US states with Amazon FBA prep centers. Public pages checked #{checked_label}."
      lede = "#{directory['center_count']} centers across #{directory['state_count']} states. Open a state to see the listings and whether the state came from the center's website or a third-party directory."
      crumbs = [
        { "label" => "Home", "url" => "/" },
        { "label" => "States", "url" => url }
      ]
      list = {
        "@type" => "ItemList",
        "name" => title,
        "numberOfItems" => directory["states"].size,
        "itemListElement" => directory["states"].each_with_index.map do |state, idx|
          {
            "@type" => "ListItem",
            "position" => idx + 1,
            "name" => state["name"],
            "url" => absolute(site, state["url"])
          }
        end
      }
      GeneratedPage.new(site, url, "listing", {
        "title" => title,
        "h1" => title,
        "description" => description,
        "lede" => lede,
        "kind" => "states",
        "section" => "states",
        "states" => directory["states"],
        "crumbs" => crumbs,
        "json_ld" => ld_graph([breadcrumb_ld(site, crumbs), list]),
        "lastmod" => checked_iso
      })
    end

    def service_page(site, service, checked_label, checked_iso)
      title = service["title"]
      url = service["url"]
      lede = "#{service['count']} centers mention #{service['name']} on their own websites."
      note = "A center appears here only when its own website mentions this service. If a center is missing, the check did not find a mention. That is not proof the center does not offer the service."
      description = "#{service['count']} prep centers whose websites mention #{service['name']}. Compiled from public pages checked #{checked_label}. A missing mention is unknown, not a no."
      crumbs = [
        { "label" => "Home", "url" => "/" },
        { "label" => "Services", "url" => "/services/" },
        { "label" => service["name"], "url" => url }
      ]
      GeneratedPage.new(site, url, "listing", {
        "title" => title,
        "h1" => title,
        "description" => description,
        "lede" => lede,
        "note" => note,
        "kind" => "service",
        "section" => "services",
        "centers" => service["centers"],
        "crumbs" => crumbs,
        "json_ld" => ld_graph([breadcrumb_ld(site, crumbs), item_list(site, title, service["centers"])]),
        "lastmod" => checked_iso
      })
    end

    def services_index_page(site, services, checked_label, checked_iso)
      title = "Prep center services"
      url = "/services/"
      description = "Services mentioned on prep center websites, including FBA prep, storage, fulfillment, and hazmat. Counts come from public pages checked #{checked_label}."
      lede = "Each page lists centers whose own websites mention that service. A center with no badge for a service was not found mentioning it. That is unknown, not a no."
      crumbs = [
        { "label" => "Home", "url" => "/" },
        { "label" => "Services", "url" => url }
      ]
      list = {
        "@type" => "ItemList",
        "name" => title,
        "numberOfItems" => services.size,
        "itemListElement" => services.each_with_index.map do |service, idx|
          {
            "@type" => "ListItem",
            "position" => idx + 1,
            "name" => service["title"],
            "url" => absolute(site, service["url"])
          }
        end
      }
      GeneratedPage.new(site, url, "listing", {
        "title" => title,
        "h1" => title,
        "description" => description,
        "lede" => lede,
        "kind" => "services-index",
        "section" => "services",
        "services" => services,
        "crumbs" => crumbs,
        "json_ld" => ld_graph([breadcrumb_ld(site, crumbs), list]),
        "lastmod" => checked_iso
      })
    end

    def tax_page(site, groups, checked_label, checked_iso)
      title = "Prep centers in states with no statewide sales tax"
      url = "/fba-prep-centers/sales-tax-free-states/"
      count = groups.sum { |g| g["count"] }
      names = groups.map { |g| g["name"] }
      lede = "#{count} listed centers are in #{join_names(names)}. The dataset flags a center when its filtering state is Delaware, Montana, New Hampshire, Oregon, or Alaska."
      description = "Prep centers in #{join_names(names)}, states with no general statewide sales tax. #{count} listings, checked #{checked_label}. Not tax advice."
      crumbs = [
        { "label" => "Home", "url" => "/" },
        { "label" => "States", "url" => "/fba-prep-centers/" },
        { "label" => "Sales-tax-free states", "url" => url }
      ]
      centers = groups.flat_map { |g| g["centers"] }
      GeneratedPage.new(site, url, "listing", {
        "title" => title,
        "h1" => title,
        "description" => description,
        "lede" => lede,
        "kind" => "tax",
        "section" => "tax",
        "groups" => groups,
        "crumbs" => crumbs,
        "json_ld" => ld_graph([breadcrumb_ld(site, crumbs), item_list(site, title, centers)]),
        "lastmod" => checked_iso
      })
    end

    def update_home(site, directory)
      home = site.pages.find { |page| page.data["section"] == "home" }
      return unless home
      count = directory["center_count"]
      states = directory["state_count"]
      label = directory["checked_label"]
      home.data["title"] = "#{count} Amazon FBA prep centers in the US"
      home.data["description"] = "Directory of #{count} Amazon FBA prep centers in #{states} US states. Search by name, state, and service. Listings are compiled from each center's public website, checked #{label}."
      home.data["lastmod"] = directory["checked_iso"]
      home.data["json_ld"] = JSON.generate(
        "@context" => "https://schema.org",
        "@type" => "WebSite",
        "name" => site.config["title"],
        "url" => absolute(site, "/"),
        "description" => home.data["description"],
        "potentialAction" => {
          "@type" => "SearchAction",
          "target" => "#{site.config['url'].to_s.sub(%r{/\z}, '')}/?q={search_term_string}",
          "query-input" => "required name=search_term_string"
        }
      ).gsub("<", "\\u003c")
    end

    def warn_formspree(site)
      endpoint = site.config["formspree_endpoint"].to_s
      return unless endpoint.include?("REPLACE_ME")
      Jekyll.logger.warn "Directory:", "FORMSPREE_ENDPOINT is still the placeholder https://formspree.io/f/REPLACE_ME. Update formspree_endpoint in _config.yml before launch."
    end

    def sitemap_entries(site, checked_iso)
      site.pages.filter_map do |page|
        next if page.data["sitemap"] == false
        url = page.url.to_s
        next unless url.end_with?("/")
        [absolute(site, url), page.data["lastmod"] || checked_iso]
      end.uniq { |loc, _| loc }.sort_by(&:first)
    end

    def sitemap_xml(entries)
      body = +%(<?xml version="1.0" encoding="UTF-8"?>\n)
      body << %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
      entries.each do |loc, lastmod|
        body << "  <url>\n"
        body << "    <loc>#{xml_escape(loc)}</loc>\n"
        body << "    <lastmod>#{xml_escape(lastmod)}</lastmod>\n"
        body << "  </url>\n"
      end
      body << "</urlset>\n"
      body
    end

    def search_json(centers)
      JSON.generate(
        "centers" => centers.map do |center|
          {
            "name" => center["name"],
            "url" => center["url"],
            "state" => center["state_code"].to_s,
            "services" => center["service_slugs"].to_s.split,
            "search" => center["search"]
          }
        end
      )
    end

    def raw_page(site, permalink, content)
      GeneratedPage.new(site, permalink, "none", {
        "sitemap" => false,
        "render_with_liquid" => false
      }, content)
    end

    def local_business(site, center)
      data = {
        "@type" => "LocalBusiness",
        "@id" => absolute(site, center["url"]),
        "name" => center["name"]
      }
      data["url"] = center["website"] if center["website"]
      phones = center["phones"].map { |phone| phone["text"] }
      data["telephone"] = phones.size == 1 ? phones.first : phones if phones.any?
      emails = center["emails"].map { |email| email["text"] }
      data["email"] = emails.size == 1 ? emails.first : emails if emails.any?
      if center["show_address"]
        data["address"] = {
          "@type" => "PostalAddress",
          "addressLocality" => center["hq_city"],
          "addressRegion" => center["hq_state"],
          "addressCountry" => "US"
        }
      elsif center["state_basis"] == "own site" && center["state_code"]
        data["address"] = {
          "@type" => "PostalAddress",
          "addressRegion" => center["state_code"],
          "addressCountry" => "US"
        }
      end
      data
    end

    def item_list(site, name, centers)
      {
        "@type" => "ItemList",
        "name" => name,
        "numberOfItems" => centers.size,
        "itemListElement" => centers.each_with_index.map do |center, idx|
          {
            "@type" => "ListItem",
            "position" => idx + 1,
            "name" => center["name"],
            "url" => absolute(site, center["url"])
          }
        end
      }
    end

    def breadcrumb_ld(site, crumbs)
      {
        "@type" => "BreadcrumbList",
        "itemListElement" => crumbs.each_with_index.map do |crumb, idx|
          {
            "@type" => "ListItem",
            "position" => idx + 1,
            "name" => crumb["label"],
            "item" => absolute(site, crumb["url"])
          }
        end
      }
    end

    def ld_graph(nodes)
      JSON.generate("@context" => "https://schema.org", "@graph" => nodes).gsub("<", "\\u003c")
    end

    def absolute(site, path)
      base = site.config["url"].to_s.sub(%r{/\z}, "")
      return "#{base}/" if path.nil? || path == "/"
      "#{base}#{path}"
    end

    def emails_for(raw)
      seen = {}
      raw.to_s.split(/[;,]/).filter_map do |part|
        token = part.strip.gsub(/\A(?:%20)+/i, "").gsub(/(?:%20)+\z/i, "").strip
        token = token.sub(/\Amailto:/i, "")
        next unless token.match?(EMAIL_RE)
        key = token.downcase
        next if seen[key]
        seen[key] = true
        { "text" => token, "href" => "mailto:#{token}" }
      end
    end

    def phones_for(raw)
      seen = {}
      raw.to_s.split(";").filter_map do |part|
        text = part.strip
        next if text.empty? || seen[text]
        seen[text] = true
        digits = text.gsub(/[^\d+]/, "")
        href = digits.match?(/\d/) ? "tel:#{digits}" : nil
        { "text" => text, "href" => href }
      end
    end

    def excerpts_for(row)
      EXCERPT_FIELDS.flat_map do |text_key, url_key, label|
        raw = present(row[text_key])
        next [] unless raw
        source = http_url(row[url_key])
        parts = raw.split(" ; ").map(&:strip).reject(&:empty?)
        parts = [raw] if parts.empty?
        parts.map { |part| { "label" => label, "text" => part, "source_url" => source } }
      end
    end

    def software_for(raw)
      raw.to_s.split(";").map(&:strip).reject(&:empty?).uniq
    end

    def warehouse_names(raw)
      codes = raw.to_s.split(";").map(&:strip).reject(&:empty?).uniq
      return [] if codes.size < 2
      codes.map { |code| STATES[code] || code }
    end

    def sources_for(row)
      bucket = {}
      add = lambda do |url, label|
        clean = http_url(url)
        return unless clean
        bucket[clean] ||= []
        bucket[clean] << label unless bucket[clean].include?(label)
      end
      services = present(row["services_source_urls"])
      services.to_s.split(/\s+/).each { |url| add.call(url, "Services") } if services
      add.call(row["address_source_url"], "Location")
      add.call(row["contact_source_url"], "Contact")
      add.call(row["pricing_source_url"], "Unit pricing")
      add.call(row["minimum_source_url"], "Minimums")
      add.call(row["setup_source_url"], "Setup fee")
      add.call(row["turnaround_source_url"], "Turnaround")
      bucket.map do |url, labels|
        { "url" => url, "label" => "#{labels.join(', ')} — #{display_url(url)}" }
      end
    end

    def http_url(value)
      url = present(value)
      return nil unless url&.start_with?("http://", "https://")
      url
    end

    def present(value)
      text = value.to_s.strip
      text.empty? ? nil : text
    end

    def display_url(url)
      url.to_s.sub(%r{\Ahttps?://}i, "").sub(%r{/\z}, "")
    end

    def slugify(text)
      text.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def date_label(iso)
      Date.strptime(iso, "%Y-%m-%d").strftime("%B %-d, %Y")
    rescue ArgumentError
      iso.to_s
    end

    def join_names(names)
      return "" if names.empty?
      return names.first if names.size == 1
      return "#{names[0]} and #{names[1]}" if names.size == 2
      "#{names[0..-2].join(', ')}, and #{names[-1]}"
    end

    def xml_escape(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
    end
  end
end

module Jekyll
  class DirectoryGenerator < Generator
    priority :lowest
    safe true

    def generate(site)
      FBAPrepList.build(site)
    end
  end
end
