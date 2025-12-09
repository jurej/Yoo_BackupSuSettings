require 'sketchup.rb'
require_relative 'logic'

module Yoo
  module BackupSuSettings
    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins').add_submenu('Yoo Backup Settings')
      
      menu.add_item('Save Toolbar Positions...') {
        self.save_toolbar_positions
      }
      
      menu.add_item('Load Toolbar Positions...') {
        self.load_toolbar_positions
      }
      
      file_loaded(__FILE__)
    end

    def self.save_toolbar_positions
      filepath = UI.savepanel("Save Toolbar Positions", "", "toolbars.json")
      return unless filepath
      
      begin
        Logic.export_settings(filepath)
        UI.messagebox("Successfully saved toolbar positions to #{filepath}")
      rescue => e
        UI.messagebox("Error saving settings: #{e.message}")
        puts e.backtrace
      end
    end

    def self.load_toolbar_positions
      filepath = UI.openpanel("Load Toolbar Positions", "", "toolbars.json")
      return unless filepath
      
      begin
        result = UI.messagebox("This will overwrite current toolbar positions. SketchUp requires a restart for changes to take full effect.\n\nContinue?", MB_YESNO)
        return if result == IDNO

        Logic.import_settings(filepath)
        UI.messagebox("Settings loaded. Please RESTART SketchUp to see changes.")
      rescue => e
        UI.messagebox("Error loading settings: #{e.message}")
        puts e.backtrace
      end
    end
  end
end
