class Command
  class Options
    DEFAULT = {
      keys: [],
      data: {},
      flat: false,
      position: nil
    }

    def self.parse(argv = {})
      options = DEFAULT.dup
      parser(options).parse!(argv)
      options
    end

    def self.parser(options = {})
      OptionParser.new do |p|
        p.banner = <<-BANNER
omise console

the following commands are available:
    display this screen:   help
    create an object:      post   /path [key=value,...] [options]
    retrieve an object:    get    /path [key=value,...] [options]
    update an object:      patch  /path [key=value,...] [options]
    destroy and object:    delete /path [key=value,...] [options]
        BANNER

        p.separator ""
        p.separator "common options:"

        p.on("-f", "--flat", "flatten the list and/or object(s)") do
          options[:flat] = true
        end

        p.on("-k", "--keys KEYS", Array, "extract KEYS from the list and/or object(s)") do |keys|
          options[:keys] = keys
        end

        p.on("-n", "--newest", "return the newest element of the list") do
          options[:position] = :newest
        end

        p.on("-o", "--oldest", "return the oldest element of the list") do
          options[:position] = :oldest
        end

        p.on("-i INDEX", Integer, "take the element at position INDEX of the list (0 based)") do |index|
          options[:position] = index
        end
      end
    end
  end

  def initialize(key, options)
    @key = key
    @options = options
  end

  def help(argv)
    Command::Options.parser
  end

  def post(argv)
    path = argv.shift
    args, attrs = extract_args_and_attrs(argv)

    object = resource(path).post(attrs)
  end

  # TODO fix omise-ruby to allow extra attrs in Omise::Resource#get
  def get(argv)
    path = argv.shift
    args, attrs = extract_args_and_attrs(argv)

    object = resource(path).get
    pretty(flatten(pos(filter(object))))
  end

  def patch(argv)
    path = argv.shift
    args, attrs = extract_args_and_attrs(argv)

    object = resource(path).patch(attrs)
  end

  def delete(argv)
    path = argv.shift
    args, attrs = extract_args_and_attrs(argv)

    object = resource(path).delete(attrs)
  end

  private

  attr_reader :key

  def resource(path)
    Omise::Resource.new(Omise.api_url, path, key)
  end

  def pos(object)
    return object unless position

    if object.is_a?(Hash) && object["object"] == "list"
      return pos(object["data"])
    end

    if object && object.is_a?(Array)
      case position
      when :newest then object.first
      when :oldest then object.last
      else
        object[position]
      end
    else
      object
    end
  end

  def extract_args_and_attrs(argv)
    if argv.any?
      args = argv.select { |a| !a.include?(?=) }
      attributes = Hash[argv.select { |a| a.include?(?=) }.map { |a| a.split(?=, 2) }]
    else
      args = []
      attributes = {}
    end

    [args, attributes]
  end

  def pretty(object)
    if object.is_a?(Hash) || object.is_a?(Array)
      JSON.pretty_generate(object)
    else
      object
    end
  end

  def filter(object)
    return object if keys.empty?

    if object.is_a?(Hash) && object["object"] == "list"
      filter(object["data"])
    elsif object.is_a?(Hash)
      object.select { |k,v| keys.include?(k) }
    elsif object.is_a?(Array)
      object.map { |i| filter(i) }
    else
      object
    end
  end

  def flatten(object)
    return object unless flat

    if object.is_a?(Hash) && object["object"] == "list"
      flatten(object["data"])
    elsif object.is_a?(Hash)
      object.select { |k,v| !v.is_a?(Array) && !v.is_a?(Hash) }.values.map { |v| v.presence || "null" }.map(&:to_s).join(", ")
    elsif object.is_a?(Array)
      object.map { |i| flatten(i) }.join("\n")
    else
      object
    end
  end

  def position
    @options[:position]
  end

  def flat
    @options[:flat]
  end

  def data
    @options[:data].merge(key: key)
  end

  def keys
    @options[:keys]
  end
end
