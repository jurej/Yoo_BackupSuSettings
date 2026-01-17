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

        # Handle "This Computer Only" wrapping
        if data.key?("This Computer Only")
          puts "Yoo_BackupSuSettings: Found 'This Computer Only' wrapper."
          data = data["This Computer Only"]
        end
        
        # Determine what to export: EVERYTHING
        # We just dump the entire 'data' hash to the export file.
        # This ensures we capture extension settings, toolbars, workspace, etc.
        export_data = data
        
        puts "Yoo_BackupSuSettings: Exporting #{export_data.keys.size} root keys to #{export_path}"

        # Save to file
        File.open(export_path, 'w') do |f|
          f.write(JSON.pretty_generate(export_data))
        end
      end

      # options: { :workspace => bool, :toolbars => bool, :extensions => bool }
      def self.import_settings(import_path, options = {})
        unless File.exist?(import_path)
          raise "Import file not found: #{import_path}"
        end

        import_data = read_json(import_path)
        
        # Set defaults if options are missing (historical behavior: load everything relevant to toolbars/workspace)
        # But if options are passed, we respect them.
        # If options is empty/nil, default to ALL TRUE for backward compatibility? 
        # Actually, let's strictly follow options if provided.
        
        load_workspace = options.fetch(:workspace, true)
        load_toolbars  = options.fetch(:toolbars, true)
        load_extensions = options.fetch(:extensions, true)

        puts "Yoo_BackupSuSettings: Importing... Workspace: #{load_workspace}, Toolbars: #{load_toolbars}, Extensions: #{load_extensions}"
        
        # 1. Workspace (DockWidgetState)
        if load_workspace && import_data['MainWindow'] && import_data['MainWindow']['DockWidgetState']
           Sketchup.write_default('MainWindow', 'DockWidgetState', import_data['MainWindow']['DockWidgetState'])
        end

        # 2. Toolbars (ToolBarState & QtRubyWorkspace)
        if import_data['MainWindow'] && import_data['MainWindow']['ToolBarState']
          if load_toolbars
            Sketchup.write_default('MainWindow', 'ToolBarState', import_data['MainWindow']['ToolBarState'])
          end
        end

        # Iterate all keys to find:
        # - QtRubyWorkspace (Toolbars)
        # - Everything else (Extensions, usually)
        
        import_data.each do |section, keys|
          next if section == 'MainWindow' # Handle separately above

          is_toolbar_section = section.start_with?("QtRubyWorkspace")
          
          if is_toolbar_section
            next unless load_toolbars
          else
            # It is an extension setting or other setting
            next unless load_extensions
          end
          
          # Write the section
          if keys.is_a?(Hash)
            keys.each do |key, value|
              Sketchup.write_default(section, key, value)
            end
          else
            # Sometimes values are not hashes? In PrivatePreferences they usually are sections.
            # But Sketchup.write_default(section, key, value) requires a key.
            # If 'keys' is not a hash, we might be looking at a weird structure or root level key?
            # Standard PrivatePreferences structure is "Section" -> "Key" -> Value
            # So 'keys' here is the hash of key-values.
          end
        end
        
        true
      end
    end
  end
end
