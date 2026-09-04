using System.Runtime.InteropServices;

namespace TeamsQuickChat;

internal static class AppIdentity
{
    internal const string DefaultAppUserModelId = "Prathiraj.TeamsQuickChat";
    internal const string ChatAppUserModelIdPrefix = DefaultAppUserModelId + ".Chat.";

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);

    internal static void SetCurrentProcess(string appUserModelId)
    {
        if (!IsValid(appUserModelId))
            throw new ArgumentException("Invalid Teams Quick Chat application identity.", nameof(appUserModelId));

        Marshal.ThrowExceptionForHR(SetCurrentProcessExplicitAppUserModelID(appUserModelId));
    }

    internal static bool IsValid(string appUserModelId)
    {
        if (string.Equals(
                appUserModelId,
                DefaultAppUserModelId,
                StringComparison.Ordinal))
        {
            return true;
        }

        if (!appUserModelId.StartsWith(
                ChatAppUserModelIdPrefix,
                StringComparison.Ordinal))
        {
            return false;
        }

        var suffix = appUserModelId.AsSpan(ChatAppUserModelIdPrefix.Length);
        return suffix.Length == 24 && suffix.IndexOfAnyExcept(
            "0123456789ABCDEF".AsSpan()) < 0;
    }
}
