using System.Buffers.Text;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace TeamsQuickChat;

internal abstract record AppLaunchRequest(string AppUserModelId);

internal sealed record OpenPinnedChatRequest(
    string AppUserModelId,
    string ChatUri) : AppLaunchRequest(AppUserModelId);

internal sealed record TaskbarPinRequest(
    string AppUserModelId,
    string ShortcutPath,
    string DisplayName) : AppLaunchRequest(AppUserModelId);

internal sealed record RemoveTaskbarPinsRequest()
    : AppLaunchRequest(AppIdentity.DefaultAppUserModelId);

internal sealed class TaskbarPinningException : Exception
{
    internal TaskbarPinningException(string message, Exception innerException)
        : base(message, innerException)
    {
    }
}

internal static class TaskbarPinning
{
    private const string OpenPinnedChatMode = "--open-pinned-chat";
    private const string RequestTaskbarPinMode = "--request-taskbar-pin";
    private const string RemoveTaskbarPinsMode = "--remove-taskbar-pins";
    private const int HashByteCount = 12;
    private const int MaxEncodedUriLength = 16_384;

    private static readonly UTF8Encoding StrictUtf8 = new(
        encoderShouldEmitUTF8Identifier: false,
        throwOnInvalidBytes: true);

    internal static void StartPinRequest(Contact contact)
    {
        var executablePath = Environment.ProcessPath;
        if (string.IsNullOrWhiteSpace(executablePath) || !File.Exists(executablePath))
        {
            throw new TaskbarPinningException(
                "Teams Quick Chat could not locate its executable to create the shortcut.",
                new FileNotFoundException("The running executable path is unavailable.", executablePath));
        }

        var chatUri = TeamsDeepLink.GetUri(contact);
        var encodedUri = EncodeUri(chatUri);
        var hash = GetTargetHash(chatUri);
        var appUserModelId = AppIdentity.ChatAppUserModelIdPrefix + hash;
        var displayName = NormalizeDisplayName(contact.Name);
        var shortcutPath = GetShortcutPath(displayName, hash);
        var shortcutArguments =
            $"{OpenPinnedChatMode} {encodedUri} {appUserModelId}";

        try
        {
            ShellShortcut.Create(
                shortcutPath,
                executablePath,
                shortcutArguments,
                $"Open the {displayName} chat in Microsoft Teams",
                appUserModelId);

            var startInfo = new ProcessStartInfo
            {
                FileName = executablePath,
                UseShellExecute = false,
                WorkingDirectory = Path.GetDirectoryName(executablePath)!
            };
            startInfo.ArgumentList.Add(RequestTaskbarPinMode);
            startInfo.ArgumentList.Add(appUserModelId);
            startInfo.ArgumentList.Add(shortcutPath);
            startInfo.ArgumentList.Add(displayName);

            using var process = Process.Start(startInfo);
            if (process is null)
                throw new InvalidOperationException("Windows did not start the taskbar pin helper.");
        }
        catch (Exception ex) when (
            ex is UnauthorizedAccessException or
                IOException or
                COMException or
                Win32Exception or
                InvalidOperationException)
        {
            throw new TaskbarPinningException(
                "Teams Quick Chat could not create or launch the taskbar shortcut.",
                ex);
        }
    }

    internal static AppLaunchRequest? ParseLaunchRequest(string[] args)
    {
        if (args.Length == 0)
            return null;

        return args[0] switch
        {
            OpenPinnedChatMode => ParseOpenPinnedChatRequest(args),
            RequestTaskbarPinMode => ParseTaskbarPinRequest(args),
            RemoveTaskbarPinsMode => ParseRemoveTaskbarPinsRequest(args),
            _ => null
        };
    }

    internal static void RemoveAllShortcuts()
    {
        var shortcutDirectory = GetPinnedShortcutDirectory();
        if (!Directory.Exists(shortcutDirectory))
            return;

        foreach (var shortcutPath in Directory.EnumerateFiles(
                     shortcutDirectory,
                     "*.lnk",
                     SearchOption.TopDirectoryOnly))
        {
            ShellShortcut.Unpin(shortcutPath);
            File.Delete(shortcutPath);
        }

        if (!Directory.EnumerateFileSystemEntries(shortcutDirectory).Any())
            Directory.Delete(shortcutDirectory);
    }

