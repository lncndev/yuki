require "http/client"
require "json"
require "file_utils"
require "clim"

module Yuki
  class Cli < Clim
    main do
      desc "Yuki: Grab and set random anime wallpapers"
      usage "yuki [search] [options]"
      option "-t TAGS", "--tags TAGS", type: String, desc: "Tags to search for (separate tags with a single space, separate searches with a single comma)", default: "nagato_yuki"
      option "-s", "--safe", type: Bool, desc: "Safe results only"
      option "-q", "--questionable", type: Bool, desc: "Safe and questionable results only"
      option "-r", "--recent", type: Bool, desc: "Choose from recent posts rather than specifying tags"
      option "--style", type: String, desc: "Scale style: scale, fill, max, tile, center", default: "fill"

      run do |opts, args|
        tags = Danbooru.choose_random_search(opts.tags)

        Danbooru.get_results_for(tags, opts.recent) do |results|
          Danbooru.cleanse_results(results, if opts.safe; "s"; elsif opts.questionable; "q"; else; "e" end) do |results|
            Danbooru.get_random_from(results) do |post|
              FileUtils.cd("/home/" + ENV["USER"] + "/.yuki") do
                File.write("wallpaper." + post["file_ext"].to_s, HTTP::Client.get(post["large_file_url"]).body.to_s)
                File.write("CURRENT_WALLPAPER", post["id"])
                Process.run("feh --bg-" + opts.style.to_s + " wallpaper." + post["file_ext"], shell: true)
              end
            end
          end
        end
      end

      sub "current" do
        desc "Get the URL for the current wallpaper"

        run do
          FileUtils.cd("/home/" + ENV["USER"] + "/.yuki") do
            puts "Current wallpaper: https://danbooru.donmai.us/posts/" + File.read("CURRENT_WALLPAPER")
          end
        end
      end
    end
  end

  class Danbooru
    def self.get_results_for(tags : String, recent : Bool, &block)
      if recent
        raw_results = HTTP::Client.get("https://danbooru.donmai.us/posts.json?limit=30").body.to_s
      else
        tags = tags.gsub(" ", "+")
        raw_results = HTTP::Client.get("https://danbooru.donmai.us/posts.json?limit=30&tags=" + tags).body.to_s
      end

      json_results = JSON.parse(raw_results)
      results = Array(NamedTuple(large_file_url: String, file_ext: String, rating: String, id: Int32)).from_json(raw_results)

      yield results
    end

    def self.cleanse_results(results, rating : String, &block)
      results.each do |result|
        case result["rating"]
        when "q"
          if rating == "s"
            results.delete(result)
          end
        when "e"
          if rating == "q" || rating == "s"
            results.delete(result)
          end
        end
      end

      yield results
    end

    def self.get_random_from(posts : Array, &block)
      rndnum = Random.new.rand(posts.size)
      post = posts[rndnum]
      yield post
    end

    def self.choose_random_search(searches : String)
      searches = searches.split(",")
      rndnum = Random.new.rand(searches.size)
      search = searches[rndnum]
      return search
    end
  end
end

Yuki::Cli.start(ARGV)