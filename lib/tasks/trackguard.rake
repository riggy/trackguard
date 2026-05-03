namespace :trackguard do
  desc "Seed default blocked user agent patterns into trackguard_blocked_user_agents"
  task seed_blocked_user_agents: :environment do
    patterns = [
      # Generic scanners & vulnerability tools
      "masscan", "zgrab", "nmap", "nikto", "sqlmap", "nuclei",
      "gobuster", "dirbuster", "wfuzz", "ffuf", "burpsuite",
      "acunetix", "nessus", "openvas", "w3af", "skipfish", "arachni",
      # Search engine crawlers
      "googleother", "googlebot", "bingbot",
      # SEO & data harvesting bots
      "semrushbot", "ahrefsbot", "mj12bot", "dotbot", "blexbot",
      "petalbot", "bytespider", "claudebot", "gptbot", "ccbot",
      # Headless/automation browsers
      "headlesschrome", "phantomjs",
      # Generic scraper/crawler signals
      "scrapy", "python-requests", "go-http-client", "okhttp",
      "curl/", "wget/",
      # Old/legacy clients
      "konqueror/4", "jakarta", "java/",
      # Other
      "fasthttp", "palo alto", "cortex xpanse"
    ]

    inserted = patterns.count do |p|
      Trackguard::BlockedUserAgent.find_or_create_by!(pattern: p).previously_new_record?
    end

    puts "Done: #{inserted} inserted, #{patterns.size - inserted} already existed " \
         "(#{Trackguard::BlockedUserAgent.count} total)"
  end
end
