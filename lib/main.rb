# frozen_string_literal: true

require_relative 'json'

string = '  { }   '

parser = JSON.parser

puts parser.parse(string)
