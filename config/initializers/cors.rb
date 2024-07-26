# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
	  origins ['http://localhost:8080', 'https://qa.blubirch.com:3780', 'https://croma.blubirch.com', 'https://croma-prod-api.blubirch.com', 'https://croma-api.blubirch.com', 'https://croma-uat.blubirch.com', 'https://qa-test.blubirch.com', 'https://qa-test.blubirch.com:3000']
    
      resource '*',
      headers: :any,
      credentials:true ,
      expose: %w(Authorization),
      methods: :any
  end
end
