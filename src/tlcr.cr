require "http/client"
require "json"
require "pg"

require "./tlcr/*"

module Tlcr
  struct Command
    JSON.mapping(
      name: String,
      platform: Set(String)
    )

    def namespace
      @namespace ||= platform.includes?("linux") ? "linux" : "common"
    end

    def content
      @content ||= File.read(File.join("tldr", "pages", namespace, "#{name}.md"))
    end

    def url
      @url ||= "https://tldr.ostera.io/#{namespace}/#{name}"
    end

    def description
      content.scan(/>\s(.*)/).map(&.try(&.[1])).join(" ")
    end
  end

  struct Index
    JSON.mapping(commands: Set(Command))
  end

  PG_DB = DB.open(ENV["DB_URL"])

  res = HTTP::Client.get("https://tldr.sh/assets/index.json")
  commands = Index.from_json(res.body)
                  .commands.select(&.platform.subset?(Set{"linux", "common"}))

  commands.each do |command|
    cmd = [
      command.name,
      command.namespace,
      command.description,
      command.content,
      command.url
    ]

    query = <<-SQL
      insert into man_pages (name, platform, description, content, url)
           values ($1, $2, $3, $4, $5)
    SQL

    PG_DB.exec(query, cmd)
  end
end
