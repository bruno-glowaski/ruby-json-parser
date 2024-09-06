# frozen_string_literal: true

require_relative 'json'

input = STDIN.read

parser = JSON.parser

puts parser.parse(input)
