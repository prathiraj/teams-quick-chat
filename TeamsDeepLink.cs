using System.Diagnostics;
using System.Web;

namespace TeamsQuickChat;

public static class TeamsDeepLink
{
    public static void OpenChat(string email)
    {
        var encoded = HttpUtility.UrlEncode(email);
        var uri = $"msteams:/l/chat/0/0?users={encoded}";

        Process.Start(new ProcessStartInfo
        {
            FileName = uri,
            UseShellExecute = true
        });
    }
}
