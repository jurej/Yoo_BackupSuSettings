
# Mock SketchUp API
module Sketchup
  def self.version
    "23.0.367"
  end
  def self.write_default(section, key, value)
    @writes ||= []
    @writes << [section, key, value]
    puts "Sketchup.write_default call: [#{section}, #{key}, #{value.inspect}]"
  end
  def self.writes
    @writes || []
  end
  def self.reset
    @writes = []
  end
end

module UI
  def self.messagebox(*args)
    puts "UI.messagebox: #{args.inspect}"
  end
end

# Require the logic file
require_relative 'Yoo_BackupSuSettings/Yoo_BackupSuSettings/logic'

# Setup test data
test_data = {
  "MainWindow" => {
    "ToolBarState" => "TOOLBAR_STATE_DATA",
    "DockWidgetState" => "DOCK_STATE_DATA"
  },
  "QtRubyWorkspace_Toolbar1" => {
    "Visible" => true
  },
  "SomeExtension" => {
    "Setting1" => "Value1"
  }
}

File.open('test_import.json', 'w') { |f| f.write(JSON.pretty_generate(test_data)) }

# Tests
puts "=== Starting Verification ==="

# Test 1: Load Everything (default)
puts "\nTest 1: Load Everything (extensions=true, toolbars=true, workspace=true)"
Sketchup.reset
Yoo::BackupSuSettings::Logic.import_settings('test_import.json', {workspace: true, toolbars: true, extensions: true})

writes = Sketchup.writes
failed = false

unless writes.include?(['MainWindow', 'DockWidgetState', "DOCK_STATE_DATA"])
  puts "FAIL: Missing DockWidgetState"
  failed = true
end
unless writes.include?(['MainWindow', 'ToolBarState', "TOOLBAR_STATE_DATA"])
  puts "FAIL: Missing ToolBarState"
  failed = true
end
unless writes.include?(['QtRubyWorkspace_Toolbar1', 'Visible', true])
  puts "FAIL: Missing Ruby Toolbar"
  failed = true
end
unless writes.include?(['SomeExtension', 'Setting1', "Value1"])
  puts "FAIL: Missing Extension Setting"
  failed = true
end

puts "Test 1 Passed" unless failed

# Test 2: Load Only Extensions
puts "\nTest 2: Load Only Extensions (extensions=true, toolbars=false, workspace=false)"
Sketchup.reset
Yoo::BackupSuSettings::Logic.import_settings('test_import.json', {workspace: false, toolbars: false, extensions: true})

writes = Sketchup.writes
failed = false

if writes.any? { |w| w[0] == 'MainWindow' }
  puts "FAIL: Should not have touched MainWindow"
  failed = true
end
if writes.any? { |w| w[0].start_with?('QtRubyWorkspace') }
  puts "FAIL: Should not have touched Toolbars"
  failed = true
end
unless writes.include?(['SomeExtension', 'Setting1', "Value1"])
  puts "FAIL: Missing Extension Setting"
  failed = true
end

puts "Test 2 Passed" unless failed

# Test 3: Load Only Toolbars
puts "\nTest 3: Load Only Toolbars (extensions=false, toolbars=true, workspace=false)"
Sketchup.reset
Yoo::BackupSuSettings::Logic.import_settings('test_import.json', {workspace: false, toolbars: true, extensions: false})

writes = Sketchup.writes
failed = false

if writes.any? { |w| w[1] == 'DockWidgetState' }
  puts "FAIL: Should not have loaded DockWidgetState"
  failed = true
end
unless writes.include?(['MainWindow', 'ToolBarState', "TOOLBAR_STATE_DATA"])
  puts "FAIL: Missing ToolBarState"
  failed = true
end
unless writes.include?(['QtRubyWorkspace_Toolbar1', 'Visible', true])
  puts "FAIL: Missing Ruby Toolbar"
  failed = true
end
if writes.any? { |w| w[0] == 'SomeExtension' }
  puts "FAIL: Should not have loaded Extension Settings"
  failed = true
end

puts "Test 3 Passed" unless failed

# Copy logic for export test
# Mocking ENV for export path
ENV['LOCALAPPDATA'] = Dir.pwd
puts "\n(Skipping Export Test path logic is messy to mock fully without affecting real system)"

puts "\n=== Verification Complete ==="
