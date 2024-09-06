# frozen_string_literal: true

require_relative 'parser'

# JSON parsing
module JSON
  def self.parser
    value_parser.eof
  end

  def self.value_parser
    Parser.first_of(
      string_parser,
      number_parser,
      object_parser,
      array_parser,
      boolean_parser,
      null_parser
    ).trim
  end

  def self.string_parser
    string_regex = /"(?'content'.*?[^\\])"/
    Parser.regex(string_regex).map ->(result) { result[:content].sub('\"', '"') }
  end

  def self.number_parser
    number_regex = /-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/
    Parser.regex(number_regex).map ->(result) { result[0].to_f }
  end

  def self.object_parser
    empty_object_parser = Parser.whitespace.map_into({})
    object_entry_parser = Parser.pair(string_parser.trim, ':', Parser.lazy(-> { value_parser }))
    filled_object_parser = Parser.list(object_entry_parser, ',').map ->(entries) { Hash[entries] }
    object_content_parser = Parser.first_of filled_object_parser, empty_object_parser
    Parser.between '{', object_content_parser, '}'
  end

  def self.array_parser
    filled_array_parser = Parser.lazy(-> { Parser.list(value_parser, ',') })
    empty_array_parser = Parser.whitespace.map_into([])
    array_content_parser = Parser.first_of filled_array_parser, empty_array_parser
    Parser.between '[', array_content_parser, ']'
  end

  def self.boolean_parser
    Parser.first_of(
      Parser.literal('true').map_into(true),
      Parser.literal('false').map_into(false)
    )
  end

  def self.null_parser
    Parser.literal('null').map_into nil
  end
end
