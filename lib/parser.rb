# frozen_string_literal: true

ParseResult = Struct.new('ParseResult', :output, :rest)

# Creates a parser that consumes an input
class Parser
  def initialize(processor)
    @processor = processor
  end

  def self.between(pre, content, post)
    Parser.sequence_of(pre, content, post).map ->(outputs) { outputs[1] }
  end

  def self.parser_from(value)
    return value if value.is_a?(Parser)

    literal(value.to_s)
  end

  def self.eof
    Parser.new ->(input) { return ParseResult.new nil, input if input.empty? }
  end

  def self.first_of(*parsers)
    Parser.new lambda { |input|
                 parsers.each do |parser|
                   result = parser_from(parser).parse input
                   return result if result
                 end
                 nil
               }
  end

  def self.lazy(parser_factory)
    Parser.new lambda { |input|
      parser = parser_factory.call
      actual_parser = parser_from(parser)
      actual_parser.parse input
    }
  end

  def self.literal(literal)
    Parser.new ->(input) { ParseResult.new literal, input.delete_prefix(literal) if input.start_with? literal }
  end

  def self.many_of(parser)
    actual_parser = parser_from(parser)
    Parser.new lambda { |input|
                 current = input
                 outputs = []
                 loop do
                   result = actual_parser.parse(current)
                   break unless result

                   outputs += [result.output]
                   current = result.rest
                 end
                 ParseResult.new outputs, current
               }
  end

  def self.list(item_parser, sep_parser)
    Parser.sequence_of(
      Parser.many_of(Parser.trim_end(item_parser, sep_parser)),
      item_parser
    )
          .map lambda { |results|
                 results[0] + [results[1]]
               }
  end

  def self.maybe(parser)
    actual_parser = parser_from(parser)
    Parser.new lambda { |input|
                 result = actual_parser.parse(input)
                 if !result
                   ParseResult.new nil, input
                 else
                   result
                 end
               }
  end

  def self.pair(parser1, sep, parser2)
    Parser.sequence_of(parser1, sep, parser2).map lambda { |outputs|
                                                    outputs.values_at(
                                                      0, 2
                                                    )
                                                  }
  end

  def self.regex(regex)
    Parser.new lambda { |input|
                 match_result = input.match regex
                 return nil if match_result.nil?

                 offset = match_result.offset(0)
                 return ParseResult.new match_result, input[offset[1]..] unless (offset[0]).positive?
               }
  end

  def self.sequence_of(*parsers)
    Parser.new lambda { |input|
                 current = input
                 outputs = []
                 parsers.each do |parser|
                   actual_parser = parser_from(parser)
                   result = actual_parser.parse current
                   return nil unless result

                   outputs += [result.output]
                   current = result.rest
                 end
                 ParseResult.new outputs, current
               }
  end

  def self.trim_end(parser, space_parser = whitespace)
    Parser.sequence_of(parser, space_parser).map ->(result) { result[0] }
  end

  def self.trim(parser, space_parser = whitespace)
    Parser.between(space_parser, parser, space_parser)
  end

  def self.whitespace
    Parser.regex(/\s*/)
  end

  def eof
    Parser.sequence_of(self, Parser.eof).map ->(outputs) { outputs[0] }
  end

  def map(transform_fn)
    Parser.new lambda { |input|
                 result = parse input
                 if result
                   ParseResult.new transform_fn.call(result.output), result.rest
                 else
                   result
                 end
               }
  end

  def map_into(value)
    map(->(_) { value })
  end

  def parse(input)
    @processor.call input
  end

  def trim(sep_parser = Parser.whitespace)
    Parser.trim self, sep_parser
  end

  def trim_end(sep_parser = Parser.whitespace)
    Parser.trim_end self, sep_parser
  end
end
