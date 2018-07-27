require "spec_helper"
require "bridger/rel_builder"

RSpec.describe Bridger::RelBuilder do
  context "templated URI and no params" do
    it "has templated URI" do
      subject = described_class.new(
        :foo,
        :get,
        "/shops/:shop_id/products/:id"
      )

      rel = subject.build

      expect(rel.path).to eq "/shops/{shop_id}/products/{id}"
      expect(rel.templated?).to be true
    end
  end

  context "templated URI and params" do
    it "has templated URI, query fields and no params" do
      described_class.domain = 'btc'
      subject = described_class.new(
        :foo,
        :get,
        "/shops/:shop_id/products/:id",
        [:foo, :bar]
      )

      rel = subject.build

      expect(rel.name).to eq "btc:foo"
      expect(rel.path).to eq "/shops/{shop_id}/products/{id}{?foo,bar}"
      expect(rel.templated?).to be true
    end
  end

  context "templated URI and partial params" do
    it "has templated URI" do
      subject = described_class.new(
        :foo,
        :get,
        "/shops/:shop_id/products/:id"
      )

      rel = subject.build(shop_id: 123)

      expect(rel.path).to eq "/shops/123/products/{id}"
      expect(rel.templated?).to be true
    end
  end

  context "templated URI, query fields and partial params" do
    it "has templated URI" do
      subject = described_class.new(
        :foo,
        :get,
        "/shops/:shop_id/products/:id",
        [:foo, :bar, :la]
      )

      rel = subject.build(shop_id: 123, foo: "22")

      expect(rel.path).to eq "/shops/123/products/{id}?foo=22{&bar,la}"
      expect(rel.templated?).to be true
    end
  end

  context "duplicated params" do
    it "does not duplicate them" do
      subject = described_class.new(
        :foo,
        :get,
        "/shops/:shop_id/products/:id",
        [:shop_id, :foo, :bar, :la]
      )

      rel = subject.build(shop_id: 123, foo: "22")

      expect(rel.path).to eq "/shops/123/products/{id}?foo=22{&bar,la}"
      expect(rel.templated?).to be true
    end
  end

  context "all tokens are provided" do
    it "is not templated" do
      subject = described_class.new(
        :foo,
        :get,
        "/shops/:shop_id/products/:id",
        [:foo, :bar, :la]
      )

      rel = subject.build(shop_id: 11, id: 22, foo: "33", bar: "44", la: "55", noop: "nope")

      expect(rel.path).to eq "/shops/11/products/22?foo=33&bar=44&la=55"
      expect(rel.templated?).to be false
    end
  end
end