    internal static void RevealShortcut(string shortcutPath)
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = "explorer.exe",
                Arguments = $"/select,\"{shortcutPath}\"",
                UseShellExecute = true
            };

            using var process = Process.Start(startInfo);
            if (process is null)
                throw new InvalidOperationException("Windows Explorer did not start.");
        }
        catch (Exception ex) when (ex is Win32Exception or InvalidOperationException)
        {
            throw new TaskbarPinningException(
                $"The shortcut was created at '{shortcutPath}', but Windows Explorer could not open it.",
                ex);
        }
    }

    private static OpenPinnedChatRequest ParseOpenPinnedChatRequest(string[] args)
    {
        if (args.Length != 3)
            throw InvalidLaunchArguments();

        ValidateChatAppUserModelId(args[2]);

        string chatUri;
        try
        {
            chatUri = DecodeUri(args[1]);
        }
        catch (Exception ex) when (ex is FormatException or DecoderFallbackException)
        {
            throw new TaskbarPinningException(
                "The pinned Teams chat shortcut contains invalid launch data.",
                ex);
        }

        if (!TeamsDeepLink.IsSupportedChatUri(chatUri))
            throw InvalidLaunchArguments();

        var expectedAppUserModelId =
            AppIdentity.ChatAppUserModelIdPrefix + GetTargetHash(chatUri);
        if (!string.Equals(
                args[2],
                expectedAppUserModelId,
                StringComparison.Ordinal))
        {
            throw InvalidLaunchArguments();
        }

        return new OpenPinnedChatRequest(args[2], chatUri);
    }

    private static TaskbarPinRequest ParseTaskbarPinRequest(string[] args)
    {
        if (args.Length != 4)
            throw InvalidLaunchArguments();

        ValidateChatAppUserModelId(args[1]);

        var shortcutPath = Path.GetFullPath(args[2]);
        var pinnedShortcutDirectory = Path.GetFullPath(GetPinnedShortcutDirectory()) +
            Path.DirectorySeparatorChar;

        if (!shortcutPath.StartsWith(
                pinnedShortcutDirectory,
                StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(
                Path.GetExtension(shortcutPath),
                ".lnk",
                StringComparison.OrdinalIgnoreCase) ||
            !File.Exists(shortcutPath))
        {
            throw InvalidLaunchArguments();
        }

        return new TaskbarPinRequest(
            args[1],
            shortcutPath,
            NormalizeDisplayName(args[3]));
    }

    private static RemoveTaskbarPinsRequest ParseRemoveTaskbarPinsRequest(string[] args)
    {
        if (args.Length != 1)
            throw InvalidLaunchArguments();

        return new RemoveTaskbarPinsRequest();
    }

    private static void ValidateChatAppUserModelId(string appUserModelId)
    {
        if (!AppIdentity.IsValid(appUserModelId) ||
            string.Equals(
                appUserModelId,
                AppIdentity.DefaultAppUserModelId,
                StringComparison.Ordinal))
        {
            throw InvalidLaunchArguments();
        }
    }

    private static string EncodeUri(string chatUri)
    {
        var encoded = Base64Url.EncodeToString(StrictUtf8.GetBytes(chatUri));

        if (encoded.Length > MaxEncodedUriLength)
        {
            throw new TaskbarPinningException(
                "This Teams chat link is too long to create a taskbar shortcut.",
                new ArgumentOutOfRangeException(nameof(chatUri)));
        }

        return encoded;
    }

    private static string DecodeUri(string encodedUri)
    {
        if (encodedUri.Length == 0 || encodedUri.Length > MaxEncodedUriLength)
            throw new FormatException("The encoded Teams chat link has an invalid length.");

        return StrictUtf8.GetString(Base64Url.DecodeFromChars(encodedUri));
    }

    private static string GetTargetHash(string target)
    {
        var hash = SHA256.HashData(StrictUtf8.GetBytes(target));
        return Convert.ToHexString(hash.AsSpan(0, HashByteCount));
    }

    private static string GetShortcutPath(string displayName, string hash)
    {
        var invalidCharacters = Path.GetInvalidFileNameChars();
        var safeName = new string(displayName
            .Where(character =>
                !char.IsControl(character) &&
                !invalidCharacters.Contains(character))
            .ToArray())
            .Trim(' ', '.');

        if (safeName.Length == 0)
            safeName = "Teams chat";
        if (safeName.Length > 80)
            safeName = safeName[..80].TrimEnd(' ', '.');

        return Path.Combine(
            GetPinnedShortcutDirectory(),
            $"{safeName} - {hash[..8]}.lnk");
    }

    private static string GetPinnedShortcutDirectory()
    {
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Programs),
            "TeamsQuickChat",
            "Pinned chats");
    }

    private static string NormalizeDisplayName(string displayName)
    {
        var normalized = new string(displayName
            .Where(character => !char.IsControl(character))
            .ToArray())
            .Trim();

        if (normalized.Length == 0)
            return "Teams chat";

        return normalized.Length <= 100 ? normalized : normalized[..100].TrimEnd();
    }

    private static TaskbarPinningException InvalidLaunchArguments()
    {
        return new TaskbarPinningException(
            "The Teams Quick Chat shortcut contains invalid launch arguments.",
            new ArgumentException("Invalid shortcut arguments."));
    }
}
