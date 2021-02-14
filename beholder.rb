require 'json'
require 'net/http'
require 'date'

class Beholder
  attr_reader :bearer_token, :instance, :attempted_instances, :limit, :last_id, :filename

  def initialize(filename)
    @filename = filename
    f = File.open("info.json", "r")
    @info = JSON.parse(f.read)
    f.close

    extract_to_instance_variable(variable: "bearer_token")
    extract_to_instance_variable(variable: "instance")
    extract_to_instance_variable(variable: "attempted_instances", required: false, default: [])
    extract_to_instance_variable(variable: "limit", required: false, default: 20)
    extract_to_instance_variable(variable: "last_id", required: false)

    @instance.downcase!
    @last_id_time = 0
  end

  def start
    while true
      @update_info_needed = false
      instances = []
      next_posts.each do |np|
        instances += instances_to_check(np)
        update_last_id(np)
      end

      instances.reject! { |instance| instance.nil? }
      instances.collect! { |instance| instance.downcase }
      instances.uniq!

      instances.each { |inst| consider_instance(inst) }

      update_info if @update_info_needed

      unless @update_info_needed
        log "Sleeping for a minute..."
        sleep 60
      end
    end
  end

  private

  def log(val)
    puts "[#{Time.now.to_s}] #{val}"
  end

  def update_info
    log "Updating info"
    f = File.open(@filename, "w")
    f.write(JSON.pretty_generate(@info))
    f.close
  end


  def consider_instance(instance)
    return if attempted_instances.include?(instance) or instance == @instance

    log "Attempting To Create Relay With New Instance: #{instance}"

    uri = URI.parse("https://#{@instance}/api/pleroma/admin/relay")
    header = {'Content-Type': 'application/json', 'Authorization': "Bearer #{bearer_token}"}
    params = { 'relay_url': "https://#{instance}/relay" }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new(uri.request_uri, header)
    req.body = params.to_json

    res = http.request(req)

    puts res.body

    attempted_instances.push(instance)
    @info["attempted_instances"].push(instance)
    @info["attempted_instances"].uniq!
    @update_info_needed = true
  end

  def extract_to_instance_variable(variable:, required: true, default: nil)
    throw "#{variable} is required but not found in JSON info file" if required and not @info.has_key?(variable)

    self.instance_variable_set("@#{variable}".to_sym, @info.has_key?(variable) ? @info[variable] : default)
  end

  def next_posts
    uri = URI.parse("https://#{instance}/api/v1/timelines/public/")
    header = {'Content-Type': 'application/json', 'Authorization': "Bearer #{bearer_token}"}
    params = { 'remote': true }
    params['since_id'] = last_id unless last_id.nil?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Get.new(uri.request_uri, header)
    req.body = params.to_json

    res = http.request(req)

    begin
      JSON.parse(res.body)
    rescue
      []
    end
  end

  def instances_to_check(post)
    post["mentions"].collect { |mention| instance_from_acct(mention["acct"]) } + [instance_from_acct(post["account"]["fqn"])]
  end

  def instance_from_acct(acct)
    acct.split("@")[1]
  end

  def update_last_id(post)
    current = DateTime.parse(post["created_at"]).to_time.to_i
    return if current <= @last_id_time

    @last_id_time = current
    @info["last_id"] = @last_id = post["id"]

    log "Newest post ID is #{last_id}"

    @update_info_needed = true
  end
end

throw "No info file found" if !File.exist?("info.json")

beholder = Beholder.new("info.json")

beholder.start
