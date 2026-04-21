using System.Reflection;

namespace TeamsQuickChat;

public static class AppInfo
{
    public static readonly string Version =
        Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "0.0.0";

    public const string RepoOwner = "pchakka_microsoft";
    public const string RepoName = "teams-quick-chat";

    public static readonly string ReleasesApiUrl =
        $"https://api.github.com/repos/{RepoOwner}/{RepoName}/releases/latest";

    public static readonly string ReleasesPageUrl =
        $"https://github.com/{RepoOwner}/{RepoName}/releases/latest";
}
