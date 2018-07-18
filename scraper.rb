#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  PARTIES = {
    'PAP' => 'Q371395',
    'WP'  => 'Q2299911',
  }.freeze

  field :members do
    member_rows.map { |p| fragment(p => MembersRow) }.flat_map do |row|
      h = row.to_h
      h.delete(:members).map { |mem| mem.merge(h).merge(party_wikidata: PARTIES[h[:party]]) }
    end
  end

  private

  def member_rows
    noko.css('.navbox-columns-table table').xpath('.//tr[.//th[@class="navbox-group"]]')
  end
end

class MembersRow < Scraped::HTML
  field :party do
    noko.css('th sup').text
  end

  field :constituency do
    constituency_link.text
  end

  field :constituency_wikidata do
    constituency_link.attr('wikidata').text
  end

  field :members do
    noko.css('td ul li').map { |li| fragment(li => MemberNode) }.map(&:to_h)
  end

  private

  def constituency_link
    noko.css('th a')
  end
end

class MemberNode < Scraped::HTML
  field :name do
    name_link.text.tidy
  end

  field :wikidata do
    name_link.attr('wikidata')
  end

  private

  def name_link
    noko.css('a').first
  end
end

url = 'https://en.wikipedia.org/wiki/Template:Singapore_Parliament_2016'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name constituency_wikidata])
