using System.Text.Json;

namespace TeamsQuickChat;

public class SettingsDialog : Form
{
    private TextBox dataDirBox = null!;

    public SettingsDialog()
    {
        Text = "Settings";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(420, 140);
        BuildUI();
    }

    private void BuildUI()
    {
        var label = new Label
        {
            Text = "Contacts folder:",
            Location = new Point(12, 18),
            AutoSize = true
        };

        dataDirBox = new TextBox
        {
            Location = new Point(12, 40),
            Width = 340,
            Text = GetCurrentConfigDir()
        };

        var browseBtn = new Button
        {
            Text = "...",
            Location = new Point(360, 38),
            Width = 40,
            Height = 26
        };
        browseBtn.Click += (_, _) =>
        {
            using var dlg = new FolderBrowserDialog
            {
                Description = "Select contacts folder",
                SelectedPath = dataDirBox.Text,
                UseDescriptionForTitle = true
            };
            if (dlg.ShowDialog(this) == DialogResult.OK)
                dataDirBox.Text = dlg.SelectedPath;
        };

        var hint = new Label
        {
            Text = "Supports environment variables like %USERPROFILE%. Leave empty for default (OneDrive).",
            Location = new Point(12, 70),
            AutoSize = true,
            ForeColor = Color.Gray,
            Font = new Font("Segoe UI", 8)
        };

        var saveBtn = new Button
        {
            Text = "Save",
            Location = new Point(250, 100),
            Width = 75,
            DialogResult = DialogResult.OK
        };
        saveBtn.Click += (_, _) => SaveConfig();

        var cancelBtn = new Button
        {
            Text = "Cancel",
            Location = new Point(335, 100),
            Width = 75,
            DialogResult = DialogResult.Cancel
        };

        AcceptButton = saveBtn;
        CancelButton = cancelBtn;
        Controls.AddRange([label, dataDirBox, browseBtn, hint, saveBtn, cancelBtn]);
    }

    private static string GetConfigPath() =>
        Path.Combine(AppContext.BaseDirectory, "appsettings.json");

    private static string GetCurrentConfigDir()
    {
        var configPath = GetConfigPath();
        if (File.Exists(configPath))
        {
            try
            {
                var json = File.ReadAllText(configPath);
                var config = JsonSerializer.Deserialize<JsonElement>(json);
                if (config.TryGetProperty("DataDir", out var dirProp))
                    return dirProp.GetString() ?? "";
            }
            catch { }
        }
        return "";
    }

    private void SaveConfig()
    {
        var dir = dataDirBox.Text.Trim();
        var configPath = GetConfigPath();

        if (string.IsNullOrEmpty(dir))
        {
            // Remove config to revert to default
            if (File.Exists(configPath))
                File.Delete(configPath);
        }
        else
        {
            var config = new { DataDir = dir };
            var json = JsonSerializer.Serialize(config, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(configPath, json);
        }

        MessageBox.Show(
            "Settings saved. Restart the app for changes to take effect.",
            "Settings",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);
    }
}
