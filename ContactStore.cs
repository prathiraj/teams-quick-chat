using System.Text.Json;

namespace TeamsQuickChat;

public record Contact(string Name, string Email);

public static class ContactStore
{
    private static readonly string DataDir = ResolveDataDir();
    private static readonly string FilePath = Path.Combine(DataDir, "contacts.json");

    private static string ResolveDataDir()
    {
        // Check for config override
        var configPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
        if (File.Exists(configPath))
        {
            try
            {
                var json = File.ReadAllText(configPath);
                var config = JsonSerializer.Deserialize<JsonElement>(json);
                if (config.TryGetProperty("DataDir", out var dirProp))
                {
                    var dir = Environment.ExpandEnvironmentVariables(dirProp.GetString() ?? "");
                    if (!string.IsNullOrWhiteSpace(dir))
                        return dir;
                }
            }
            catch { /* fall through to default */ }
        }

        // Default: OneDrive for roaming
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "OneDrive - Microsoft", "TeamsQuickChat");
    }

    public static string GetDataDir() => DataDir;

    public static List<Contact> Load()
    {
        if (!File.Exists(FilePath))
            return [];

        var json = File.ReadAllText(FilePath);
        return JsonSerializer.Deserialize<List<Contact>>(json) ?? [];
    }

    public static void Save(List<Contact> contacts)
    {
        Directory.CreateDirectory(DataDir);
        var json = JsonSerializer.Serialize(contacts, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(FilePath, json);
    }

    public static void Add(string name, string email)
    {
        var contacts = Load();
        if (contacts.Any(c => c.Email.Equals(email, StringComparison.OrdinalIgnoreCase)))
            return;
        contacts.Add(new Contact(name, email));
        Save(contacts);
    }

    public static void Remove(string email)
    {
        var contacts = Load();
        contacts.RemoveAll(c => c.Email.Equals(email, StringComparison.OrdinalIgnoreCase));
        Save(contacts);
    }
}
