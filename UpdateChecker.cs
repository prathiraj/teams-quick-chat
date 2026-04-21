using System.Diagnostics;
using System.Net.Http.Json;
using System.Text.Json.Serialization;

namespace TeamsQuickChat;

public static class UpdateChecker
{
    private static readonly HttpClient Http = new()
    {
        DefaultRequestHeaders =
        {
            { "User-Agent", $"TeamsQuickChat/{AppInfo.Version}" },
            { "Accept", "application/vnd.github+json" }
        },
        Timeout = TimeSpan.FromSeconds(10)
    };

    public record GitHubRelease(
        [property: JsonPropertyName("tag_name")] string TagName,
        [property: JsonPropertyName("assets")] List<GitHubAsset> Assets,
        [property: JsonPropertyName("html_url")] string HtmlUrl);

    public record GitHubAsset(
        [property: JsonPropertyName("name")] string Name,
        [property: JsonPropertyName("browser_download_url")] string DownloadUrl);

    /// <summary>
    /// Check for updates. Returns (newVersion, release) if an update is available, or (null, null) if up to date.
    /// </summary>
    public static async Task<(string? NewVersion, GitHubRelease? Release)> CheckAsync()
    {
        try
        {
            var release = await Http.GetFromJsonAsync<GitHubRelease>(AppInfo.ReleasesApiUrl);
            if (release is null) return (null, null);

            var latestTag = release.TagName.TrimStart('v');
            if (!Version.TryParse(latestTag, out var latest)) return (null, null);
            if (!Version.TryParse(AppInfo.Version, out var current)) return (null, null);

            if (latest > current)
                return (latestTag, release);
        }
        catch
        {
            // Silently fail — no crash if offline or API unavailable
        }

        return (null, null);
    }

    /// <summary>
    /// Download the installer and launch it, then exit the app.
    /// </summary>
    public static async Task<bool> DownloadAndInstallAsync(GitHubRelease release)
    {
        var installerAsset = release.Assets
            .FirstOrDefault(a => a.Name.StartsWith("TeamsQuickChatSetup", StringComparison.OrdinalIgnoreCase)
                              && a.Name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase));

        if (installerAsset is null) return false;

        try
        {
            var tempPath = Path.Combine(Path.GetTempPath(), installerAsset.Name);
            using var response = await Http.GetAsync(installerAsset.DownloadUrl, HttpCompletionOption.ResponseHeadersRead);
            response.EnsureSuccessStatusCode();

            await using var fs = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None);
            await response.Content.CopyToAsync(fs);
            fs.Close();

            Process.Start(new ProcessStartInfo
            {
                FileName = tempPath,
                UseShellExecute = true
            });

            Application.Exit();
            return true;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Full update flow: check, prompt, download, install.
    /// </summary>
    public static async Task PromptAndUpdateAsync(bool showUpToDate = false)
    {
        var (newVersion, release) = await CheckAsync();

        if (newVersion is null || release is null)
        {
            if (showUpToDate)
            {
                MessageBox.Show(
                    $"You're running the latest version (v{AppInfo.Version}).",
                    "TeamsQuickChat",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }
            return;
        }

        var result = MessageBox.Show(
            $"A new version of TeamsQuickChat is available!\n\n" +
            $"Current: v{AppInfo.Version}\n" +
            $"Latest: v{newVersion}\n\n" +
            $"Would you like to update now?",
            "Update Available",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Information);

        if (result == DialogResult.Yes)
        {
            var ok = await DownloadAndInstallAsync(release);
            if (!ok)
            {
                MessageBox.Show(
                    "Failed to download the update.\nYou can download it manually from the releases page.",
                    "Update Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);

                Process.Start(new ProcessStartInfo
                {
                    FileName = AppInfo.ReleasesPageUrl,
                    UseShellExecute = true
                });
            }
        }
    }
}
