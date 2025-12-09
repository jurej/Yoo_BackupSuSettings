require 'json'

module Yoo
  module BackupSuSettings
    module Logic
      def self.get_preferences_file
        # Construct path for Windows: %LOCALAPPDATA%/SketchUp/SketchUp 20XX/SketchUp/PrivatePreferences.json
        # Adjust version mapping if necessary. Sketchup.version is like '23.0.367'
        major_version = Sketchup.version.split('.').first
        
        # SketchUp 2023 is version 23.
        # However, the folder name is "SketchUp 2023".
        # So we construct "SketchUp 20" + major_version
        
        year_version = "20#{major_version}" 
        
        # Verify folder exists, sometimes 'SketchUp 2023' might be different if they change versioning scheme
        # But for 2023-2025 this pattern should hold.
        
        local_app_data = ENV['LOCALAPPDATA']
        path = File.join(local_app_data, 'SketchUp', "SketchUp #{year_version}", 'SketchUp', 'PrivatePreferences.json')
        
        unless File.exist?(path)
          # Fallback or try to find it?
          puts "Yoo_BackupSuSettings: Could not find #{path}"
          # Attempt to list directories in %LOCALAPPDATA%/SketchUp to see if we can find the right one?
          # For now, return path and let file read fail.
        end
        
        path
      end

      def self.read_json(path)
        content = File.read(path)
        JSON.parse(content)
      end

      def self.export_settings(export_path)
        prefs_path = get_preferences_file
        puts "Yoo_BackupSuSettings: Reading preferences from #{prefs_path}"
        
        unless File.exist?(prefs_path)
          UI.messagebox("Could not find PrivatePreferences.json at: #{prefs_path}")
          raise "PrivatePreferences.json not found at #{prefs_path}"
        end

        data = read_json(prefs_path)
        puts "Yoo_BackupSuSettings: Read #{data.keys.size} keys from PrivatePreferences.json"
        
        export_data = {}
        
        # 1. Capture MainWindow ToolBarState and DockWidgetState
        if data['MainWindow']
          puts "Yoo_BackupSuSettings: Found MainWindow key"
          export_data['MainWindow'] = {}
          if data['MainWindow']['ToolBarState']
            export_data['MainWindow']['ToolBarState'] = data['MainWindow']['ToolBarState']
            puts "Yoo_BackupSuSettings: Found ToolBarState"
          else
            puts "Yoo_BackupSuSettings: ToolBarState MISSING in MainWindow"
          end
          
          if data['MainWindow']['DockWidgetState']
            export_data['MainWindow']['DockWidgetState'] = data['MainWindow']['DockWidgetState']
            puts "Yoo_BackupSuSettings: Found DockWidgetState"
          else
            puts "Yoo_BackupSuSettings: DockWidgetState MISSING in MainWindow"
          end
        else
          puts "Yoo_BackupSuSettings: MainWindow key MISSING"
        end
        
        # 2. Capture QtRubyWorkspace toolbars
        count_ruby = 0
        data.each do |key, value|
          if key.start_with?("QtRubyWorkspace")
            export_data[key] = value
            count_ruby += 1
          end
        end
        puts "Yoo_BackupSuSettings: Found #{count_ruby} QtRubyWorkspace items"

        puts "Yoo_BackupSuSettings: Exporting #{export_data.keys.size} root keys to #{export_path}"

        # Save to file
        File.open(export_path, 'w') do |f|
          f.write(JSON.pretty_generate(export_data))
        end
      end

      def self.import_settings(import_path)
        unless File.exist?(import_path)
          raise "Import file not found: #{import_path}"
        end

        import_data = read_json(import_path)
        
        # Apply Main Window settings
        if import_data['MainWindow']
          if val = import_data['MainWindow']['ToolBarState']
            Sketchup.write_default('MainWindow', 'ToolBarState', val)
          end
          if val = import_data['MainWindow']['DockWidgetState']
            Sketchup.write_default('MainWindow', 'DockWidgetState', val)
          end
        end
        
        # Apply Ruby Toolbars
        import_data.each do |section, keys|
          next if section == 'MainWindow'
          
          # Assuming other top level keys are sections
          if keys.is_a?(Hash)
            keys.each do |key, value|
              # Sketchup.write_default handles basic types (bool, int, string, float)
              # In PrivatePreferences logic, everything seems to match.
              Sketchup.write_default(section, key, value)
            end
          end
        end
        
        true
      end
    end
  end
end
