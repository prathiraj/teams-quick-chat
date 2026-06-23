using System.Diagnostics;
using System.Web;

namespace TeamsQuickChat;

public static class TeamsDeepLink
{
    private const string TeamsHost = "teams.microsoft.com";

    public static bool TryNormalizeTeamsWebLink(string input, out string teamsLink)
    {
        teamsLink = "";
        var trimmed = input.Trim();

        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var uri))
            return false;

        if (!string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(uri.Host, TeamsHost, StringComparison.OrdinalIgnoreCase) ||
            !uri.AbsolutePath.StartsWith("/l/chat/", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        teamsLink = $"msteams:{uri.PathAndQuery}{uri.Fragment}";
        return true;
    }

    public static void Open(Contact contact)
    {
        if (contact.IsTeamsLink && !string.IsNullOrWhiteSpace(contact.TeamsLink))
        {
            OpenUri(contact.TeamsLink);
            return;
        }

        if (!string.IsNullOrWhiteSpace(contact.Email))
        {
            OpenChat(contact.Email);
            return;
        }

        throw new InvalidOperationException("Contact must have either an email address or a Teams link.");
    }

    public static void OpenChat(string email)
    {
        var encoded = HttpUtility.UrlEncode(email);
        var uri = $"msteams:/l/chat/0/0?users={encoded}";
        OpenUri(uri);
    }

    private static void OpenUri(string uri)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = uri,
            UseShellExecute = true
        });
    }
}
