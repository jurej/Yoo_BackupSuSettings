require 'json'

def read_json(path)
  content = File.read(path)
  JSON.parse(content)
end

def test_export(prefs_path)
  puts "Reading from #{prefs_path}"
  data = read_json(prefs_path)
  puts "Read #{data.keys.size} keys: #{data.keys.inspect}"
  
  if data.key?("This Computer Only")
    puts "Found 'This Computer Only' wrapper."
    data = data["This Computer Only"]
  end

  export_data = {}

  if data['MainWindow']
    puts "Found MainWindow"
    if data['MainWindow']['ToolBarState']
      puts "Found ToolBarState: #{data['MainWindow']['ToolBarState'].to_s[0..50]}..."
      export_data['MainWindow'] ||= {}
      export_data['MainWindow']['ToolBarState'] = data['MainWindow']['ToolBarState']
    else
      puts "ToolBarState MISSING"
    end
    
    if data['MainWindow']['DockWidgetState']
      puts "Found DockWidgetState"
      export_data['MainWindow'] ||= {}
      export_data['MainWindow']['DockWidgetState'] = data['MainWindow']['DockWidgetState']
    else
      puts "DockWidgetState MISSING"
    end
  else
    puts "MainWindow MISSING"
  end

  count = 0
  data.each do |key, value|
    if key.start_with?("QtRubyWorkspace")
      export_data[key] = value
      count += 1
    end
  end
  puts "Found #{count} QtRubyWorkspace items"
  
  puts "Export data has #{export_data.keys.size} keys"
  puts JSON.pretty_generate(export_data)
end

test_export('test_prefs.json')
