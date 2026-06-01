if Trackguard.adapter.is_a?(Trackguard::Adapters::Local)
  pin_all_from File.expand_path("../app/assets/javascripts/controllers", __dir__), under: "controllers"
end
