using System.Text.Json;
using System.Text.Json.Nodes;

namespace YooBackupRestorer;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("==========================================");
        Console.WriteLine("   Yoo Backup Settings - External Restorer");
        Console.WriteLine("==========================================");
        Console.WriteLine("This tool restores SketchUp settings while SketchUp is closed.");
        Console.WriteLine();

        // 1. Find PrivatePreferences.json
        string? sketchupPrefsPath = FindSketchupPreferences();
        if (sketchupPrefsPath == null)
        {
            Console.WriteLine("Could not automatically find SketchUp PrivatePreferences.json.");
            Console.Write("Please enter the full path to PrivatePreferences.json: ");
            sketchupPrefsPath = Console.ReadLine()?.Trim('"'); // Remove quotes if dragged in
        }

        if (string.IsNullOrWhiteSpace(sketchupPrefsPath) || !File.Exists(sketchupPrefsPath))
        {
            Console.WriteLine($"Error: File not found at {sketchupPrefsPath}");
            Pause();
            return;
        }

        Console.WriteLine($"Target: {sketchupPrefsPath}");
        Console.WriteLine();

        // 2. Get Backup File
        Console.WriteLine("Please drag and drop your 'settings.json' backup file here and press Enter:");
        string? backupPath = Console.ReadLine()?.Trim('"');

        if (string.IsNullOrWhiteSpace(backupPath) || !File.Exists(backupPath))
        {
            Console.WriteLine($"Error: Backup file not found at {backupPath}");
            Pause();
            return;
        }

        // 3. Ask what to restore
        Console.WriteLine();
        Console.WriteLine("Select settings to restore:");
        bool restoreWorkspace = AskYesNo("Restore Workspace (Docking/Layout)? [y/n]: ");
        bool restoreToolbars = AskYesNo("Restore Toolbars (Positions/Visibility)? [y/n]: ");
        bool restoreExtensions = AskYesNo("Restore Extension Settings? [y/n]: ");

        if (!restoreWorkspace && !restoreToolbars && !restoreExtensions)
        {
            Console.WriteLine("Nothing selected. Exiting.");
            Pause();
            return;
        }

        try
        {
            // 4. Perform Restore
            Console.WriteLine();
            Console.WriteLine("Reading files...");
            
            // Read Backup
            string backupContent = File.ReadAllText(backupPath);
            JsonNode? backupRoot = JsonNode.Parse(backupContent);
            if (backupRoot == null) throw new Exception("Failed to parse backup JSON.");

            // Read Target
            string targetContent = File.ReadAllText(sketchupPrefsPath);
            JsonNode? targetRoot = JsonNode.Parse(targetContent);
            if (targetRoot == null) throw new Exception("Failed to parse target JSON.");

            // Backup the target file first
            string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            string backupOfTarget = sketchupPrefsPath + $".{timestamp}.bak";
            File.Copy(sketchupPrefsPath, backupOfTarget);
            Console.WriteLine($"Backup of current settings created at: {Path.GetFileName(backupOfTarget)}");

            // Merge Logic
            if (targetRoot is JsonObject targetObj && backupRoot is JsonObject backupObj)
            {
                // Handle "This Computer Only" wrapper in backup if present
                JsonObject? sourceObj = backupObj;
                if (backupObj.ContainsKey("This Computer Only"))
                {
                    Console.WriteLine("Detected 'This Computer Only' wrapper in backup.");
                    sourceObj = backupObj["This Computer Only"] as JsonObject;
                }
                
                // Handle "This Computer Only" wrapper in target if present
                JsonObject? destObj = targetObj;
                if (targetObj.ContainsKey("This Computer Only"))
                {
                    Console.WriteLine("Detected 'This Computer Only' wrapper in target.");
                    destObj = targetObj["This Computer Only"] as JsonObject;
                }

                if (sourceObj == null || destObj == null)
                {
                    throw new Exception("Structure error: Could not resolve root objects.");
                }

                int changes = 0;

                // --- Workspace (DockWidgetState) ---
                if (restoreWorkspace)
                {
                    if (GetNestedNode(sourceObj, "MainWindow", "DockWidgetState") is JsonNode dockState)
                    {
                        EnsureObject(destObj, "MainWindow");
                        destObj["MainWindow"]!["DockWidgetState"] = dockState.DeepClone();
                        Console.WriteLine("- Restored MainWindow/DockWidgetState");
                        changes++;
                    }
                }

                // --- Toolbars (ToolBarState & QtRubyWorkspace) ---
                if (restoreToolbars)
                {
                    // 1. Native Toolbars
                    if (GetNestedNode(sourceObj, "MainWindow", "ToolBarState") is JsonNode toolbarState)
                    {
                        EnsureObject(destObj, "MainWindow");
                        destObj["MainWindow"]!["ToolBarState"] = toolbarState.DeepClone();
                        Console.WriteLine("- Restored MainWindow/ToolBarState");
                        changes++;
                    }

                    // 2. Ruby Toolbars (QtRubyWorkspace*)
                    foreach (var kvp in sourceObj.ToList()) // ToList to avoid concurrent mod
                    {
                        if (kvp.Key.StartsWith("QtRubyWorkspace"))
                        {
                            destObj[kvp.Key] = kvp.Value?.DeepClone();
                            Console.WriteLine($"- Restored {kvp.Key}");
                            changes++;
                        }
                    }
                }

                // --- Extensions (Everything else) ---
                if (restoreExtensions)
                {
                    foreach (var kvp in sourceObj.ToList())
                    {
                        // Skip MainWindow and QtRubyWorkspace (handled above or ignored)
                        if (kvp.Key == "MainWindow" || kvp.Key.StartsWith("QtRubyWorkspace"))
                            continue;

                        // It's an extension or other setting
                        destObj[kvp.Key] = kvp.Value?.DeepClone();
                        Console.WriteLine($"- Restored {kvp.Key}");
                        changes++;
                    }
                }

                // Save
                Console.WriteLine();
                Console.WriteLine($"Writing {changes} changes to PrivatePreferences.json...");
                
                // JsonSerializerOptions to keep it pretty or compact? SketchUp usually compact but pretty is safer to read.
                // However, SketchUp might care about format? Usually not.
                // Let's write pretty.
                var options = new JsonSerializerOptions { WriteIndented = true };
                File.WriteAllText(sketchupPrefsPath, targetRoot.ToJsonString(options));

                Console.WriteLine("SUCCESS! Settings restored.");
                Console.WriteLine("You can now open SketchUp.");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine();
            Console.WriteLine($"ERROR: {ex.Message}");
            Console.WriteLine(ex.StackTrace);
        }

        Pause();
    }

    static JsonNode? GetNestedNode(JsonObject obj, string key1, string key2)
    {
        if (obj.TryGetPropertyValue(key1, out JsonNode? val1) && val1 is JsonObject obj1)
        {
            if (obj1.TryGetPropertyValue(key2, out JsonNode? val2))
            {
                return val2;
            }
        }
        return null;
    }

    static void EnsureObject(JsonObject obj, string key)
    {
        if (!obj.ContainsKey(key) || !(obj[key] is JsonObject))
        {
            obj[key] = new JsonObject();
        }
    }

    static bool AskYesNo(string prompt)
    {
        Console.Write(prompt);
        string? input = Console.ReadLine()?.Trim().ToLower();
        return input == "y" || input == "yes";
    }

    static void Pause()
    {
        Console.WriteLine();
        Console.WriteLine("Press any key to exit...");
        Console.ReadKey();
    }

    static string? FindSketchupPreferences()
    {
        // %LOCALAPPDATA%/SketchUp/SketchUp 20XX/SketchUp/PrivatePreferences.json
        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string sketchupRoot = Path.Combine(localAppData, "SketchUp");

        if (!Directory.Exists(sketchupRoot)) return null;

        // Find latest year
        var dirs = Directory.GetDirectories(sketchupRoot, "SketchUp 20*");
        if (dirs.Length == 0) return null;

        // Sort descending
        Array.Sort(dirs);
        Array.Reverse(dirs);

        foreach (var dir in dirs)
        {
            string candidate = Path.Combine(dir, "SketchUp", "PrivatePreferences.json");
            if (File.Exists(candidate))
                return candidate;
        }

        return null;
    }
}
