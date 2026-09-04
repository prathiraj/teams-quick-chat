using System.Diagnostics;
using System.Web;

namespace TeamsQuickChat;

public static class TeamsDeepLink
{
    private const string TeamsHost = "teams.microsoft.com";
    private const string TeamsScheme = "msteams";

    public static bool TryNormalizeTeamsWebLink(string input, out string teamsLink)
    {
        teamsLink = "";
        var trimmed = input.Trim();

        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var uri))
            return false;

        if (!string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(uri.Host, TeamsHost, StringComparison.OrdinalIgnoreCase) ||
            !IsChatPath(uri.AbsolutePath))
        {
            return false;
        }

        teamsLink = $"msteams:{uri.PathAndQuery}{uri.Fragment}";
        return true;
    }

    public static void Open(Contact contact)
    {
        OpenUri(GetUri(contact));
    }

    public static string GetUri(Contact contact)
    {
        if (contact.IsTeamsLink && !string.IsNullOrWhiteSpace(contact.TeamsLink))
            return contact.TeamsLink;

        if (!string.IsNullOrWhiteSpace(contact.Email))
            return CreateChatUri(contact.Email);

        throw new InvalidOperationException("Contact must have either an email address or a Teams link.");
    }

    internal static void OpenPinnedChat(string uri) => OpenUri(uri);

    internal static bool IsSupportedChatUri(string uri)
    {
        return Uri.TryCreate(uri, UriKind.Absolute, out var parsed) &&
            string.Equals(parsed.Scheme, TeamsScheme, StringComparison.OrdinalIgnoreCase) &&
            IsChatPath(parsed.AbsolutePath);
    }

    private static string CreateChatUri(string email)
    {
        var encoded = HttpUtility.UrlEncode(email);
        return $"msteams:/l/chat/0/0?users={encoded}";
    }

    private static void OpenUri(string uri)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = uri,
            UseShellExecute = true
        });
    }

    private static bool IsChatPath(string path) =>
        path.StartsWith("/l/chat/", StringComparison.OrdinalIgnoreCase);
}
