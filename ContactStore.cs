using System.Text.Json;
using System.Text.Json.Serialization;

namespace TeamsQuickChat;

public record Contact
{
    public string Name { get; init; } = "";
    public string? Email { get; init; }
    public string? TeamsLink { get; init; }

    [JsonIgnore]
    public bool IsTeamsLink => !string.IsNullOrWhiteSpace(TeamsLink);

    public static Contact ForEmail(string name, string email) => new()
    {
        Name = name,
        Email = email
    };

    public static Contact ForTeamsLink(string name, string teamsLink) => new()
    {
        Name = name,
        TeamsLink = teamsLink
    };
}

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
        var json = JsonSerializer.Serialize(contacts, new JsonSerializerOptions
        {
            WriteIndented = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        });
        File.WriteAllText(FilePath, json);
    }

    public static void Add(string name, string email)
    {
        AddEmail(name, email);
    }

    public static void AddEmail(string name, string email)
    {
        Add(Contact.ForEmail(name, email));
    }

    public static void AddTeamsLink(string name, string teamsLink)
    {
        Add(Contact.ForTeamsLink(name, teamsLink));
    }

    private static void Add(Contact contact)
    {
        var contacts = Load();
        if (contacts.Any(c => HasSameTarget(c, contact)))
            return;
        contacts.Add(contact);
        Save(contacts);
    }

    public static void Remove(string email)
    {
        Remove(Contact.ForEmail("", email));
    }

    public static void Remove(Contact contact)
    {
        var contacts = Load();
        contacts.RemoveAll(c => HasSameTarget(c, contact));
        Save(contacts);
    }

    private static bool HasSameTarget(Contact left, Contact right)
    {
        if (left.IsTeamsLink != right.IsTeamsLink)
            return false;

        if (left.IsTeamsLink)
            return string.Equals(left.TeamsLink, right.TeamsLink, StringComparison.Ordinal);

        return string.Equals(left.Email, right.Email, StringComparison.OrdinalIgnoreCase);
    }
}
