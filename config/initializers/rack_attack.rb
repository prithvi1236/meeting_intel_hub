class Rack::Attack
  throttle("chat/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path.match?(%r{/chat_messages}) && req.post?
  end

  throttle("uploads/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.match?(%r{/transcripts}) && req.post?
  end
end

Rails.application.config.middleware.use Rack::Attack
