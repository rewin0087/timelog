require "net/http"

# Minimal client for the FuelIX OpenAI-compatible chat completions API.
# Mirrors FuelixService in ai_sourcing_app, using Net::HTTP instead of Faraday.
# Settings come from ENV (FUELIX_API_KEY, FUELIX_API_URL, FUELIX_MODEL), loaded from .env in development.
class FuelixClient
  class Error < StandardError; end

  DEFAULT_URL = "https://api.fuelix.ai"
  DEFAULT_MODEL = "claude-sonnet-4-6"

  def self.configured? = ENV["FUELIX_API_KEY"].present?

  def initialize(api_key: ENV["FUELIX_API_KEY"], base_url: ENV.fetch("FUELIX_API_URL", DEFAULT_URL), model: ENV.fetch("FUELIX_MODEL", DEFAULT_MODEL))
    @api_key, @base_url, @model = api_key, base_url, model
  end

  def complete(prompt, system: nil, temperature: 0.7, max_tokens: 2048, timeout: 45)
    messages = []
    messages << { role: "system", content: system } if system
    messages << { role: "user", content: prompt }

    body = post({ model: @model, messages:, temperature:, max_tokens: }, timeout:)
    body.dig("choices", 0, "message", "content") || body.dig("choices", 0, "text") || raise(Error, "No content in FuelIX response")
  end

  # One chat completions turn with optional OpenAI-style function tools. Returns the assistant message
  # as a Hash ("content", and "tool_calls" when the model wants tools run).
  def chat(messages, tools: nil, temperature: 0.3, max_tokens: 2048, timeout: 90)
    payload = { model: @model, messages:, temperature:, max_tokens: }
    payload[:tools] = tools if tools.present?
    post(payload, timeout:).dig("choices", 0, "message") || raise(Error, "No message in FuelIX response")
  end

  # Asks for JSON and parses the first object in the reply (tolerates ```json fences).
  def complete_json(prompt, **options)
    raw = complete(prompt, **options)
    json = raw.gsub(/```(?:json)?/i, "")[/\{.*\}/m] or raise Error, "No JSON object in FuelIX response"
    JSON.parse(json)
  rescue JSON::ParserError => e
    raise Error, "FuelIX returned invalid JSON: #{e.message}"
  end

  private

  def post(payload, timeout:)
    raise Error, "FUELIX_API_KEY is not set" if @api_key.blank?

    uri = URI.join(@base_url, "/v1/chat/completions")
    request = Net::HTTP::Post.new(uri, "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json")
    request.body = payload.to_json

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: timeout) { |http| http.request(request) }
    Rails.logger.info("[FuelixClient] model=#{@model} status=#{response.code} elapsed=#{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(2)}s")

    raise Error, "FuelIX API error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
    raise Error, "FuelIX request failed: #{e.class}: #{e.message}"
  end
end
