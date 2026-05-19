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

    base_version       = File.basename(monolithic).match(/\A(\d{14})/)[1].to_i
    monolithic_content = File.read(monolithic)
    template_dir       = Trackguard::Engine.root.join("lib", "generators", "trackguard", "templates")
    conn               = ActiveRecord::Base.connection

    splits = [
      [ base_version,     "create_trackguard_visitors",            "trackguard_visitors" ],
      [ base_version + 1, "create_trackguard_visits",              "trackguard_visits" ],
      [ base_version + 2, "create_trackguard_whitelisted_ips",     "trackguard_whitelisted_ips" ],
      [ base_version + 3, "create_trackguard_blocked_user_agents", "trackguard_blocked_user_agents" ],
      [ base_version + 4, "create_trackguard_blocked_paths",       "trackguard_blocked_paths" ]
    ]

    # Only inject entries for tables the monolithic actually created.
    # Tables absent from it are left for `rails generate trackguard:install` + `db:migrate`.
    to_inject, to_defer = splits.partition { |_, _, table| monolithic_content.include?("create_table :#{table}") }

    new_versions = to_inject.map { |ts, _, _| ts }.reject { |ts| ts == base_version }
    create_list  = to_inject.map { |ts, name, _| "  db/migrate/#{ts}_#{name}.rb" }.join("\n")

    puts "This will make the following changes to your application:"
    puts ""
    puts "  Remove:  db/migrate/#{File.basename(monolithic)}"
    puts "  Create:"
    puts create_list
    puts ""
    puts "  Update schema_migrations: add versions #{new_versions.join(', ')}" if new_versions.any?
    puts "  Update db/schema.rb if its version points at #{base_version}"
    if to_defer.any?
      puts ""
      puts "  Not in monolithic — deferred to install generator + db:migrate:"
      to_defer.each { |_, name, _| puts "    #{name}" }
    end
    puts ""
    puts "  Tables themselves are NOT touched. Bookkeeping only."
    puts ""

    $stdout.print "Proceed? [y/N] "
    input = $stdin.gets.to_s.strip.downcase
    unless input == "y"
      puts "Aborted."
      next
    end

    puts ""

    sm_insert = lambda do |v|
      quoted = conn.quote(v.to_s)
      unless conn.select_value("SELECT 1 FROM schema_migrations WHERE version = #{quoted}")
        conn.execute("INSERT INTO schema_migrations (version) VALUES (#{quoted})")
      end
    end

    last_injected = base_version

    to_inject.each do |ts, name, _|
      path = migrate_dir.join("#{ts}_#{name}.rb")
      if path.exist?
        puts "  skip   #{path.basename}"
      else
        content = ERB.new(File.read(template_dir.join("#{name}.rb"))).result(binding)
        path.write(content)
        puts "  create #{path.basename}"
      end
      sm_insert.call(ts)
      last_injected = ts
    end

    FileUtils.rm(monolithic)
    puts "  remove #{File.basename(monolithic)}"
    # base_version stays in schema_migrations — it now belongs to create_trackguard_visitors

    schema_path = Rails.root.join("db", "schema.rb")
    if schema_path.exist? && last_injected != base_version
      schema_content = schema_path.read
      if schema_content.include?("version: #{base_version}")
        schema_path.write(schema_content.sub("version: #{base_version}", "version: #{last_injected}"))
        puts "  update db/schema.rb: version #{base_version} → #{last_injected}"
      end
    end

    if to_defer.any?
      puts "\nRun `rails generate trackguard:install && rails db:migrate` to create the remaining tables."
    end
    puts "\nDone. Run `rails db:migrate:status` to verify."
  end
end
