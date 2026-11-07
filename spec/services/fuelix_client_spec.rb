require "rails_helper"

RSpec.describe FuelixClient do
  subject(:client) { described_class.new(api_key: "test-key", base_url: "https://api.fuelix.ai", model: "test-model") }

  it "is configured only when an API key is set" do
    expect(described_class.configured?).to be(false)
    with_fuelix_key { expect(described_class.configured?).to be(true) }
  end

  it "raises without an API key" do
    expect { described_class.new(api_key: nil).complete("hi") }.to raise_error(FuelixClient::Error, /not set/)
  end

  it "posts the prompt with the key and model and returns the content" do
    stub = stub_fuelix(content: "Hello").with(
      headers: { "Authorization" => "Bearer test-key" },
      body: hash_including("model" => "test-model", "messages" => [ { "role" => "system", "content" => "sys" }, { "role" => "user", "content" => "hi" } ])
    )
    expect(client.complete("hi", system: "sys")).to eq("Hello")
    expect(stub).to have_been_requested
  end

  it "raises on an HTTP error" do
    stub_fuelix(status: 500, body: "{}")
    expect { client.complete("hi") }.to raise_error(FuelixClient::Error, /500/)
  end

  it "raises on network failures" do
    stub_request(:post, FuelixHelpers::FUELIX_URL).to_timeout
    expect { client.complete("hi") }.to raise_error(FuelixClient::Error, /request failed/)
  end

  it "raises when the reply has no content" do
    stub_fuelix(body: { choices: [] }.to_json)
    expect { client.complete("hi") }.to raise_error(FuelixClient::Error, /No content/)
  end

  describe "#complete_json" do
    it "parses JSON even inside a markdown fence" do
      stub_fuelix(content: "Sure!\n```json\n{\"a\":1}\n```")
      expect(client.complete_json("hi")).to eq("a" => 1)
    end

    it "raises when there is no JSON object" do
      stub_fuelix(content: "no json here")
      expect { client.complete_json("hi") }.to raise_error(FuelixClient::Error, /No JSON/)
    end

    it "raises on invalid JSON" do
      stub_fuelix(content: "{not json}")
      expect { client.complete_json("hi") }.to raise_error(FuelixClient::Error, /invalid JSON/)
    end
  end
end
