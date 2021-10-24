require "http/client"
require "json"
require "file_utils"
require "clim"

module Yuki
  class Cli < Clim
    main do
      desc "Yuki: Grab and set random anime wallpapers"
      usage "yuki [search] [options]"
      option "-t TAGS", "--tags TAGS", type: String, desc: "Tags to search for (separate tags with a single space, separate searches with a single comma)", required: false
      option "-s", "--safe", type: Bool, desc: "Safe results only"
      option "-q", "--questionable", type: Bool, desc: "Safe and questionable results only"
      option "-r", "--recent", type: Bool, desc: "Choose from recent posts rather than specifying tags"
      option "--style", type: String, desc: "Scale style: scale, fill, max, tile, center", default: "fill"

      run do |opts, args|
        tags : String = FileUtils.cd("/home/" + ENV["USER"] + "/.yuki") do
          if opts.tags.to_s.empty? != true
            Danbooru.choose_random_search(opts.tags.to_s.split(",")).to_s
          elsif File.read("TAGS").to_s.empty? != true
            Danbooru.choose_random_search(File.read("TAGS").to_s.split("\n")).to_s
          else
            "yuki_nagato"
          end
        end

        puts "Finding image for \"" + tags + "\""

        Danbooru.get_results_for(tags, opts.recent) do |results|
          Danbooru.cleanse_results(results, if opts.safe == true; "s"; elsif opts.questionable == true; "q"; else; "e" end) do |results|
            Danbooru.get_random_from(results) do |post|
              FileUtils.cd("/home/" + ENV["USER"] + "/.yuki") do
                File.write("wallpaper." + post["file_ext"].to_s, HTTP::Client.get(post["file_url"]?.to_s).body.to_s)
                File.write("CURRENT_WALLPAPER", post["id"]?)
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
            puts "\nCurrent wallpaper: https://danbooru.donmai.us/posts/" + File.read("CURRENT_WALLPAPER").to_s + "\n"
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
      results = Array(NamedTuple(large_file_url: String | Nil, file_url: String | Nil, file_ext: String, rating: String, id: Int32 | String | Nil)).from_json(raw_results)

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

    def self.choose_random_search(searches : Array)
      searches.delete("")

      begin
        rndnum = Random.new.rand(searches.size)
        search = searches[rndnum]
        return search
      rescue
        rndnum = Random.new.rand(searches.size)
        search = searches[rndnum]
        return search
      end
    end
  end
end

Yuki::Cli.start(ARGV)