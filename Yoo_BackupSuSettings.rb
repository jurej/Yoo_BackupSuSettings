require 'sketchup.rb'
require 'extensions.rb'

module Yoo
  module BackupSuSettings
    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('Yoo Backup Settings', 'Yoo_BackupSuSettings/main')
      ex.description = 'Save and Load Toolbar positions.'
      ex.version     = '1.0.0'
      ex.copyright   = '2025'
      ex.creator     = 'Jure Judež'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end
  end
end
