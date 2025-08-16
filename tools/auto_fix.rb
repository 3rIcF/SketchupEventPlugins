#!/usr/bin/env ruby
# frozen_string_literal: true

system('rubocop', '-A') || abort('RuboCop auto-correction failed')
