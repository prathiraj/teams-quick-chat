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

/// <summary>
/// Thrown when the contact store cannot be reached because its backing
/// cloud storage (e.g. OneDrive) is not available — most commonly because
/// the OneDrive/cloud file provider process is not running.
/// </summary>
public sealed class ContactStoreUnavailableException : Exception
{
    public ContactStoreUnavailableException(string message, Exception inner)
        : base(message, inner) { }
}

public static class ContactStore
{
    private static readonly string DataDir = ResolveDataDir();
    private static readonly string FilePath = Path.Combine(DataDir, "contacts.json");

    // Win32 error codes in the ERROR_CLOUD_FILE_* family (winerror.h). These
    // surface as IOException with HResult == HRESULT_FROM_WIN32(code) when a
    // OneDrive placeholder can't be hydrated (e.g. OneDrive isn't running).
    private static readonly HashSet<int> CloudFileErrorCodes =
    [
        358, 362, 363, 364, 365, 366, 374, 375, 377, 378, 379, 380, 381, 382,
        383, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398,
        404, 426, 434, 475
    ];

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
        try
        {
            if (!File.Exists(FilePath))
                return [];

            var json = File.ReadAllText(FilePath);
            return JsonSerializer.Deserialize<List<Contact>>(json) ?? [];
        }
        catch (IOException ex) when (IsCloudProviderUnavailable(ex))
        {
            throw CloudUnavailable(ex);
        }
    }

    public static void Save(List<Contact> contacts)
    {
        try
        {
            Directory.CreateDirectory(DataDir);
            var json = JsonSerializer.Serialize(contacts, new JsonSerializerOptions
            {
                WriteIndented = true,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            });
            File.WriteAllText(FilePath, json);
        }
        catch (IOException ex) when (IsCloudProviderUnavailable(ex))
        {
            throw CloudUnavailable(ex);
        }
    }

    private static bool IsCloudProviderUnavailable(IOException ex)
    {
        // .NET wraps Win32 failures as HResult == HRESULT_FROM_WIN32(code),
        // i.e. 0x8007xxxx. Extract the Win32 code and match the cloud-file set.
        if ((ex.HResult & unchecked((int)0xFFFF0000)) != unchecked((int)0x80070000))
            return false;

        return CloudFileErrorCodes.Contains(ex.HResult & 0xFFFF);
    }

    private static ContactStoreUnavailableException CloudUnavailable(IOException ex) =>
        new(
            "Your contacts are stored in OneDrive, but the cloud files aren't " +
            "available right now. This usually means OneDrive isn't running. " +
            "Start OneDrive (or wait for it to finish syncing) and try again.",
            ex);

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
