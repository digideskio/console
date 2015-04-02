class Command
  class Options
    DEFAULT = {
      keys: [],
      data: {},
      flat: false,
      position: nil,
      amount_column: nil
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
    display this screen:     help
    create an object:        post   /path [key=value,...] [options]
    retrieve an object:      get    /path [key=value,...] [options]
    update an object:        patch  /path [key=value,...] [options]
    destroy and object:      delete /path [key=value,...] [options]
    execute a local command: exec local-command(arg, ...)
        BANNER

        p.separator ""
        p.separator "common options:"

        p.on("-f", "--flat", "flatten the list and/or object(s)") do
          options[:flat] = true
        end

        p.on("-k", "--keys KEYS", Array, "extract KEYS from the list and/or object(s)") do |keys|
          options[:keys] = keys
        end

        p.on("--first", "return the first element of the list") do
          options[:position] = :first
        end

        p.on("--last", "return the last element of the list") do
          options[:position] = :last
        end

        p.on("-i INDEX", Integer, "take the element at position INDEX of the list (0 based)") do |index|
          options[:position] = index
        end

        p.on("-m", "--money KEY", "converts KEY to money") do |key|
          options[:amount_column] = key
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
    pretty(format_money(flatten(pos(filter(object)))))
  end

  # TODO fix omise-ruby to allow extra attrs in Omise::Resource#get
  def get(argv)
    path = argv.shift
    args, attrs = extract_args_and_attrs(argv)

    object = resource(path).get
    pretty(format_money(flatten(pos(filter(object)))))
  end

  def patch(argv)
    path = argv.shift
    args, attrs = extract_args_and_attrs(argv)

    object = resource(path).patch(attrs)
    pretty(format_money(flatten(pos(filter(object)))))
  end

  def delete(argv)
    path = argv.shift
    args, attrs = extract_args_and_attrs(argv)

    object = resource(path).delete(attrs)
    pretty(format_money(flatten(pos(filter(object)))))
  end

  def exec(argv)
<<-BANNER
Usage: exec local-command([arg, ...])

    the following commands are available:
        create a card token: exec token-create-card(pkey, name, number,
          expiration-month, expiration-year, security-code)
BANNER
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
      when :first then object.first
      when :last then object.last
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

  def format_money(object)
    amount_subunits = begin
      Integer(object[amount_column])
    rescue
      raise "can't convert '#{amount_column}' to integer"
    end

    if amount_subunits
      currency = object["currency"] || nil
      Money.new(amount_subunits, currency).format(symbol: false, with_currency: currency)
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

  def amount_column
    @options[:amount_column]
  end
end
