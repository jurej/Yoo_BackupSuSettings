require 'sketchup.rb'
require_relative 'logic'

module Yoo
  module BackupSuSettings
    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins').add_submenu('Yoo Backup Settings')
      
      menu.add_item('Save Settings...') {
        self.save_settings
      }
      
      menu.add_item('Load Settings...') {
        self.load_settings
      }
      
      file_loaded(__FILE__)
    end

    def self.save_settings
      filepath = UI.savepanel("Save Settings", "", "settings.json")
      return unless filepath
      
      begin
        Logic.export_settings(filepath)
        UI.messagebox("Successfully saved settings to #{filepath}")
      rescue => e
        UI.messagebox("Error saving settings: #{e.message}")
        puts e.backtrace
      end
    end

    def self.load_settings
      result = UI.messagebox(
        "To restore Workspace and Toolbars correctly, you must use the External Restorer app while SketchUp is CLOSED.\n\n" \
        "Do you want to open the folder containing the Restorer app?\n\n" \
        "Click 'No' to attempt loading ONLY Extension settings internally.",
        MB_YESNOCANCEL
      )

      if result == IDYES
        # Open the folder containing the standalone app
        # Assuming the structure is .../Plugins/Yoo_BackupSuSettings/StandaloneApp/dist/
        # We need to find the path relative to this file.
        
        current_dir = File.dirname(__FILE__)
        # Go up one level to root package dir, then down to StandaloneApp/dist
        dist_path = File.join(File.dirname(current_dir), 'StandaloneApp', 'dist')
        dist_path = File.expand_path(dist_path)
        
        if File.directory?(dist_path)
          UI.openURL("file:///#{dist_path}")
        else
          UI.messagebox("Could not find Standalone App folder at:\n#{dist_path}")
        end
        return
      elsif result == IDCANCEL
        return
      end

      # Fallback: Load Extensions Only internally
      filepath = UI.openpanel("Load Settings (Extensions Only)", "", "settings.json")
      return unless filepath
      
      begin
        Logic.import_settings(filepath, {
          workspace: false,
          toolbars: false,
          extensions: true
        })
        UI.messagebox("Extension settings loaded. Some changes may require a restart.")
      rescue => e
        UI.messagebox("Error loading settings: #{e.message}")
        puts e.backtrace
      end
    end
  end
end
