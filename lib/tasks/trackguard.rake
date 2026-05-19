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

  desc "Seed default blocked path patterns into trackguard_blocked_paths"
  task seed_blocked_paths: :environment do
    patterns = [
      # WordPress
      "wp-login.php", "wp-admin", "wp-config.php", "xmlrpc.php",
      # Other CMS admin panels
      "/administrator", "/typo3/",
      # PHP shells & backdoors
      "shell.php", "cmd.php", "c99.php", "r57.php", "webshell", "backdoor.php",
      # Environment & config leaks
      "/.env", "/web.config",
      "phpinfo.php", "info.php", "test.php",
      # Database admin tools
      "/phpmyadmin", "/pma/", "/myadmin", "adminer.php",
      # Source control leaks
      "/.git/config", "/.git/HEAD", "/.svn/",
      # Cloud credential leaks
      "/.aws/credentials",
      # Spring Boot / Java actuator
      "/actuator/env", "/actuator/mappings", "/solr/admin/"
    ]

    inserted = patterns.count do |p|
      Trackguard::BlockedPath.find_or_create_by!(pattern: p).previously_new_record?
    end

    puts "Done: #{inserted} inserted, #{patterns.size - inserted} already existed " \
         "(#{Trackguard::BlockedPath.count} total)"
  end

  desc "Replace the monolithic create_trackguard_tables migration with individual per-table migrations"
  task cleanup_monolithic_migration: :environment do
    require "erb"

    migrate_dir  = Rails.root.join("db", "migrate")
    monolithic   = Dir[migrate_dir.join("*_create_trackguard_tables.rb")].first

    unless monolithic
      puts "No create_trackguard_tables migration found — nothing to do."
      next
    end

    base_version = File.basename(monolithic).match(/\A(\d{14})/)[1].to_i
    template_dir = Trackguard::Engine.root.join("lib", "generators", "trackguard", "templates")

    splits = [
      [ base_version,     "create_trackguard_visitors" ],
      [ base_version + 1, "create_trackguard_visits" ],
      [ base_version + 2, "create_trackguard_whitelisted_ips" ],
      [ base_version + 3, "create_trackguard_blocked_user_agents" ],
      [ base_version + 4, "create_trackguard_blocked_paths" ]
    ]

    create_list = splits.map { |ts, name| "  db/migrate/#{ts}_#{name}.rb" }.join("\n")

    puts "This will make the following changes to your application:"
    puts ""
    puts "  Remove:  db/migrate/#{File.basename(monolithic)}"
    puts "  Create (table/index creation guarded with if_not_exists):"
    puts create_list
    puts ""
    puts "  Run `rails db:migrate` afterwards — existing tables and indexes are skipped safely."
    puts ""

    $stdout.print "Proceed? [y/N] "
    input = $stdin.gets.to_s.strip.downcase
    unless input == "y"
      puts "Aborted."
      next
    end

    puts ""

    splits.each do |ts, name|
      path = migrate_dir.join("#{ts}_#{name}.rb")
      if path.exist?
        puts "  skip   #{path.basename}"
      else
        raw = ERB.new(File.read(template_dir.join("#{name}.rb"))).result(binding)
        guarded = raw
                  .gsub(/create_table (\S+) do/, 'create_table \1, if_not_exists: true do')
                  .gsub(/^(\s+add_index .+)$/, '\1, if_not_exists: true')
        path.write(guarded)
        puts "  create #{path.basename}"
      end
    end

    FileUtils.rm(monolithic)
    puts "  remove #{File.basename(monolithic)}"

    puts "\nDone. Run `rails db:migrate` to apply any missing migrations."
  end
end
